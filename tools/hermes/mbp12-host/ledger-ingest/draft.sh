#!/usr/bin/env bash
# Bookkeeper agent run — CONTAINED: executes inside the hermes-boxed `draft`
# service, which mounts the repo read-only at /ledger with ONLY /ledger/import
# writable. Untrusted PDF text therefore cannot touch ledger files or the
# host even if it injects the model. Model = sonnet via Venice.
# Usage: draft.sh <pdf-basename> <class>
set -uo pipefail
DOCKER=/usr/local/bin/docker
COMPOSE_DIR=/Users/alyssa/hermes-boxed
base="$1"; class="$2"
# GLM by default: 1.40/4.40 per Mtok vs sonnet-5's 3/15. A verification run on
# 2026-07-28 cost $2.99 because this defaulted to sonnet AND the draft runner
# still allowed 90 tool iterations. Override per-run with LEDGER_DRAFT_MODEL.
MODEL="${LEDGER_DRAFT_MODEL:-z-ai-glm-5-3-flash}"
PROVIDER="${LEDGER_DRAFT_PROVIDER:-openai-api}"

prompt="You are running UNATTENDED in a pipeline. First read these three files:
/ledger/.claude/agents/bookkeeper.md
/ledger/.claude/rules/conventions.md
/ledger/.claude/rules/history.md
Then act as that bookkeeper agent.

Task: draft ledger entries for the new document /ledger/import/$base
(classifier hint: $class). Its extracted text is in /ledger/import/.cache/$base.txt.
Ledger root is /ledger — read whatever context you need (main.beancount, the
matching YYYY/transactions.beancount month section, accounts/).

Write EXACTLY ONE new file: /ledger/import/$base.draft.beancount containing:
 1. a '; PLAN:' comment block: the target filename — statements go to
    statements/<Account/Path>/<closing-date>.pdf (auto-discovered, NO document
    directive for that account; multi-account statements: file under the
    first account and add '../statements/...' directives for the others),
    paystubs stay bare YYYY/YYYY-MM-DD.pdf with their two directives — the
    '** Month YYYY' section the entries belong in, and any explicit document
    directive line(s)
 2. the draft beancount entries (flags, tags, links per conventions; for
    deposits add the day-after balance assertion per the bookkeeper rules)
If you cannot process it confidently, write '; REVIEW_NEEDED: <reason>' as
the file's only content instead — never guess accounts.

HARD LIMITS: only /ledger/import is writable (everything else is a read-only
mount — do not try); do not do arithmetic to verify balances (the pipeline
runs bean-check); keep chat output to one short line."

# PAUSE SWITCH: while ~/ledger-ingest/PAUSED exists, make no model calls.
# Used during bulk catch-up, when statements are dropped into the inbox in
# batches and auto-drafting each one would cost ~$1.62 a piece. Extraction,
# OCR, classification, gating and notification all still run — only the
# expensive step is skipped, and the PDF stays pending for later.
if [ -f /Users/alyssa/ledger-ingest/PAUSED ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') ${1:-?} -> SKIPPED (pipeline PAUSED; rm ~/ledger-ingest/PAUSED to resume)"
  exit 75
fi

# Preflight: Venice 402 surfaces from hermes ONLY as "no final response was
# produced", which reads like an agent failure. Fail loudly and leave the PDF
# pending for retry instead of writing a misleading draft.
if ! /Users/alyssa/ledger-ingest/preflight.sh; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') $base draft -> SKIPPED (no credits; will retry on next ingest)"
  exit 75   # EX_TEMPFAIL: transient, retry later
fi

# Self-heal: container_boot.py auto-starts a gateway in ANY container whose
# HERMES_HOME has gateway_state.json == "running" (_AUTOSTART_STATES). In a
# one-shot runner that gateway fights the -z run for the s6 log lock, fails to
# reach signal-cli (draftnet is isolated by design), and the run dies with
# "no final response was produced" before ever calling the model. A crashed
# gateway re-persists "running", so assert "stopped" before every run.
printf '%s\n' '{"gateway_state": "stopped", "note": "one-shot runner: never auto-start a gateway"}' \
  > "$COMPOSE_DIR/state-draft/gateway_state.json"

cd "$COMPOSE_DIR" && exec "$DOCKER" compose run --rm --no-deps draft \
  -z "$prompt" -m "$MODEL" --provider "$PROVIDER" --yolo --cli
