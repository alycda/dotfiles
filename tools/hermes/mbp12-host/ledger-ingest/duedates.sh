#!/usr/bin/env bash
# Upcoming/overdue obligations — the "don't let a one-off payment slip" check.
# Sources (all local, no model):
#   1. statement text extracts in import/*.txt  → due date + minimum + past-due
#   2. ledger `note` directives with future dates (main.beancount + YYYY/)
# Prints a dated list; used by status.sh and the daily Signal reminder.
set -uo pipefail
LEDGER=/Users/alyssa/ledger
DAYS="${1:-45}"

/usr/bin/python3 - "$LEDGER" "$DAYS" <<'PY'
import datetime, glob, os, re, sys

ledger, days = sys.argv[1], int(sys.argv[2])
today = datetime.date.today()
horizon = today + datetime.timedelta(days=days)
rows = []

# 1. statement extracts: due date, minimum, past due
for path in glob.glob(os.path.join(ledger, "import", "*.txt")):
    t = open(path, errors="replace").read()
    name = os.path.basename(path)[:-4]
    m = re.search(r"Payment Due Date\s*([0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4})", t, re.I)
    if not m:
        continue
    try:
        mm, dd, yy = [int(x) for x in m.group(1).split("/")]
        due = datetime.date(yy + 2000 if yy < 100 else yy, mm, dd)
    except ValueError:
        continue
    minp = re.search(r"Minimum Payment Due\s*\$?([0-9,]+\.[0-9]{2})", t, re.I)
    past = re.search(r"Past Due Amount\s*\$?([0-9,]+\.[0-9]{2})", t, re.I)
    bits = []
    if minp: bits.append("min $" + minp.group(1))
    if past and past.group(1) not in ("0.00", "0"): bits.append("PAST DUE $" + past.group(1))
    rows.append((due, f"statement {name}", ", ".join(bits) or "due"))

# 2. ledger notes dated ahead (reminders Alyssa writes into the ledger)
note_re = re.compile(r'^(\d{4}-\d{2}-\d{2})\s+note\s+(\S+)\s+"(.*)"')
# Scan every ledger file, not just main + yearly transactions: rate/promo
# notes live in per-topic files (rates.beancount) and were being missed.
files = sorted(set(glob.glob(os.path.join(ledger, "*.beancount"))
                   + glob.glob(os.path.join(ledger, "20*", "*.beancount"))))
for f in files:
    try:
        for line in open(f, errors="replace"):
            m = note_re.match(line.strip())
            if not m:
                continue
            d = datetime.date.fromisoformat(m.group(1))
            if today <= d <= horizon:
                rows.append((d, m.group(2).split(":")[-1], m.group(3)[:90]))
    except OSError:
        pass

# dismissals: one substring per line in ~/ledger-ingest/paid.txt suppresses a row
try:
    dismissed = [l.strip() for l in open("/Users/alyssa/ledger-ingest/paid.txt") if l.strip() and not l.startswith("#")]
except OSError:
    dismissed = []
rows = [r for r in rows if not any(d in f"{r[0]} {r[1]} {r[2]}" for d in dismissed)]

# Only recent history is actionable. import/ now holds every statement back to
# 2022 (the reconciliation batch), and without this window the daily reminder
# reports 100+ statements from 2022-2025 as "OVERDUE" -- noise that would get
# the whole notification muted.
STALE_AFTER_DAYS = 60
floor = today - datetime.timedelta(days=STALE_AFTER_DAYS)
rows = [r for r in rows if r[0] >= floor]
overdue = [r for r in rows if r[0] < today or "PAST DUE" in r[2]]
soon = [r for r in rows if today <= r[0] <= horizon and r not in overdue]
if not overdue and not soon:
    print(f"No obligations found in the next {days} days.")
for label, group in (("OVERDUE / ACTION NEEDED", overdue), (f"NEXT {days} DAYS", soon)):
    if group:
        print(f"== {label} ==")
        for d, who, what in sorted(group):
            print(f"  {d}  {who:<28} {what}")
PY
