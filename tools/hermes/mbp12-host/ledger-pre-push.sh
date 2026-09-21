#!/usr/bin/env bash
# ledger pre-push — refuse to push this repo anywhere but the local bare repo.
#
# This ledger holds every account, balance, paystub and statement reference.
# A single `git remote add` pointing at a forge would publish all of it. A
# content scanner is the wrong tool here: the sensitive data IS the content,
# so it would fire on every push and get bypassed by reflex until it was
# useless. Guard the DESTINATION instead — that stays quiet and meaningful.
#
# Override (deliberately, e.g. a real encrypted off-site backup):
#   ALLOW_REMOTE_PUSH=1 git push <remote>

set -uo pipefail

remote_url="${2:-}"
[ -z "$remote_url" ] && exit 0

if [ "${ALLOW_REMOTE_PUSH:-}" = "1" ]; then
    echo "ledger pre-push: destination check OVERRIDDEN for $remote_url" >&2
    exit 0
fi

case "$remote_url" in
    /*|file://*)
        exit 0 ;;                      # local path — the intended bare repo
esac

cat >&2 <<BANNER

  ┌────────────────────────────────────────────────────────────┐
  │  PUSH BLOCKED — ledger may only be pushed locally          │
  └────────────────────────────────────────────────────────────┘

  Destination: $remote_url

  This repository contains complete financial records — account balances,
  paystubs, statement references, institution names. It is meant to live on
  local disk and sync only to /Users/alyssa/git/ledger.git.

  If you genuinely intend an off-site copy, encrypt it first and then:

      ALLOW_REMOTE_PUSH=1 git push <remote>

BANNER
exit 1
