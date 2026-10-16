#!/bin/sh
# session-end-taskbook.sh: Claude Code's SessionEnd hook. Leaves one task on
# taskbook's @claude board per session, so `tb` shows where every session was
# and how to resume it. Claude hands the session over on stdin as JSON
# (session_id, cwd, reason, ...). No summary is in it, so the task is a resume
# pointer, not a summary; edit it afterwards, or ask Claude to (tb --mcp).
#
# It never fails. Whatever goes wrong, it exits 0 and stays quiet, so a missing
# tb or a bare PATH can't make Claude's exit hang or print. A hook runs with the
# environment Claude was started from, which under the desktop app may not
# have mise activated, so tb is looked up on PATH first and through mise next.
set -u

input=$(cat) || exit 0
[ -n "$input" ] || exit 0

# field NAME: the string value of a top-level key. jq, then python3, then a
# sed for plain values, which is all these fields ever are.
field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r --arg k "$1" '.[$k] // empty'
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c \
      'import json, sys; print(json.load(sys.stdin).get(sys.argv[1]) or "")' "$1"
  else
    printf '%s' "$input" |
      sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
  fi
}

session=$(field session_id)
cwd=$(field cwd)
reason=$(field reason)
[ -n "$session" ] || exit 0

tb=$(command -v tb 2>/dev/null || true)
if [ -z "$tb" ] && [ -x "$HOME/.local/bin/mise" ]; then
  tb=$("$HOME/.local/bin/mise" which tb 2>/dev/null || true)
fi
[ -n "$tb" ] || exit 0

# TASKBOOK_DIR points tb at another data directory: a bind mount in a
# container, or a scratch one under test.
set -- --cli
[ -n "${TASKBOOK_DIR:-}" ] && set -- "$@" --taskbook-dir "$TASKBOOK_DIR"

# One task per session. A session can end more than once (/clear, then the
# terminal closes), and the ID is what makes the item findable.
if "$tb" "$@" --find "$session" 2>/dev/null | grep -q -- "$session"; then
  exit 0
fi

# tb reads @word and p:N out of the description as board and priority, so
# neither may appear in it. Paths don't carry p:, but @ is legal in them.
cwd=$(printf '%s' "${cwd:-?}" | tr '@' '_')

"$tb" "$@" --task @claude \
  "resume: claude --resume $session (in $cwd${reason:+, $reason})" \
  >/dev/null 2>&1 || true
exit 0
