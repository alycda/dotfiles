#!/usr/bin/env python3
"""sweep-processed.py — archive import/ statements that already appear in the ledger.

"Appears in the ledger" is defined by evidence, not by the presence of a draft:
a statement is considered processed when the dollar amounts printed on it are
found as postings against the account that statement belongs to. A draft file
proves only that a draft was generated, never that it was merged.

DRY RUN BY DEFAULT. Nothing moves without --apply. Files are moved, never
deleted, and unclassifiable files are never touched.

  ./sweep-processed.py                 # report only
  ./sweep-processed.py --apply         # move the ones that qualify
  ./sweep-processed.py --threshold 95  # stricter coverage bar
  ./sweep-processed.py --trust Liabilities:Credit:BankA:CardA
                                       # archive that account on the strength of
                                       # its reconciliation anchor, skipping the
                                       # coverage bar (2026-08-29 decision: the
                                       # BANKA card + LOANA were reconciled
                                       # statement-by-statement and anchored in
                                       # 22a16c8; the amount-coverage heuristic
                                       # scored them 70-87% anyway)

Every archived statement gets a `document` directive appended to
statements.beancount (included from main.beancount), dated by the statement
closing date, so it shows on the account's Documents tab in fava.
"""
import argparse, os, re, shutil, sys, datetime

LEDGER = "/Users/alyssa/ledger"
IMPORT = os.path.join(LEDGER, "import")
ARCHIVE = os.path.join(LEDGER, "statements")
LOG = "/Users/alyssa/ledger-ingest/sweep.log"
DOCS = os.path.join(LEDGER, "statements.beancount")
TXT_CACHE = os.path.join(IMPORT, ".cache")
CLS_ACCOUNT = {
    "carda": "Liabilities:Credit:BankA:CardA",
    "loana": "Liabilities:Credit:BankA:LoanA",
    "cardb": "Liabilities:Credit:CardB",
    "storec": "Liabilities:Credit:StoreC",
    "cardd": "Liabilities:Credit:BankD:CardD",
    "storee": "Liabilities:Credit:StoreE",
    "cardf": "Liabilities:Credit:BankF:CardF",
}


def add_document(date, acct, relpath):
    """Append a document directive unless one for relpath already exists."""
    existing = open(DOCS, errors="replace").read() if os.path.exists(DOCS) else ""
    if '"%s"' % relpath in existing:
        return False
    with open(DOCS, "a") as f:
        if not existing:
            f.write("; Archived statements (statements/<account>/), written by\n"
                    "; ledger-ingest/sweep-processed.py. One document directive per\n"
                    "; PDF, dated by the statement closing date.\n\n")
        f.write('%s document %s "%s"\n' % (date, acct, relpath))
    return True


# ---- classification --------------------------------------------------------
# Filename patterns first (cheap, unambiguous), then statement text. A file we
# cannot place is reported and left alone — archiving an unknown statement is
# how you lose one.
FILENAME_RULES = [
    (re.compile(r'^loana-'),                          "Liabilities:Credit:BankA:LoanA"),
    (re.compile(r'^\d{2}-\d{2}-\d{4}$'),              "Liabilities:Credit:StoreC"),
    (re.compile(r'^[a-z]+_\d{4}_monthly_statement$'), "Liabilities:Credit:BankA:CardA"),
]
CONTENT_RULES = [
    (re.compile(r'loan\s*a|LOANA', re.I),                "Liabilities:Credit:BankA:LoanA"),
    (re.compile(r'CARD\s*A|Bank A.*Visa', re.I|re.S), "Liabilities:Credit:BankA:CardA"),
    (re.compile(r'CardB', re.I),                             "Liabilities:Credit:CardB"),
    (re.compile(r'Store\s*C', re.I),                       "Liabilities:Credit:StoreC"),
    (re.compile(r'BankD.*CardD|CardD Preferred', re.I|re.S), "Liabilities:Credit:BankD:CardD"),
    (re.compile(r'StoreE', re.I),                             "Liabilities:Credit:StoreE"),
    (re.compile(r'CardF|Bank F', re.I),             "Liabilities:Credit:BankF:CardF"),
]

