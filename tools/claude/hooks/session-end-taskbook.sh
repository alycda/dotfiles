#!/bin/sh
# session-end-taskbook.sh: Claude Code's SessionEnd hook. Leaves one task on
# taskbook's @claude board per session, so `tb` shows where every session was,
# what it was about, and how to resume it. Claude hands the session over on
# stdin as JSON (session_id, transcript_path, cwd, reason, ...). No summary is
# in it, so the recap is read off the transcript (recap below); without jq or
# a readable transcript the task is the resume pointer alone.
#
# It never fails. Whatever goes wrong, it exits 0 and stays quiet, so a missing
# tb or a bare PATH can't make Claude's exit hang or print. A hook runs with the
# environment Claude was started from, which under the desktop app may not
# have mise activated or the Nix profile on PATH, so tb is looked up on PATH
# first, then in the home-manager profiles, then through mise.
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

# recap FILE: one line about the session, from its transcript, fields joined
# by " · ":
#   headline  the /rename title, else the first line of the latest /recap,
#             else the last prompt of four words or more ("post it" says
#             nothing), else the last prompt. Not the AI title: it is set
#             early and goes stale.
#   branch    the last gitBranch recorded.
#   refs      GitHub PRs and issues as repo#N, from prompts, replies and
#             tool output, not from the context Claude Code injects.
#   tasks     HUIDs named in prompts or in files Claude wrote.
#   size      prompts, and the time from first entry to last.
# Prompts are the user's own text: tool results, harness blocks ("<...") and
# meta messages are not. Lines that don't parse are skipped, since the file
# may still be being written.
recap() {
  command -v jq >/dev/null 2>&1 && [ -r "$1" ] || return 0
  jq -R -s -r '
    def clip($n): if length > $n then .[0:$n - 1] + "…" else . end;
    def oneline: gsub("\\s+"; " ") | sub("^ "; "") | sub(" $"; "");
    split("\n") | map(fromjson? // empty) as $all
    | ($all | map(select(.type != "attachment" and (.isMeta | not)))) as $own
    | ($own | map(select(.type == "user" and (.message.content | type == "string"))
        | .message.content | select(startswith("<") | not) | oneline
        | select(. != ""))) as $prompts
    | ( ($all | map(.customTitle // empty) | last)
        // ($all | map(select(.type == "system" and .subtype == "away_summary")
             | .content // empty | tostring | split("\n")[0]) | last)
        // ($prompts | map(select(split(" ") | length >= 4)) | last)
        // ($prompts | last)
        // "" | oneline | clip(80)) as $headline
    | ($all | map(.gitBranch // empty | select(. != "" and . != "HEAD")) | last) as $branch
    | ([$own[] | tostring
        | scan("https://github\\.com/[^/\"\\\\\\s]+/([^/\"\\\\\\s]+)/(?:pull|issues)/([0-9]+)")
        | "\(.[0])#\(.[1])"] | reduce .[] as $r ([]; if index([$r]) then . else . + [$r] end)) as $refs
    | ([ ($prompts[]),
         ($own[] | select(.type == "assistant") | .message.content[]?
           | select(.type == "tool_use" and (.name == "Edit" or .name == "Write"))
           | .input.file_path // empty) ]
        | map(scan("tasks/([0-9]{8}-[0-9]{6})")[0]) | unique) as $tasks
    | ([$all[] | .timestamp // empty | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601? // empty]) as $ts
    | (if ($ts | length) > 1 then (($ts | max) - ($ts | min)) / 60 | floor else null end) as $min
    | [ $headline,
        (if $branch then "on \($branch)" else empty end),
        (if ($refs | length) > 0 then $refs[0:4] | join(", ") else empty end),
        (if ($tasks | length) > 0 then "task " + ($tasks | join(", ")) else empty end),
        ( "\($prompts | length) prompts"
          + (if $min == null then ""
             elif $min < 60 then ", \($min)m"
             else ", \($min / 60 | floor)h\($min % 60)m" end) ) ]
    | map(select(. != "")) | join(" · ")
  ' "$1" 2>/dev/null || true
}

session=$(field session_id)
transcript=$(field transcript_path)
cwd=$(field cwd)
reason=$(field reason)
[ -n "$session" ] || exit 0

tb=$(command -v tb 2>/dev/null || true)
# Standalone home-manager, then home-manager under nix-darwin (useUserPackages).
for candidate in "$HOME/.nix-profile/bin/tb" "/etc/profiles/per-user/$(id -un 2>/dev/null)/bin/tb"; do
  [ -z "$tb" ] && [ -x "$candidate" ] && tb=$candidate
done
if [ -z "$tb" ] && [ -x "$HOME/.local/bin/mise" ]; then
  tb=$("$HOME/.local/bin/mise" which tb 2>/dev/null || true)
fi
[ -n "$tb" ] || exit 0

# TASKBOOK_DIR points tb at another data directory: a bind mount in a
# container, or a scratch one under test.
set -- --cli
[ -n "${TASKBOOK_DIR:-}" ] && set -- "$@" --taskbook-dir "$TASKBOOK_DIR"

pointer="resume: claude --resume $session (in ${cwd:-?}${reason:+, $reason})"
summary=$(recap "$transcript")
desc="${summary:+$summary · }$pointer"
# tb reads @word and p:N out of a new task's description as board and
# priority, so neither may appear in it. Prompts and paths can carry both.
desc=$(printf '%s' "$desc" | tr '@' '_' | sed 's/p:\([0-9]\)/p_\1/g')

# One task per session, kept current. A session can end more than once (/clear,
# then the terminal closes; or it is resumed and exited again), and the ID is
# what makes the item findable. The recap from the latest end replaces the
# earlier one.
id=$("$tb" "$@" --find "$session" 2>/dev/null | grep -F -- "$session" |
  sed -n 's/^[[:space:]]*\([0-9][0-9]*\)\..*/\1/p' | head -n 1)
if [ -n "$id" ]; then
  "$tb" "$@" --edit "@$id" "$desc" >/dev/null 2>&1 || true
else
  "$tb" "$@" --task @claude "$desc" >/dev/null 2>&1 || true
fi
exit 0
