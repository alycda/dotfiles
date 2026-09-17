#!/usr/bin/env bash
# Gated approve: execute the PLAN of import/<name>.draft.beancount via a
# HOST-side one-shot (fixed prompt, never exposed to inbound chat), then
# bean-check; commit on clean, git-revert on failure.
# Usage: approve.sh <pdf-basename>   (e.g. 2026-07-31.pdf)
set -uo pipefail
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

MODEL="${LEDGER_APPROVE_MODEL:-claude-sonnet-5}"
PROVIDER="${LEDGER_APPROVE_PROVIDER:-openai-api}"

prompt="You are running UNATTENDED executing an APPROVED filing plan. Ledger
root: $LEDGER. The draft $LEDGER/$draft contains a '; PLAN:' block and
beancount entries. Execute EXACTLY that plan:
 1. mv the PDF $LEDGER/import/$name to the PLAN's target YYYY/ filename.
 2. Append the draft's entries and document directive(s) into the PLAN's
    '** Month YYYY' section of the matching YYYY/transactions.beancount,
    keeping date order (document directives grouped at the section end).
 3. Delete $LEDGER/$draft and $LEDGER/import/$name.txt.
HARD LIMITS: touch ONLY those files; do NOT run git; do NOT run bean-check
(the pipeline does); do NOT adjust any amount, date, or account from what the
draft says; if the PLAN is ambiguous or the month section is missing, output
APPROVE_ABORT and change nothing. Keep chat output to one short line."

"$HERMES" -z "$prompt" -m "$MODEL" --provider "$PROVIDER" --yolo --cli
if "$BIN/check-main.sh" >/dev/null 2>&1; then
  cd "$LEDGER" && $GIT add -A && $GIT commit -q -m "[approve] $name" && $GIT push -q origin main
  echo "APPROVED: $name booked, bean-check clean, committed."
  "$BIN/notify.sh" "ledger: approved $name — booked, bean-check clean, committed" || true
else
  cd "$LEDGER" && $GIT checkout -- .
  echo "FAILED: bean-check errors after filing — tracked files reverted. Details:"
  "$BIN/check-main.sh" 2>&1 | tail -5
  "$BIN/notify.sh" "ledger: approve $name FAILED bean-check — reverted, needs a look" || true
  exit 4
fi
