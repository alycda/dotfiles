#!/usr/bin/env bash
# allow-commands.sh — Crush PreToolUse hook that pre-approves bash commands
# listed in the sibling `allowed-commands` file.
#
# Why a hook: crush's permissions.allowed_tools matches only a tool name or
# "tool:action", and every bash call is "bash:execute" - so the native list
# can allow all of bash or none of it. A hook returning {"decision":"allow"}
# pre-approves just that call (crush >= 0.89, internal/agent/hooked_tool.go).
#
# Silence ({}) falls through to the normal prompt. Hook decisions aggregate
# deny > allow > none, so outbound-gate.sh still blocks anything it gates
# even if an entry here were to match it.
set -euo pipefail

command="${CRUSH_TOOL_INPUT_COMMAND:-}"
list="${CRUSH_ALLOWED_COMMANDS:-$(dirname "$0")/allowed-commands}"

no_opinion() {
	echo '{}'
	exit 0
}

[[ "${CRUSH_TOOL_NAME:-}" == "bash" && -n "$command" && -r "$list" ]] || no_opinion

# Chaining, pipes, redirects, substitution, subshells, line continuations:
# any of these would let an allowed prefix carry an arbitrary tail.
if [[ "$command" == *$'\n'* ]] || grep -q '[;&|<>`$(){}\\]' <<<"$command"; then
	no_opinion
fi

read -ra words <<<"$command"

while IFS= read -r line || [[ -n "$line" ]]; do
	line="${line%%#*}"
	read -ra prefix <<<"$line"
	((${#prefix[@]} > 0)) || continue
	((${#words[@]} >= ${#prefix[@]})) || continue
	match=true
	for i in "${!prefix[@]}"; do
		if [[ "${words[i]}" != "${prefix[i]}" ]]; then
			match=false
			break
		fi
	done
	if [[ "$match" == true ]]; then
		echo '{"decision":"allow"}'
		exit 0
	fi
done <"$list"

no_opinion