AMOUNT = re.compile(r'\$?\s*(\d{1,3}(?:,\d{3})*\.\d{2})')
CLOSING = [
    re.compile(r'Statement\s+Closing\s+Date\s*:?\s*(\d{1,2}/\d{1,2}/\d{2,4})', re.I),
    re.compile(r'Closing\s+Date\s*:?\s*(\d{1,2}/\d{1,2}/\d{2,4})', re.I),
    re.compile(r'Statement\s+Date\s*:?\s*(\d{1,2}/\d{1,2}/\d{2,4})', re.I),
    re.compile(r'through\s+(\d{1,2}/\d{1,2}/\d{2,4})', re.I),
]

def classify(stem, text):
    for rx, acct in FILENAME_RULES:
        if rx.search(stem):
            return acct
    for rx, acct in CONTENT_RULES:
        if rx.search(text):
            return acct
    return None

def closing_date(text):
    for rx in CLOSING:
        m = rx.search(text)
        if m:
            for fmt in ("%m/%d/%Y", "%m/%d/%y"):
                try:
                    return datetime.datetime.strptime(m.group(1), fmt).date()
                except ValueError:
                    pass
    return None

# Figures every statement prints that are never postings. Left in the
# denominator they cap coverage well below 100% no matter how completely the
# statement was booked, which is what made a 90% bar unreachable.
SUMMARY = re.compile(
    r'(?:'
    r'(?:previous|new|statement|ending|beginning|principal|average daily|daily)\s+balance'
    r'|credit\s+limit|available\s+(?:credit|cash)|cash\s+advance\s+limit'
    r'|minimum\s+payment(?:\s+due)?|payment\s+due|amount\s+due|past\s+due\s+amount'
    r'|total\s+(?:fees|interest|payments|credits|purchases|advances)'
    r'|(?:interest|fees)\s+charged|finance\s+charge'
    r'|year[- ]to[- ]date|ytd'
    r')[^\n$]{0,40}\$?\s*([\d,]+\.\d{2})', re.I)

def amounts(text):
    """Distinct transaction amounts on the statement.

    Excludes sub-dollar noise, implausibly large figures, and any amount that
    follows a summary label — those are account totals, not line items."""
    summary = set()
    for a in SUMMARY.findall(text):
        try:
            summary.add(round(float(a.replace(",", "")), 2))
        except ValueError:
            pass
    out = set()
    for a in AMOUNT.findall(text):
        v = round(float(a.replace(",", "")), 2)
        if 1.00 <= v <= 100000.00 and v not in summary:
            out.add(v)
    return out

