"""Relayout statement PDFs to fava's documents convention.

statements/<cls>/<cls>-<date>.pdf         -> statements/<Acct/Path>/<date>.pdf
statements/<cls>/<cls>-<date>.txt         -> statements/.cache/<cls>-<date>.txt
import/MM-DD-YYYY.pdf (Store C)        -> statements/Liabilities/Credit/StoreC/<date>.pdf
import/<cardb>.pdf                       -> statements/Liabilities/Credit/CardB/<closing>.pdf
Extraction text for import/ files: import/.cache/<pdf>.txt -> statements/.cache/<cls>-<date>.txt
"""
import os, re, sys, shutil, datetime, importlib.util
APPLY = "--apply" in sys.argv
L = "/Users/alyssa/ledger"; ST = os.path.join(L, "statements"); IMP = os.path.join(L, "import")
CACHE = os.path.join(ST, ".cache")
spec = importlib.util.spec_from_file_location("sw", "/Users/alyssa/ledger-ingest/sweep-processed.py")
sw = importlib.util.module_from_spec(spec); spec.loader.exec_module(sw)
CLS_ACCOUNT = sw.CLS_ACCOUNT
moves = []  # (src, dst)


collisions = []


def plan(src, dst):
    if os.path.exists(dst) or dst in [d for _, d in moves]:
        collisions.append((src, dst)); return
    moves.append((src, dst))


# 1. archived
for cls in sorted(os.listdir(ST)):
    d = os.path.join(ST, cls)
    if cls.startswith(".") or not os.path.isdir(d) or cls not in CLS_ACCOUNT:
        continue
    acct = CLS_ACCOUNT[cls]
    for fn in sorted(os.listdir(d)):
        m = re.match(r"^%s-(\d{4}-\d{2}-\d{2})\.(pdf|txt)$" % re.escape(cls), fn)
        assert m, fn
        date, ext = m.groups()
        if ext == "pdf":
            plan(os.path.join(d, fn), os.path.join(ST, *acct.split(":"), date + ".pdf"))
        else:
            plan(os.path.join(d, fn), os.path.join(CACHE, "%s-%s.txt" % (cls, date)))

# 2. import/ Store C + CardB
unresolved = []
for fn in sorted(os.listdir(IMP)):
    if not fn.endswith(".pdf"):
        continue
    stem = fn[:-4]
    txt = os.path.join(IMP, ".cache", fn + ".txt")
    text = open(txt, errors="replace").read() if os.path.exists(txt) else ""
    acct = sw.classify(stem, text)
    if not acct:
        unresolved.append((fn, "unclassified")); continue
    cls = acct.split(":")[-1].lower()
    m = re.match(r"^(\d{2})-(\d{2})-(\d{4})$", stem)
    if m:
        date = "%s-%s-%s" % (m.group(3), m.group(1), m.group(2))
    else:
        my = re.match(r"^(\d{4})_annual_statement$", stem)
        d = sw.closing_date(text)
        if my:
            date = "%s-12-31" % my.group(1)
        elif d:
            date = d.isoformat()
        else:
            unresolved.append((fn, "no closing date in text (%s)" % acct)); continue
    plan(os.path.join(IMP, fn), os.path.join(ST, *acct.split(":"), date + ".pdf"))
    if os.path.exists(txt):
        plan(txt, os.path.join(CACHE, "%s-%s.txt" % (cls, date)))

# 3. files fava Move filed with its default "<today> <original>" name
for root, dirs, files in os.walk(ST):
    if ".cache" in root:
        continue
    for fn in sorted(files):
        m = re.match(r"^\d{4}-\d{2}-\d{2} (.+\.pdf)$", fn)
        if not m:
            continue
        orig = m.group(1); stem = orig[:-4]
        acct = ":".join(os.path.relpath(root, ST).split(os.sep))
        cls = acct.split(":")[-1].lower()
        txt = os.path.join(IMP, ".cache", orig + ".txt")
        text = open(txt, errors="replace").read() if os.path.exists(txt) else ""
        mm = re.match(r"^(\d{2})-(\d{2})-(\d{4})$", stem)
        d = sw.closing_date(text)
        if mm:
            date = "%s-%s-%s" % (mm.group(3), mm.group(1), mm.group(2))
        elif d:
            date = d.isoformat()
        else:
            unresolved.append((fn, "no date (%s)" % acct)); continue
        plan(os.path.join(root, fn), os.path.join(root, date + ".pdf"))
        if os.path.exists(txt):
            plan(txt, os.path.join(CACHE, "%s-%s.txt" % (cls, date)))

for s, d in moves:
    print("%-70s -> %s" % (os.path.relpath(s, L), os.path.relpath(d, L)))
print("\n%d moves; unresolved: %s" % (len(moves), unresolved or "none"))
if APPLY:
    for s, d in moves:
        os.makedirs(os.path.dirname(d), exist_ok=True)
        shutil.move(s, d)
    for cls in list(CLS_ACCOUNT):
        d = os.path.join(ST, cls)
        if os.path.isdir(d) and not os.listdir(d):
            os.rmdir(d)
    print("applied")
