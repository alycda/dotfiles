#!/usr/bin/env bash
# fleet — fire-and-review for parallel agents, on zellij.
#
# The tmux-era version ran `nohup claude -p … > TICKET.out &` and read state
# back out of the .out file - which froze the moment the headless turn ended,
# so a ticket finished later in another session still showed NEEDS YOU. The
# fix then was "stop trusting the log for state".
#
# Here there is no log to trust. Each agent runs *interactively* in its own
# tab of one background zellij session, so the session is the state:
#   - running / exited + exit code  come from zellij itself (list-panes)
#   - needs-input / idle + reason   the agent writes into its own pane name
#                                   through a lifecycle hook (`fleet hook`)
#   - done                          is a merged PR, asked of gh, not the agent
# and "resume" is focusing the pane, not `claude -c`: the conversation never
# stopped.
#
# Pane names are "TICKET · state · reason". `fleet status` parses them back.
set -euo pipefail

SESSION="${FLEET_SESSION:-fleet}"
SEP=' · '

usage() {
	cat <<'EOF'
fleet - parallel agents in a background zellij session

  fleet fire TICKET "intent" [-a claude|codex|crush] [-C dir]
                          start an interactive agent in its own tab
  fleet status            one line per agent: state, reason, how to resume
  fleet go TICKET         jump to that agent's pane
  fleet sweep [-n]        close tabs whose PR has merged (-n: dry run)
  fleet hook STATE        called by agent hooks; labels the calling pane

Agent defaults to $FLEET_AGENT, else claude. Session is $FLEET_SESSION,
else "fleet". Directory defaults to ./TICKET if it exists, else $PWD.
EOF
}

die() {
	echo "fleet: $*" >&2
	exit 1
}

# Live sessions only. `list-sessions --short` also lists EXITED sessions kept
# for resurrection (e.g. after a container restart), and actions against one
# print "There is no active session!" yet exit 0.
session_state() {
	zellij list-sessions --no-formatting 2>/dev/null |
		awk -v s="$SESSION" '$1 == s { print (/EXITED/ ? "exited" : "live"); exit }'
}

session_exists() {
	case "$(session_state)" in
	live) return 0 ;;
	exited)
		die "session '$SESSION' has exited (container restart?). Resurrect it with
  zellij attach $SESSION      (each agent waits for Enter before re-running
                               its original prompt - claude -c may suit better)
or discard it with
  zellij delete-session $SESSION"
		;;
	*) return 1 ;;
	esac
}

z() { zellij --session "$SESSION" "$@"; }

# Agent panes only: plugins and the session's default shell have no
# terminal_command, every `fleet fire` pane does.
agent_panes() {
	z action list-panes --json --command --state --all |
		jq -c '.[] | select((.is_plugin | not) and .terminal_command != null)'
}

pane_for() {
	agent_panes | jq -r --arg t "$1" --arg sep "$SEP" \
		'select((.title | split($sep))[0] == $t) | "\(.id) \(.tab_id)"' | head -n1
}

agent_argv() {
	local agent="$1" prompt="$2"
	case "$agent" in
	# Interactive, not -p: the session stays open for review and follow-up.
	claude) printf '%s\0' claude --permission-mode acceptEdits "$prompt" ;;
	codex) printf '%s\0' codex "$prompt" ;;
	crush) printf '%s\0' crush ;;
	*) die "unknown agent '$agent' (claude|codex|crush)" ;;
	esac
}

cmd_fire() {
	local ticket="${1:-}" intent="${2:-}" agent="${FLEET_AGENT:-claude}" dir=""
	[ -n "$ticket" ] && [ -n "$intent" ] || die 'usage: fleet fire TICKET "intent" [-a agent] [-C dir]'
	shift 2
	while getopts 'a:C:' opt; do
		case "$opt" in
		a) agent="$OPTARG" ;;
		C) dir="$OPTARG" ;;
		*) die "bad option" ;;
		esac
	done
	[[ "$ticket" != *"$SEP"* ]] || die "ticket may not contain '$SEP'"
	if [ -z "$dir" ]; then
		if [ -d "$ticket" ]; then dir="$PWD/$ticket"; else dir="$PWD"; fi
	fi
	dir="$(cd "$dir" && pwd)"

	session_exists || zellij attach --create-background "$SESSION" >/dev/null
	if [ -n "$(pane_for "$ticket")" ]; then
		die "$ticket is already in the fleet - fleet go $ticket"
	fi

	local prompt="$ticket: $intent"
	local -a argv
	mapfile -d '' argv < <(agent_argv "$agent" "$prompt")

	# new-tab's own initial command does not start in a session with no
	# client attached (zellij 0.45.1); an empty tab plus `run --tab-id` does.
	local tab pane
	tab="$(z action new-tab --name "$ticket" --cwd "$dir")"
	# env: FLEET_TICKET is how `fleet hook` knows which label to write.
	pane="$(z run --tab-id "$tab" --name "$ticket" --cwd "$dir" -- \
		env FLEET_TICKET="$ticket" FLEET_SESSION="$SESSION" "${argv[@]}")"

	if [ "$agent" = crush ]; then
		# crush's TUI takes no prompt argument; type it in once it is up.
		sleep 2
		z action write-chars --pane-id "$pane" "$prompt"
		z action send-keys --pane-id "$pane" Enter
	fi
	echo "🚀 $ticket → $agent in $dir ($SESSION:$pane)"
}

