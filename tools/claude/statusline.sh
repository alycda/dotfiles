#!/bin/sh
# Claude Code status line: the numbers /context and /usage would show,
# without leaving the prompt. Claude Code pipes session JSON on stdin and
# renders whatever this prints; see https://code.claude.com/docs/en/statusline
#
#   Opus 5.5 high │ ctx ▓▓▓░░░░░░░ 34% 68k/200k │ 5h 23% ↻2h10m · 7d 41% ↻3d │ $1.23 │ dotfiles ksqwz main
#
# All formatting is one jq call; the only other process is the VCS lookup.
# Every field is optional: rate_limits exists only on Pro/Max after the first
# response, used_percentage is null early in a session, effort is absent on
# models without it. A segment with no data is dropped rather than shown as 0.

input=$(cat)

line=$(printf '%s' "$input" | jq -r '
  def c(code): "\u001b[\(code)m";
  def reset: "\u001b[0m";
  # green under 50, yellow under 80, red from 80: the zone where auto-compact
  # or a rate-limit wall is close enough to change what you do next.
  def heat(p): if p >= 80 then c("31") elif p >= 50 then c("33") else c("32") end;
  def bar(p): ((p / 10) | floor) as $n
    | ([range(0; $n)] | map("▓") | join("")) + ([range($n; 10)] | map("░") | join(""));
  def k(n): if n >= 1000000 then "\((n / 100000 | floor) / 10)M"
            elif n >= 1000 then "\(n / 1000 | floor)k" else "\(n)" end;
  # resets_at is epoch seconds; show the coarsest two units left.
  def until(t): ((t - now) | floor) as $s
    | if $s <= 0 then "now"
      elif $s >= 86400 then "\($s / 86400 | floor)d"
      elif $s >= 3600 then "\($s / 3600 | floor)h\(($s % 3600) / 60 | floor)m"
      else "\($s / 60 | floor)m" end;
  def limit(name; w): if w == null then empty else
      (w.used_percentage | floor) as $p
      | "\(heat($p))\(name) \($p)%\(reset) \(c("2"))↻\(until(w.resets_at))\(reset)" end;

  [
    ( "\(c("1"))\(.model.display_name)\(reset)"
      + (if .effort.level then " \(c("2"))\(.effort.level)\(reset)" else "" end) ),

    ( .context_window as $w
      | if $w.used_percentage == null then empty else
          ($w.used_percentage | floor) as $p
          | "ctx \(heat($p))\(bar($p)) \($p)%\(reset)"
            + " \(c("2"))\(k($w.total_input_tokens))/\(k($w.context_window_size))\(reset)"
        end ),

    ( [ limit("5h"; .rate_limits.five_hour), limit("7d"; .rate_limits.seven_day) ]
      | if length > 0 then join(" · ") else empty end ),

    ( .cost.total_cost_usd // empty | "$\(. * 100 | round / 100)" )
  ] | join(" │ ")
')

# VCS: jj change id + nearest bookmark when in a jj repo, else the git branch.
# --ignore-working-copy keeps this from snapshotting on every render, same
# as the chpwd hook in tools/zsh/interactive.zsh.
dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
vcs=
if [ -n "$dir" ]; then
  if command -v jj >/dev/null 2>&1 &&
     vcs=$(jj -R "$dir" log --ignore-working-copy --no-graph --color=never -r @ \
       -T 'change_id.shortest(5) ++ if(bookmarks, " " ++ bookmarks.join(" "))' 2>/dev/null) &&
     [ -n "$vcs" ]; then
    :
  else
    vcs=$(git -C "$dir" branch --show-current 2>/dev/null)
  fi
  vcs="$(basename "$dir")${vcs:+ $vcs}"
fi

printf '%s' "$line"
[ -n "$vcs" ] && printf ' │ \033[36m%s\033[0m' "$vcs"
printf '\n'
