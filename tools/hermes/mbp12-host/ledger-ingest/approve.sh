#!/usr/bin/env bash
# Gated approve: execute the PLAN of import/<name>.draft.beancount via a
# HOST-side one-shot (fixed prompt, never exposed to inbound chat), then
# bean-check; commit on clean, git-revert on failure.
# Usage: approve.sh <pdf-basename>   (e.g. 2026-07-31.pdf)
set -uo pipefail

# PAUSE SWITCH: while ~/ledger-ingest/PAUSED exists, make no model calls.
# Used during bulk catch-up, when statements are dropped into the inbox in
# batches and auto-drafting each one would cost ~$1.62 a piece. Extraction,
# OCR, classification, gating and notification all still run — only the
# expensive step is skipped, and the PDF stays pending for later.
if [ -f /Users/alyssa/ledger-ingest/PAUSED ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') ${1:-?} -> SKIPPED (pipeline PAUSED; rm ~/ledger-ingest/PAUSED to resume)"
  exit 75
fi
HERMES=/Users/alyssa/.local/bin/hermes
LEDGER=/Users/alyssa/ledger
BIN=/Users/alyssa/ledger-ingest
GIT=/usr/bin/git

name="$1"
draft="import/$name.draft.beancount"
[ -f "$LEDGER/$draft" ] || { echo "ERROR: no such draft: $draft"; exit 2; }
if grep -q REVIEW_NEEDED "$LEDGER/$draft"; then
  echo "ERROR: draft is REVIEW_NEEDED — resolve manually (fava or M4), not via approve"
  exit 3
fi

MODEL="${LEDGER_APPROVE_MODEL:-z-ai-glm-5-3}"
PROVIDER="${LEDGER_APPROVE_PROVIDER:-openai-api}"

prompt="You are running UNATTENDED executing an APPROVED filing plan. Ledger
root: $LEDGER. The draft $LEDGER/$draft contains a '; PLAN:' block and
beancount entries. Execute EXACTLY that plan:
 1. mv the PDF $LEDGER/import/$name to the PLAN's target path (creating
    directories as needed): statements/<Account/Path>/<closing-date>.pdf for
    statements, YYYY/YYYY-MM-DD.pdf for paystubs. Move
    $LEDGER/import/.cache/$name.txt to statements/.cache/<leaf>-<date>.txt
    for a statement (delete it for a paystub).
 2. Append the draft's entries and any explicit document directive(s) into the
    PLAN's '** Month YYYY' section of the matching YYYY/transactions.beancount,
    keeping date order (document directives grouped at the section end).
 3. Delete $LEDGER/$draft.
HARD LIMITS: touch ONLY those files; do NOT run git; do NOT run bean-check
(the pipeline does); do NOT adjust any amount, date, or account from what the
draft says; if the PLAN is ambiguous or the month section is missing, output
APPROVE_ABORT and change nothing. Keep chat output to one short line."

"$HERMES" -z "$prompt" -m "$MODEL" --provider "$PROVIDER" --yolo --cli
if "$BIN/check-main.sh" >/dev/null 2>&1; then
  cd "$LEDGER" && $GIT add -A && $GIT commit -q -m "[approve] $name"
  # Offsite copy, encrypted (offsite-ledger.sh), logged to its own file so
  # this script's output stays the one line the caller reads.
  "$BIN/offsite-ledger.sh" >> "$BIN/offsite-ledger.log" 2>&1 \
    || echo "WARN: offsite copy failed; the commit is local, the next run retries"
  echo "APPROVED: $name booked, bean-check clean, committed."
  "$BIN/notify.sh" "ledger: approved $name — booked, bean-check clean, committed" || true
else
  cd "$LEDGER" && $GIT checkout -- .
  echo "FAILED: bean-check errors after filing — tracked files reverted. Details:"
  "$BIN/check-main.sh" 2>&1 | tail -5
  "$BIN/notify.sh" "ledger: approve $name FAILED bean-check — reverted, needs a look" || true
  exit 4
fi
