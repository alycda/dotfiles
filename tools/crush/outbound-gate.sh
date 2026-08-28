#!/usr/bin/env bash
# outbound-gate.sh — Crush PreToolUse hook enforcing the outbound-message rule
# (port of ~/.claude/rules/outbound-comment-gate.md).
#
# Modes:
#   (no args)  gate mode: runs as a PreToolUse hook. Blocks outbound-posting
#              calls unless a matching one-shot approval exists.
#   approve    approval mode: record a one-shot approval for the exact payload
#              on stdin (the exact bash command, or for MCP tools the exact
#              "<tool_name>:<stdin json>" string shown in the deny message).
#
# Approvals are one-shot and exact-payload: any change to the body, title, or
# destination re-triggers the gate. This is a guardrail for a cooperative
# agent, not an adversarial boundary.
set -euo pipefail

APPROVALS_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/crush/outbound-approvals"

hash_payload() {
	shasum -a 256 | awk '{print $1}'
}

if [[ "${1:-}" == "approve" ]]; then
	mkdir -p "$APPROVALS_DIR"
	payload="$(cat)"
	[[ -n "$payload" ]] || { echo "approve: empty payload on stdin" >&2; exit 1; }
	hash="$(printf '%s' "$payload" | hash_payload)"
	: >"$APPROVALS_DIR/$hash"
	echo "Recorded one-shot approval: $hash"
	exit 0
fi

tool="${CRUSH_TOOL_NAME:-}"
command="${CRUSH_TOOL_INPUT_COMMAND:-}"
input="$(cat || true)"

case "$tool" in
bash) payload="bash:$command" ;;
*) payload="$tool:$input" ;;
esac

is_outbound_bash() {
	local cmd="$1"
	grep -qiE 'gh\s+(pr|issue)\s+(comment|review|create|edit)' <<<"$cmd" && return 0
	grep -qiE 'gh\s+(pr|issue)\s+(close|reopen)\b[^|]*--comment' <<<"$cmd" && return 0
	grep -qiE 'gh\s+release\s+(create|edit)' <<<"$cmd" && return 0
	# gh api mutations against message-ish endpoints; -f/-F/--input imply POST
	if grep -qiE 'gh\s+api\b' <<<"$cmd" &&
		grep -qiE '(-X\s*=?\s*(POST|PATCH|PUT)|--method(=|\s+)(POST|PATCH|PUT)|-[fF]\s|--input\s)' <<<"$cmd" &&
		grep -qiE '(comments|replies|reviews|statuses|/issues([/?[:space:]\"'\'']|$))' <<<"$cmd"; then
		return 0
	fi
	return 1
}

is_outbound_tool() {
	local name
	name="$(tr '[:upper:]' '[:lower:]' <<<"$1")"
	grep -qE 'linear.*(comment|status_update|customer_need)' <<<"$name" && return 0
	grep -qE 'slack.*(send|post|reply|message)' <<<"$name" && return 0
	grep -qE '(email|mail).*send' <<<"$name" && return 0
	grep -qE 'mcp_.*(add_comment|create_comment|post_message|send_message|create_issue|create_pull_request|submit_review)' <<<"$name" && return 0
	return 1
}

gated=false
reason_detail=""
if [[ "$tool" == "bash" ]] && is_outbound_bash "$command"; then
	gated=true
	reason_detail="bash command posts user-visible content"
elif [[ "$tool" != "bash" ]] && is_outbound_tool "$tool"; then
	gated=true
	reason_detail="tool '$tool' posts user-visible content"
fi

if [[ "$gated" != true ]]; then
	echo '{}'
	exit 0
fi

hash="$(printf '%s' "$payload" | hash_payload)"
if [[ -f "$APPROVALS_DIR/$hash" ]]; then
	rm -f "$APPROVALS_DIR/$hash"
	echo '{"decision":"allow","context":"Outbound gate: one-shot approval consumed for this exact payload."}'
	exit 0
fi

cat >&2 <<EOF
OUTBOUND GATE — blocked: $reason_detail.

Required flow:
1. Show the user the FULL rendered body and the destination
   (PR/issue/thread/channel/recipient).
2. Wait for their explicit approval in chat. An earlier instruction like
   "reply to X" authorizes the act, not the unseen content.
3. Record a one-shot approval for this EXACT payload, then retry unchanged:
     printf '%s' '$payload' | ~/.config/crush/hooks/outbound-gate.sh approve
   For a user-approved batch, approve each payload once; one chat approval
   covers the batch.
4. Any change to body/title/destination invalidates the approval and this
   gate will block again.
EOF
exit 2
