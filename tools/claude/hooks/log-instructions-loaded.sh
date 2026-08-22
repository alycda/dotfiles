#!/bin/sh
# Append one JSON line per instruction file Claude Code loads.
#
# Answers "which CLAUDE.md, includes and rules actually loaded, when, and why"
# without opening a session and reading /context. The InstructionsLoaded event
# fires at session start and again whenever a nested CLAUDE.md or a path-scoped
# rule loads lazily; its matcher values are session_start, nested_traversal,
# path_glob_match, include, and compact.
#
# The event has no decision control and Claude Code ignores this script's exit
# code, so the only failure mode worth guarding is one that writes garbage into
# the log. Every path below exits 0.
#
# No jq: the whole event object is passed through verbatim. JSON escapes real
# newlines inside strings as \n, so `tr -d` only removes the pretty-printing
# ones and cannot corrupt a value.
set -eu

log="${XDG_STATE_HOME:-$HOME/.local/state}/claude/instructions-loaded.jsonl"
mkdir -p "$(dirname "$log")" || exit 0

# Roll at 1 MiB, keeping one previous file. This appends several records per
# session and lives on a persistent volume; cleanupPeriodDays sweeps session
# transcripts, not this. One generation back is enough - the log answers "what
# loaded recently", and anything older has been superseded by an activation.
# -f first: redirecting from a missing file is a *shell* error, which 2>/dev/null
# on wc would not have suppressed - it printed on every fresh log.
if [ -f "$log" ] && [ "$(wc -c <"$log")" -ge 1048576 ]; then
	mv -f "$log" "$log.1" 2>/dev/null || :
fi

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Read the event before writing anything. Three separate writes sharing one
# O_APPEND fd could interleave - InstructionsLoaded fires repeatedly per
# session and async:true means invocations overlap - and an empty stdin used
# to emit {"ts":"...","event":} , which is not JSON: one such record makes the
# whole log unreadable to `jq -c .`, not just that line.
event=$(tr -d '\n')

# Only an object is worth logging. Anything else means the payload was not
# what this expects, and a guess would be the garbage the log must not hold.
case $event in
	'{'*) ;;
	*) exit 0 ;;
esac

printf '{"ts":"%s","event":%s}\n' "$ts" "$event" >>"$log" 2>/dev/null || exit 0

exit 0