cmd_status() {
	session_exists || {
		echo "no fleet (session '$SESSION' is not running)"
		return 0
	}
	local done_list="" line title command exited code ticket state reason
	while IFS= read -r line; do
		title="$(jq -r .title <<<"$line")"
		command="$(jq -r .terminal_command <<<"$line")"
		exited="$(jq -r .exited <<<"$line")"
		code="$(jq -r '.exit_status // ""' <<<"$line")"
		ticket="${title%%"$SEP"*}"
		state=""
		reason=""
		if [[ "$title" == *"$SEP"* ]]; then
			state="${title#*"$SEP"}"
			reason="${state#*"$SEP"}"
			state="${state%%"$SEP"*}"
			[ "$reason" != "$state" ] || reason=""
		fi
		if [ "$exited" = true ]; then
			if [ "$code" = 0 ]; then
				done_list+="${done_list:+, }$ticket"
			else
				printf '💥 %-16s EXITED %s  → fleet go %s\n' "$ticket" "$code" "$ticket"
			fi
			continue
		fi
		case "$state" in
		needs-input)
			printf '⏸️  %-16s NEEDS YOU  %s → fleet go %s\n' "$ticket" "${reason:-waiting on approval}" "$ticket"
			;;
		idle)
			printf '💬 %-16s YOUR TURN  %s → fleet go %s\n' "$ticket" "${reason:-turn finished}" "$ticket"
			;;
		running) printf '🟢 %-16s RUNNING\n' "$ticket" ;;
		*)
			# No hook has fired yet, so the agent has not taken its prompt:
			# it is starting, or stuck on something that fires no hook
			# (claude's folder-trust dialog, a login). Crush has no hooks at
			# all, so for crush this is all we will ever know.
			if [[ "$command" == *crush* ]]; then
				printf '🟢 %-16s RUNNING    (crush: no hooks, state unknown)\n' "$ticket"
			else
				printf '⏳ %-16s STARTING   no hook yet - startup prompt? → fleet go %s\n' "$ticket" "$ticket"
			fi
			;;
		esac
	done < <(agent_panes)
	[ -z "$done_list" ] || echo "— exited cleanly: $done_list  → fleet sweep"
}

cmd_go() {
	local ticket="${1:-}" hit id tab
	[ -n "$ticket" ] || die "usage: fleet go TICKET"
	session_exists || die "no fleet session '$SESSION'"
	hit="$(pane_for "$ticket")"
	[ -n "$hit" ] || die "$ticket is not in the fleet"
	read -r id tab <<<"$hit"
	if [ -n "${ZELLIJ:-}" ]; then
		# Already inside zellij: hop sessions instead of nesting a client.
		zellij action switch-session "$SESSION" --pane-id "terminal_$id"
	else
		# A tab focused before attaching does not carry over to the new
		# client (it lands on the last-active tab), so focus once it exists.
		(
			sleep 0.5
			z action go-to-tab-by-id "$tab"
			z action focus-pane-id "terminal_$id"
		) >/dev/null 2>&1 &
		exec zellij attach "$SESSION"
	fi
}

cmd_sweep() {
	local dry=""
	[ "${1:-}" != -n ] || dry=1
	session_exists || return 0
	local line title ticket cwd tab pr
	while IFS= read -r line; do
		title="$(jq -r .title <<<"$line")"
		ticket="${title%%"$SEP"*}"
		tab="$(jq -r .tab_id <<<"$line")"
		cwd="$(jq -r '.pane_cwd // empty' <<<"$line")"
		[ -n "$cwd" ] || continue
		# Merged-only: a PR for this checkout's branch that GitHub says merged.
		# Anything else - open, closed unmerged, no PR - keeps its tab.
		pr="$(cd "$cwd" && gh pr view --json state,number \
			--jq 'select(.state == "MERGED") | .number' 2>/dev/null || true)"
		[ -n "$pr" ] || continue
		if [ -n "$dry" ]; then
			echo "would close $ticket (PR #$pr merged)"
		else
			z action close-tab-by-id "$tab"
			echo "🧹 $ticket (PR #$pr merged)"
		fi
	done < <(agent_panes)
}

# Called from agent lifecycle hooks with the event payload on stdin. Must
# never fail or block the agent: outside zellij, or outside the fleet, it
# drains stdin and exits 0.
cmd_hook() {
	local state="${1:-running}" payload reason=""
	payload="$(cat || true)"
	[ -n "${ZELLIJ_PANE_ID:-}" ] || exit 0
	# Interactive sessions outside the fleet get labelled too, named by
	# directory - a waiting claude in your own session is worth a glance.
	local ticket="${FLEET_TICKET:-$(basename "$PWD")}"
	if [ "$state" != running ]; then
		# Claude Notification carries .message; codex PermissionRequest only
		# .tool_name; both Stop payloads may carry .last_assistant_message.
		reason="$(jq -r '.message
			// (if .tool_name then "approve \(.tool_name)" else null end)
			// .last_assistant_message // empty' <<<"$payload" 2>/dev/null |
			tr -s '\n ' ' ' | cut -c1-80 | sed 's/ *$//' || true)"
	fi
	local name="$ticket$SEP$state"
	[ -z "$reason" ] || name+="$SEP$reason"
	zellij action rename-pane --pane-id "terminal_$ZELLIJ_PANE_ID" "$name" >/dev/null 2>&1 || true
}

case "${1:-}" in
fire) shift && cmd_fire "$@" ;;
status | st) cmd_status ;;
go) shift && cmd_go "$@" ;;
sweep) shift && cmd_sweep "$@" ;;
hook) shift && cmd_hook "$@" ;;
-h | --help | help | "") usage ;;
*) die "unknown command '$1' (see fleet --help)" ;;
esac
