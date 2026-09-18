#!/usr/bin/env bash
# Signal notification via `hermes send` (no LLM, no agent loop). Targets the
# Signal home channel (SIGNAL_HOME_CHANNEL in the sending Hermes' .env) - no
# number here.
#
# Box first, then local. While Hermes runs on the remote box (hermes-1), this
# machine's signal-cli is stopped - one daemon per Signal account - so the
# message goes over ssh to a forced command there (hermes-notify: stdin in,
# `hermes send` out, no shell). When the box's gateway container is not running
# (before a cutover, after `cutover.sh back`) that exits non-zero and the local
# route is used, so this is correct in every state without being switched.
# Neither leg sends twice: the local leg only runs when the box leg failed.
#
# notify.log records which leg carried each message (length only, never text).
LOG=/Users/alyssa/ledger-ingest/notify.log
msg="$*"
ts() { date "+%Y-%m-%d %H:%M:%S"; }

if printf '%s' "$msg" | ssh hermes-notify 2>/dev/null; then
    echo "$(ts) box   ok  ${#msg}B" >> "$LOG"
    exit 0
fi
echo "$(ts) box   no  -> local" >> "$LOG"
/Users/alyssa/.local/bin/hermes send -t signal "$msg"
rc=$?
echo "$(ts) local rc=$rc ${#msg}B" >> "$LOG"
exit $rc
