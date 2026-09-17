#!/usr/bin/env bash
# bean-check gate for a draft: load-test it against the full ledger via a temp
# top-level file (per .claude/rules/validation.md — parse-clean != books-clean).
# The gate file is a COPY of main.beancount plus the draft include, not a bare
# `include "main.beancount"`: beancount only honours option/plugin directives
# in the top-level file, so a bare include drops auto_accounts and every
# auto-opened account fails with "unknown account" (~43k lines, always rc=1).
# Found 2026-08-29; the gate had never passed.
# Usage: check-draft.sh <draft-basename-in-import/>   Exit 0 = books-clean.
set -uo pipefail
DOCKER=/usr/local/bin/docker
draft="$1"
"$DOCKER" exec fava-custom sh -c '
  draft="$1"
  { cat /data/main.beancount; echo; echo "include \"import/$draft\""; } > /data/.draft-gate.beancount
  # A draft may carry document directives for the PDF it is about, which is
  # still import/<name>.pdf until approval files it. beancount reports the
  # missing target as an error; that is not a books problem, so drop those
  # (and their echoed directive line) before deciding.
  out=$(bean-check /data/.draft-gate.beancount 2>&1)
  rm -f /data/.draft-gate.beancount /data/.draft-gate.beancount.picklecache
  real=$(printf "%s\n" "$out" | grep -v "File does not exist:" | grep -v "^ *[0-9-]* document " | grep -v "^ *$")
  printf "%s\n" "$out"
  [ -z "$real" ]' sh "$draft"
