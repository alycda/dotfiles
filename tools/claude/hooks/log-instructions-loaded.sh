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

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

{
	printf '{"ts":"%s","event":' "$ts"
	tr -d '\n'
	printf '}\n'
} >>"$log" 2>/dev/null || exit 0

exit 0
