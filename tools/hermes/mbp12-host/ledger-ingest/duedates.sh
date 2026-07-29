#!/usr/bin/env bash
# duedates.sh — SILENT unless a payment is genuinely unhandled.
#
# Rewritten 2026-07-29. The previous version scraped a due date out of every
# statement sitting in import/ and reported it. Once four years of statements
# were loaded for the reconciliation, that meant 100+ permanently-"overdue"
# lines, every one of them already paid or on autopay. Eleven lines, one of
# which mattered. A reminder that cries wolf gets muted, and then the line that
# mattered is lost with it.
#
# It now alerts ONLY when a payment looks unhandled:
#   * the newest statement for an account has a due date within HORIZON days
#   * AND the ledger has no payment covering it
#   * OR the covering entry is tagged #unscheduled (Alyssa's marker for
#     "forecast exists but not actually set up with the bank")
#
# Suppressed:
#   * statements that say autopay ("WILL BE DEDUCTED" / "#autopay" in ledger)
#   * superseded statements — only the NEWEST per account is considered
#   * anything already covered by a real ledger payment entry
#
# Always surfaced (these are deliberate, hand-written reminders):
#   * future-dated `note` directives falling inside the horizon
#
# Exit 0 = nothing to say (and nothing is sent).
set -uo pipefail
LEDGER=/Users/alyssa/ledger
BIN=/Users/alyssa/ledger-ingest
HORIZON="${1:-10}"
QUIET="${QUIET:-0}"          # QUIET=1 → print only, never notify
date +%s > "$BIN/.duedates-heartbeat"

OUT=$(/usr/bin/python3 - "$LEDGER" "$HORIZON" <<'PY'
import datetime, glob, os, re, sys

ledger, horizon = sys.argv[1], int(sys.argv[2])
today = datetime.date.today()
limit = today + datetime.timedelta(days=horizon)

# statement-filename prefix -> ledger account
ACCOUNTS = [
    (re.compile(r'^heloc-'),                      "Liabilities:Credit:NavyFederal:HELOC"),
    (re.compile(r'^PDF document'),                "Liabilities:Credit:Alyssa:Paypal"),
    (re.compile(r'^\d{2}-\d{2}-\d{4}$'),          "Liabilities:Credit:HomeDepot"),
    (re.compile(r'^[a-z]+_\d{4}_monthly_statement$'), "Liabilities:Credit:NavyFederal:Visa:GoRewards"),
]
def account_for(name):
    for rx, acct in ACCOUNTS:
        if rx.search(name):
            return acct
    return None

def parse_date(s):
    for fmt in ("%m/%d/%Y", "%m/%d/%y"):
        try: return datetime.datetime.strptime(s, fmt).date()
        except ValueError: pass
    return None

# ---- newest statement per account, with its due date -----------------------
latest = {}
for path in glob.glob(os.path.join(ledger, "import", "*.txt")):
    name = os.path.basename(path)[:-8] if path.endswith(".pdf.txt") else os.path.basename(path)[:-4]
    acct = account_for(name)
    if not acct:
        continue
    t = open(path, errors="replace").read()
    m = re.search(r'Payment Due Date\s*([0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4})', t, re.I)
    if not m:
        continue
    due = parse_date(m.group(1))
    if not due:
        continue
    # NOTE: `$ 466.46` (space after the $) broke the old regex and silently
    # dropped every HELOC amount, printing a bare "due".
    mp = re.search(r'Minimum Payment Due\s*\$?\s*([0-9,]+\.[0-9]{2})', t, re.I)
    past = re.search(r'Past Due Amount\s*\$?\s*([0-9,]+\.[0-9]{2})', t, re.I)
    autopay = bool(re.search(r'WILL BE DEDUCTED|AUTOMATIC PAYMENT|AUTOPAY', t, re.I))
    rec = dict(name=name, due=due, acct=acct, autopay=autopay,
               minp=float(mp.group(1).replace(',', '')) if mp else None,
               past=float(past.group(1).replace(',', '')) if past else 0.0)
    if acct not in latest or due > latest[acct]["due"]:
        latest[acct] = rec

# ---- ledger payments per account (any flag, incl. # forecasts) -------------
pay = {}
notes = []
blk = re.compile(r'\n(?=\d{4}-\d{2}-\d{2} [*!#] )')
for f in glob.glob(os.path.join(ledger, "**", "*.beancount"), recursive=True):
    if ".bak-" in f or ".reconcile." in f:
        continue
    try: txt = open(f, errors="replace").read()
    except OSError: continue
    for line in txt.split("\n"):
        nm = re.match(r'^(\d{4}-\d{2}-\d{2})\s+note\s+(\S+)\s+"(.*)"', line.strip())
        if nm:
            d = datetime.date.fromisoformat(nm.group(1))
            if today <= d <= limit:
                notes.append((d, nm.group(2).split(":")[-1], nm.group(3)))
    for b in blk.split(txt):
        h = re.match(r'^(\d{4}-\d{2}-\d{2}) ([*!#]) ', b)
        if not h: continue
        try: d = datetime.date.fromisoformat(h.group(1))
        except ValueError: continue
        tags = set(re.findall(r'#([A-Za-z0-9_-]+)', b.split("\n")[0]))
        for a in set(re.findall(r'^\s+!?(Liabilities:[A-Za-z0-9:]+)', b, re.M)):
            # a payment REDUCES a liability: positive amount on the liability leg
            amt = re.search(re.escape(a) + r'\s+([\d,]+\.?\d*) USD', b)
            if not amt: continue
            pay.setdefault(a, []).append((d, tags, float(amt.group(1).replace(',', ''))))

# ---- decide ----------------------------------------------------------------
alerts = []
for acct, r in sorted(latest.items()):
    # PAST DUE is already a problem — report it regardless of the horizon.
    # (A balance that is past due today should not wait for its next due date
    # to come within N days before anyone hears about it.)
    if r["past"] > 0:
        alerts.append((today, acct.split(":")[-1],
                       "PAST DUE $%.2f as of stmt %s — next min $%s due %s" %
                       (r["past"], r["name"],
                        ("%.2f" % r["minp"]) if r["minp"] else "?", r["due"])))
    if r["due"] > limit:
        continue                       # not yet within the horizon
    if r["autopay"]:
        continue                       # the statement says it deducts itself
    covering = [p for p in pay.get(acct, [])
                if r["due"] - datetime.timedelta(days=35) <= p[0] <= r["due"] + datetime.timedelta(days=5)]
    unscheduled = [p for p in covering if "unscheduled" in p[1]]
    autopaid    = [p for p in covering if "autopay" in p[1]]
    if autopaid:
        continue
    amt = ("$%.2f" % r["minp"]) if r["minp"] else "amount unknown"
    if not covering:
        alerts.append((r["due"], acct.split(":")[-1],
                       "NO PAYMENT IN LEDGER — min %s due %s (stmt %s)" % (amt, r["due"], r["name"])))
    elif unscheduled:
        alerts.append((r["due"], acct.split(":")[-1],
                       "payment is #unscheduled — min %s due %s" % (amt, r["due"])))

for d, who, what in notes:
    alerts.append((d, who, what))

if not alerts:
    sys.exit(0)
print("Ledger — %d item(s) need attention in the next %d days:" % (len(alerts), horizon))
for d, who, what in sorted(alerts):
    print("  %s  %-22s %s" % (d, who[:22], what[:150]))
PY
)
rc=$?
[ -z "$OUT" ] && exit 0
echo "$OUT"
[ "$QUIET" = "1" ] && exit 0
"$BIN/notify.sh" "$OUT" || true
