#!/usr/bin/env bash
# Signal notification via `hermes send` (no LLM, no agent loop). Targets the
# Signal home channel (SIGNAL_HOME_CHANNEL in the sending Hermes' .env) - no
# number here.
#
# Local first, then the box. Hermes runs on THIS machine, so the local
# `hermes send` is the live route. The box leg (hermes-notify: a forced
# command over ssh, stdin in, `hermes send` out, no shell) stays as a second
# try: it only delivers when a cutover has moved Hermes to the box, and
# otherwise exits non-zero in ~3s. Keeping both legs and only choosing the
# ORDER is what makes this file correct in every state - a cutover in either
# direction costs at most one dead leg, never a lost message.
#
# Both legs are never taken on a success: the box leg only runs when the
# local leg failed.
#
# notify.log records which leg carried each message (length only, never text).
LOG=/Users/alyssa/ledger-ingest/notify.log
msg="$*"
ts() { date "+%Y-%m-%d %H:%M:%S"; }

if /Users/alyssa/.local/bin/hermes send -t signal "$msg"; then
    echo "$(ts) local ok  ${#msg}B" >> "$LOG"
    exit 0
fi
echo "$(ts) local no  -> box" >> "$LOG"
printf '%s' "$msg" | ssh hermes-notify 2>/dev/null
rc=$?
echo "$(ts) box   rc=$rc ${#msg}B" >> "$LOG"
exit $rc
