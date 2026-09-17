#!/usr/bin/env bash
# backup-ledger.sh — archive the beancount source into iCloud.
#
# Convention (matches the pre-existing archives in LedgerDocs/_backups):
#   beancount-backup-YYYYMMDD.tar.gz
#
# WHY THIS EXISTS IN THIS FORM: the previous backups captured only 7 root-level
# files, and by 2026-07-31 five of those seven no longer existed — they were
# from an older ledger layout. None of them contained main.beancount,
# rates.beancount, accounts/, or any 20xx/transactions.beancount, which is where
# essentially all the data lives. The scheme also stopped running on 2026-06-10.
# So: take the file list from the filesystem every run, never from a fixed list.
#
# Included: every *.beancount outside import/, plus importers.py.
# Excluded: PDFs (statements and paystubs — sensitive, and gitignored for the
# same reason), *.bak-* working copies, .git/.jj internals.
#
# Silent on success. Notifies via Signal only on failure, because a backup that
# fails quietly is worse than no backup at all.
set -uo pipefail

LEDGER=/Users/alyssa/ledger
BIN=/Users/alyssa/ledger-ingest
DEST="/Users/alyssa/Library/Mobile Documents/com~apple~CloudDocs/LedgerDocs/_backups"
LOG="$BIN/backup-ledger.log"
KEEP=26                       # ~6 months of weekly archives

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ echo "$(ts) $*" >> "$LOG"; }
fail(){ log "FAIL: $*"; "$BIN/notify.sh" "ledger backup FAILED: $*" 2>/dev/null || true; exit 1; }

[ -d "$LEDGER" ] || fail "ledger directory missing at $LEDGER"
# iCloud can evict content, but the directory itself must exist — if it does
# not, the backup would silently write into a path nobody syncs.
[ -d "$DEST" ]   || fail "iCloud backup directory missing at $DEST"

cd "$LEDGER" || fail "cannot cd to $LEDGER"

OUT="$DEST/beancount-backup-$(date +%Y%m%d).tar.gz"
[ -e "$OUT" ] && OUT="$DEST/beancount-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

LIST=$(mktemp)
trap 'rm -f "$LIST"' EXIT
find . -name "*.beancount" -not -name "*.bak-*" -not -path "./import/*" \
       -not -path "./.git/*" -not -path "./.jj/*" | sed 's|^\./||' | sort > "$LIST"
[ -f importers.py ] && echo "importers.py" >> "$LIST"

count=$(wc -l < "$LIST" | tr -d ' ')
[ "$count" -ge 10 ] || fail "only $count files matched — refusing to write a suspiciously small backup"

tar -czf "$OUT" -T "$LIST" 2>>"$LOG" || fail "tar failed"
gzip -t "$OUT" 2>>"$LOG"             || fail "archive failed integrity check"

# Prove it restores, not just that it was written.
TMP=$(mktemp -d)
tar -xzf "$OUT" -C "$TMP" 2>>"$LOG" || { rm -rf "$TMP"; fail "archive will not extract"; }
if ! diff -q "$TMP/2026/transactions.beancount" "$LEDGER/2026/transactions.beancount" >/dev/null 2>&1; then
    rm -rf "$TMP"; fail "restored 2026/transactions.beancount does not match source"
fi
rm -rf "$TMP"

lines=$(tar -xzOf "$OUT" 2>/dev/null | wc -l | tr -d ' ')
SUMMARY="OK $(basename "$OUT") — $count files, $lines lines, $(du -h "$OUT" | cut -f1)"
log "$SUMMARY"
# Also to stdout: silence is right for Signal notifications, but a broker tool
# call that returns "(no output)" gives the agent no way to tell success from a
# no-op. launchd just captures this into backup-ledger.out.
echo "$SUMMARY"

# Retention: keep the newest $KEEP of OUR archives. Never touches anything else
# in _backups (the fava-complete-* archives and the pre-2026-06 files stay).
ls -t "$DEST"/beancount-backup-*.tar.gz 2>/dev/null | tail -n +$((KEEP+1)) | while read -r old; do
    rm -f "$old" && log "pruned $(basename "$old")"
done

exit 0
