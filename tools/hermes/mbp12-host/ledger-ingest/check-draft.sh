#!/usr/bin/env bash
# bean-check gate for a draft: load-test it against the full ledger via a temp
# include (per .claude/rules/validation.md — parse-clean != books-clean).
# Usage: check-draft.sh <draft-basename-in-import/>   Exit 0 = books-clean.
set -uo pipefail
DOCKER=/usr/local/bin/docker
draft="$1"
"$DOCKER" exec fava-custom sh -c "
  printf 'include \"main.beancount\"\ninclude \"import/%s\"\n' \"$draft\" > /data/.draft-gate.beancount
  bean-check /data/.draft-gate.beancount; rc=\$?
  rm -f /data/.draft-gate.beancount
  exit \$rc"
