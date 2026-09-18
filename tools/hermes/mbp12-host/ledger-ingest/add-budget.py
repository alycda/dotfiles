#!/usr/bin/env python3
"""add-budget.py — append one Fava budget directive, safely.

Deliberately narrow. The agent supplies an account, a period and an amount as
separate validated fields; it never supplies a line of beancount. The directive
is assembled here from checked components, so there is no path from agent text
into the ledger's syntax.

Guards, in order:
  * account must already be declared by an `open` directive — no inventing accounts
  * period must be one of Fava's five
  * amount must parse as a positive number under a sane ceiling
  * date must be ISO, defaulting to Jan 1 of the current year (budgets apply
    from their date forward, so the year start is the useful default)
  * an identical account+period+date directive is refused rather than duplicated
  * after appending, bean-check must pass or the file is restored byte-for-byte

Fava budgets are NATIVE — no extension is required. This ledger has used
`custom "budget"` since 2022.

  add-budget.py --account Expenses:Household:Groceries --period monthly --amount 800
"""
import argparse, datetime, os, re, subprocess, sys

LEDGER = "/Users/alyssa/ledger"
TARGET = os.path.join(LEDGER, "budgets-forecasts.beancount")
CHECK = "/Users/alyssa/ledger-ingest/check-main.sh"
PERIODS = ("daily", "weekly", "monthly", "quarterly", "yearly")
MAX = 1_000_000.0

OPEN = re.compile(r'^\d{4}-\d{2}-\d{2}\s+open\s+([A-Za-z][A-Za-z0-9:_-]+)')


def known_accounts():
    found = set()
    for root, dirs, files in os.walk(LEDGER):
        dirs[:] = [d for d in dirs if d not in (".git", ".jj", "import", "statements")]
        for fn in files:
            if not fn.endswith(".beancount") or ".bak-" in fn:
                continue
            try:
                for line in open(os.path.join(root, fn), errors="replace"):
                    m = OPEN.match(line)
                    if m:
                        found.add(m.group(1))
            except OSError:
                pass
    return found


def die(msg):
    print("ERROR: " + msg)
    sys.exit(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--account", required=True)
    ap.add_argument("--period", required=True)
    ap.add_argument("--amount", required=True)
    ap.add_argument("--date", default="")
    a = ap.parse_args()

    period = a.period.strip().lower()
    if period not in PERIODS:
        die("period must be one of %s (got %r)" % (", ".join(PERIODS), a.period))

    try:
        amount = float(str(a.amount).replace(",", "").replace("$", "").strip())
    except ValueError:
        die("amount is not a number: %r" % a.amount)
    if not (0 < amount <= MAX):
        die("amount must be > 0 and <= %.0f (got %s)" % (MAX, a.amount))

    if a.date:
        try:
            date = datetime.date.fromisoformat(a.date.strip())
        except ValueError:
            die("date must be YYYY-MM-DD (got %r)" % a.date)
    else:
        date = datetime.date(datetime.date.today().year, 1, 1)

    account = a.account.strip()
    accounts = known_accounts()
    if account not in accounts:
        near = sorted(x for x in accounts if x.lower().startswith(account.lower()[:18]))[:5]
        die("account %s is not opened in the ledger%s"
            % (account, ("; did you mean: " + ", ".join(near)) if near else ""))

    line = '%s custom "budget" %s "%s" %.2f USD' % (date, account, period, amount)

    original = open(TARGET).read()
    if line in original:
        die("that exact budget directive is already present: %s" % line)

    body = original if original.endswith("\n") else original + "\n"
    open(TARGET, "w").write(body + line + "\n")

    r = subprocess.run([CHECK], capture_output=True, text=True, timeout=180)
    if r.returncode != 0:
        open(TARGET, "w").write(original)          # byte-for-byte restore
        die("bean-check rejected the directive, ledger restored:\n%s"
            % ((r.stdout or "") + (r.stderr or ""))[:1500])

    print("added to budgets-forecasts.beancount: %s" % line)


if __name__ == "__main__":
    main()