def ledger_amounts():
    """Map account -> set of amounts appearing in transactions that touch it.

    Reading amounts off the account's OWN posting line does not work in this
    ledger: the liability leg is elided on nearly every entry (1,543 elided vs
    94 with an explicit amount on the BANKA card), because the figure is carried
    by the counter-leg. So the unit of evidence is the whole transaction — if a
    statement's figure appears in any transaction referencing that account, the
    line was booked.

    Parsed directly rather than via bean-query, whose quoting does not survive
    an ssh round-trip."""
    by_acct = {}
    blk = re.compile(r'\n(?=\d{4}-\d{2}-\d{2}\s+[*!#])')
    amt = re.compile(r'(-?[\d,]+\.\d{2})\s+USD')
    acctre = re.compile(r'\b((?:Assets|Liabilities|Income|Expenses|Equity)(?::[A-Za-z0-9-]+)+)')
    for root, dirs, files in os.walk(LEDGER):
        dirs[:] = [d for d in dirs if d not in (".git", ".jj", "import", "statements")]
        for fn in files:
            if not fn.endswith(".beancount") or ".bak-" in fn:
                continue
            try:
                txt = open(os.path.join(root, fn), errors="replace").read()
            except OSError:
                continue
            for b in blk.split(txt):
                if not re.match(r'\d{4}-\d{2}-\d{2}', b):
                    continue
                vals = set()
                for a in amt.findall(b):
                    try:
                        vals.add(round(abs(float(a.replace(",", ""))), 2))
                    except ValueError:
                        pass
                if not vals:
                    continue
                for acct in set(acctre.findall(b)):
                    by_acct.setdefault(acct, set()).update(vals)
    return by_acct

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="actually move files")
    ap.add_argument("--threshold", type=float, default=90.0,
                    help="percent of statement amounts that must appear (default 90)")
    ap.add_argument("--min-amounts", type=int, default=5,
                    help="skip statements with fewer distinct amounts than this")
    ap.add_argument("--trust", action="append", default=[], metavar="ACCOUNT",
                    help="archive this account's statements without the coverage bar "
                         "(its reconciliation anchor is the evidence); repeatable")
    args = ap.parse_args()

    book = ledger_amounts()
    rows, moved = [], 0

    for pdf in sorted(os.listdir(IMPORT)):
        if not pdf.endswith(".pdf"):
            continue
        stem = pdf[:-4]
        tpath = os.path.join(TXT_CACHE, pdf + ".txt")
        if not os.path.exists(tpath):
            tpath = os.path.join(IMPORT, pdf + ".txt")
        if not os.path.exists(tpath):
            tpath = os.path.join(IMPORT, stem + ".txt")
        if not os.path.exists(tpath):
            rows.append((stem, "-", 0, 0, 0.0, "NO TEXT — skipped"))
            continue

        text = open(tpath, errors="replace").read()
        acct = classify(stem, text)
        if not acct:
            rows.append((stem, "-", 0, 0, 0.0, "UNCLASSIFIED — skipped"))
            continue

        trusted = acct in args.trust
        stmt = amounts(text)
        if len(stmt) < args.min_amounts and not trusted:
            rows.append((stem, acct.split(":")[-1], len(stmt), 0, 0.0, "too few amounts — skipped"))
            continue

        posted = book.get(acct, set())
        hit = stmt & posted
        cov = 100.0 * len(hit) / len(stmt) if stmt else 0.0

        if cov < args.threshold and not trusted:
            rows.append((stem, acct.split(":")[-1], len(stmt), len(hit), cov, "NOT in ledger — kept"))
            continue

        d = closing_date(text)
        cls = acct.split(":")[-1].lower()
        newname = ("%s-%s.pdf" % (cls, d)) if d else ("%s-%s.pdf" % (cls, stem))
        dest = os.path.join(ARCHIVE, cls)
        note = "-> statements/%s/%s%s" % (cls, newname, "  (trusted)" if trusted else "")
        if not d:
            note += "  (no closing date found — kept original stem)"

        if args.apply:
            os.makedirs(dest, exist_ok=True)
            target = os.path.join(dest, newname)
            if os.path.exists(target):
                rows.append((stem, cls, len(stmt), len(hit), cov, "TARGET EXISTS — kept"))
                continue
            shutil.move(os.path.join(IMPORT, pdf), target)
            for p in (os.path.join(TXT_CACHE, pdf + ".txt"), os.path.join(IMPORT, pdf + ".txt"),
                      os.path.join(IMPORT, stem + ".txt"), os.path.join(IMPORT, stem + ".beancount")):
                if os.path.exists(p):
                    shutil.move(p, os.path.join(dest, os.path.splitext(newname)[0]
                                                + os.path.splitext(p)[1]))
            if d:
                add_document(d, acct, "statements/%s/%s" % (cls, newname))
            moved += 1
        rows.append((stem, cls, len(stmt), len(hit), cov, note))

    w = max([len(r[0]) for r in rows] + [8])
    print("%-*s  %-12s %6s %6s %7s  %s" % (w, "statement", "account", "amts", "found", "cov", "decision"))
    print("-" * (w + 60))
    for r in rows:
        print("%-*s  %-12s %6d %6d %6.1f%%  %s" % (w, r[0][:w], r[1][:12], r[2], r[3], r[4], r[5]))

    qualify = sum(1 for r in rows if r[5].startswith("->"))
    print("\n%d files, %d qualify at >=%.0f%% coverage, %d moved%s"
          % (len(rows), qualify, args.threshold, moved,
             "" if args.apply else "  (DRY RUN — rerun with --apply)"))

    # Backfill directives for statements archived before this script wrote them.
    if args.apply:
        added = 0
        for cls in (sorted(os.listdir(ARCHIVE)) if os.path.isdir(ARCHIVE) else []):
            acct = CLS_ACCOUNT.get(cls)
            if not acct:
                continue
            for fn in sorted(os.listdir(os.path.join(ARCHIVE, cls))):
                m = re.match(r'^%s-(\d{4}-\d{2}-\d{2})\.pdf$' % re.escape(cls), fn)
                if m and add_document(m.group(1), acct, "statements/%s/%s" % (cls, fn)):
                    added += 1
        if added:
            print("backfilled %d document directive(s) into statements.beancount" % added)

    if args.apply and moved:
        with open(LOG, "a") as f:
            f.write("%s swept %d files at >=%.0f%%\n"
                    % (datetime.datetime.now().isoformat(timespec="seconds"), moved, args.threshold))

if __name__ == "__main__":
    main()
