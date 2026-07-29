#!/usr/bin/env bash
# Ledger status snapshot (for the Hermes `ledger` skill and humans).
set -uo pipefail
LEDGER=/Users/alyssa/ledger
INBOX="$HOME/Library/Mobile Documents/com~apple~CloudDocs/3282/import"

echo "== bean-check =="
if /Users/alyssa/ledger-ingest/check-main.sh; then echo CLEAN; else echo "ERRORS (see above)"; fi
echo "== pending drafts (import/) =="
ls "$LEDGER"/import/*.draft.beancount 2>/dev/null || echo none
echo "== inbox (iCloud) =="
ls "$INBOX" | grep -iv "^\." | head -10
echo "== last ingest activity =="
tail -5 /Users/alyssa/ledger-ingest/ingest.log 2>/dev/null
echo "== git =="
cd "$LEDGER" && /usr/bin/git log --oneline -3 && /usr/bin/git status --short | head -5

echo "== upcoming / overdue =="
/Users/alyssa/ledger-ingest/duedates.sh 30
