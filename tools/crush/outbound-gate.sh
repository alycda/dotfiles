#!/usr/bin/env bash
# outbound-gate.sh — Crush PreToolUse hook enforcing the outbound-message rule
# (port of ~/.claude/rules/outbound-comment-gate.md).
#
# Modes:
#   (no args)  gate mode: runs as a PreToolUse hook. Blocks outbound-posting
#              calls unless a matching one-shot approval exists.
#   approve [--file PATH]
#              approval mode: record a one-shot approval for the exact payload
#              ("bash:<command>", or for MCP tools "<tool_name>:<stdin json>",
#              as shown in the deny message), read from PATH or stdin.
#              Agents must use --file: an approve command that carries the
#              payload in its own text (printf '...' | approve) contains the
#              gated command, so the gate blocks the approval itself (#177).
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
	if [[ "${2:-}" == "--file" ]]; then
		[[ -r "${3:-}" ]] || { echo "approve: --file needs a readable path" >&2; exit 1; }
		# $(<) strips trailing newlines, so an editor's final newline is harmless
		payload="$(<"$3")"
	else
		payload="$(cat)"
	fi
	[[ -n "$payload" ]] || { echo "approve: empty payload" >&2; exit 1; }
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
	# reads (list_comments, get_status_updates, ...) are exempt by verb rather
	# than writes listed by verb, so an unforeseen write verb stays gated
	if grep -qE 'linear.*(comment|status_update|customer_need)' <<<"$name" &&
		! grep -qE 'linear_(list|get|search)_' <<<"$name"; then
		return 0
	fi
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
3. Record a one-shot approval for this EXACT payload, then retry unchanged.
   Write the payload below to a file with your file-writing tool (not a
   shell command - one that contains the payload is itself gated), then:
     ~/.config/crush/hooks/outbound-gate.sh approve --file /path/to/payload
   Payload:
$payload
   For a user-approved batch, approve each payload once; one chat approval
   covers the batch.
4. Any change to body/title/destination invalidates the approval and this
   gate will block again.
EOF
exit 2
