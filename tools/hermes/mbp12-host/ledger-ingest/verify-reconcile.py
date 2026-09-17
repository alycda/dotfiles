#!/usr/bin/env python3
"""verify-reconcile.py YEAR — check reconcile files against the statements.

Two independent checks:

1. PER MONTH: the signed net effect each reconcile file has on the BANKA
   liability, versus what the statement says that cycle should move it
   (prev - new), less whatever was already booked. Reported as a residual.

2. PER YEAR: total net movement of the liability across the year must equal
   (Dec new) - (prior Dec new). This one is immune to the cycle-boundary
   problem that made per-cycle balance assertions unusable in 2022, because
   it does not care which side of a boundary a transaction landed on.

Sums signed amounts and handles beancount's shorthand (`15 USD`, `15.1 USD`),
which an earlier regex of mine silently missed.
"""
import re, sys, os, glob

ACC = "Liabilities:Credit:BankA:CardA"
MONTHS = ["january","february","march","april","may","june","july",
          "august","september","october","november","december"]
IMPORT = "/Users/alyssa/ledger/import"

def money(f, label):
    for line in open(f, errors="replace"):
        if line.lower().startswith(label.lower()):
            m = re.search(r'([\d,]+\.\d{2})', line)
            if m: return float(m.group(1).replace(',', ''))
    return None

def net_effect(path):
    """Signed change this file applies to the BANKA liability."""
    t = open(path, errors="replace").read()
    net = 0.0
    for b in re.split(r'\n(?=\d{4}-\d{2}-\d{2} [*!])', t):
        if not re.match(r'\d{4}-\d{2}-\d{2} [*!]', b):
            continue
        explicit, rest = None, 0.0
        for line in b.split("\n"):
            m = re.match(r'\s+!?([A-Za-z][A-Za-z0-9:]+)\s+(-?[\d,]+(?:\.\d+)?) USD', line)
            if not m: continue
            acct, amt = m.groups()
            v = float(amt.replace(',', ''))
            if acct == ACC: explicit = (explicit or 0.0) + v
            else: rest += v
        net += explicit if explicit is not None else -rest
    return net

def txn_count(path):
    return len(re.findall(r'^\d{4}-\d{2}-\d{2} [*!]',
                          open(path, errors="replace").read(), re.M))

def review_count(path):
    return open(path, errors="replace").read().count("; REVIEW:")

def main(year):
    print("%-11s %5s %7s %12s %12s %11s  %s" %
          ("MONTH", "TXNS", "REVIEW", "FILE NET", "CYCLE NEEDS", "RESIDUAL", "NOTE"))
    year_net = 0.0
    first_prev = last_new = None
    missing = []
    for mn in MONTHS:
        stmt = os.path.join(IMPORT, "%s_%d_monthly_statement.pdf.txt" % (mn, year))
        rec  = os.path.join(IMPORT, "%s_%d.reconcile.beancount" % (mn, year))
        if not os.path.exists(stmt):
            print("%-11s  ** statement missing **" % mn); continue
        prev, new = money(stmt, "Previous Balance"), money(stmt, "New Balance")
        if first_prev is None: first_prev = prev
        last_new = new
        if not os.path.exists(rec):
            missing.append(mn)
            print("%-11s %5s %7s %12s %12.2f %11s  (pending)" %
                  (mn, "-", "-", "-", (prev - new) if None not in (prev, new) else 0, "-"))
            continue
        fn = net_effect(rec); year_net += fn
        need = prev - new
        resid = need - fn
        note = "= cycle" if abs(resid) < 0.005 else "%.2f already booked" % (-resid)
        print("%-11s %5d %7d %12.2f %12.2f %11.2f  %s" %
              (mn, txn_count(rec), review_count(rec), fn, need, resid, note))
    print()
    if first_prev is not None and last_new is not None:
        expected = first_prev - last_new
        print("  YEAR: statements move the liability %+.2f (%.2f -> %.2f)" %
              (expected, -first_prev, -last_new))
        print("        reconcile files supply %+.2f" % year_net)
        print("        difference (must equal what was ALREADY booked): %+.2f" %
              (expected - year_net))
    if missing:
        print("\n  still pending: %s" % ", ".join(missing))

if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 2023)
