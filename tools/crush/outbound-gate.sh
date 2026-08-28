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
	# coreutils on linux profiles; perl shasum on stock macOS. Same digest.
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum | awk '{print $1}'
	else
		shasum -a 256 | awk '{print $1}'
	fi
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
	# gist create publishes content; pr merge --body writes a visible message
	grep -qiE 'gh\s+gist\s+create' <<<"$cmd" && return 0
	grep -qiE 'gh\s+pr\s+merge\b[^|]*--body' <<<"$cmd" && return 0
	# any graphql mutation - addComment/addPullRequestReview/etc. all post;
	# over-blocking non-message mutations is the safe side for a gate
	if grep -qiE 'gh\s+api\s+graphql' <<<"$cmd" && grep -qiE '\bmutation\b' <<<"$cmd"; then
		return 0
	fi
	# raw HTTP writes to message APIs bypass gh entirely
	if grep -qiE '\b(curl|wget)\b' <<<"$cmd" &&
		grep -qiE '(api\.github\.com|slack\.com/api|hooks\.slack\.com|api\.linear\.app)' <<<"$cmd" &&
		grep -qiE '(-X\s*=?\s*(POST|PATCH|PUT)|--method(=|\s+)(POST|PATCH|PUT)|--data\b|--data-|-d\s|--json\b|--post-data|--body\b)' <<<"$cmd"; then
		return 0
	fi
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
	grep -qE 'linear.*share_' <<<"$name" && return 0
	grep -qE 'slack.*(send|post|reply|message)' <<<"$name" && return 0
	# A Slack canvas is published into a channel the same way a message is
	grep -qE 'slack.*canvas' <<<"$name" && return 0
	grep -qE '(email|mail).*(send|draft)' <<<"$name" && return 0
	# Google Workspace ships one MCP server per product, so the tool names
	# arrive prefixed mcp_google-<product>_. Chat messages post; a Drive
	# permission change IS publication, whatever the file already said.
	grep -qE 'chat.*(send|post|create).*message' <<<"$name" && return 0
	grep -qE 'drive.*share' <<<"$name" && return 0
	grep -qE 'drive.*(add|create|update|set|delete).*permission' <<<"$name" && return 0
	# Notion writes land in a workspace other people read. Deliberately wider
	# than "comment": a page or database edit is visible content too, and
	# over-blocking is the safe side here.
	grep -qE 'notion.*(create|update|append|duplicate|move|delete)' <<<"$name" && return 0
	# GitHub's MCP tool names don't line up with the generic patterns below:
	# add_issue_comment has no literal "add_comment" in it, and the write
	# paths are spelled issue_write / pull_request_review_write. Both halves
	# require a write verb so the get_*/list_*/search_* readers stay open.
	grep -qE 'github.*(add|create|update|submit|write).*(comment|issue|pull_request|review|release|gist)' <<<"$name" && return 0
	grep -qE 'github.*(issue|pull_request|review)_write' <<<"$name" && return 0
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

# stale approvals are a replay risk: expire anything older than an hour
find "$APPROVALS_DIR" -type f -mmin +60 -delete 2>/dev/null || true

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
