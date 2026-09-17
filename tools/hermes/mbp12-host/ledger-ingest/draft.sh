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
MODEL="${LEDGER_DRAFT_MODEL:-claude-sonnet-5}"
PROVIDER="${LEDGER_DRAFT_PROVIDER:-openai-api}"

prompt="You are running UNATTENDED in a pipeline. First read these three files:
/ledger/.claude/agents/bookkeeper.md
/ledger/.claude/rules/conventions.md
/ledger/.claude/rules/history.md
Then act as that bookkeeper agent.

Task: draft ledger entries for the new document /ledger/import/$base
(classifier hint: $class). Its extracted text is in /ledger/import/$base.txt.
Ledger root is /ledger — read whatever context you need (main.beancount, the
matching YYYY/transactions.beancount month section, accounts/).

Write EXACTLY ONE new file: /ledger/import/$base.draft.beancount containing:
 1. a '; PLAN:' comment block: the target filename per the slug convention
    (import/$base -> YYYY/<statement-date>.<slug>.pdf, paystubs bare
    YYYY-MM-DD.pdf), the '** Month YYYY' section the entries belong in, and
    the document directive line(s)
 2. the draft beancount entries (flags, tags, links per conventions; for
    deposits add the day-after balance assertion per the bookkeeper rules)
If you cannot process it confidently, write '; REVIEW_NEEDED: <reason>' as
the file's only content instead — never guess accounts.

HARD LIMITS: only /ledger/import is writable (everything else is a read-only
mount — do not try); do not do arithmetic to verify balances (the pipeline
runs bean-check); keep chat output to one short line."

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
