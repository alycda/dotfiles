#!/usr/bin/env bats
# tools/zsh/interactive.zsh: it parses, loads cleanly, sets what it says, and
# its chpwd hook reports repositories as documented. Every zsh here runs with
# -f (no rc files) and jj with its own config, so only this file is under test.

setup() {
  repo="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  rc="$repo/tools/zsh/interactive.zsh"
  export JJ_CONFIG="$BATS_TEST_TMPDIR/jj.toml"
  printf '[user]\nname = "t"\nemail = "t@example.com"\n' > "$JJ_CONFIG"
  cd "$BATS_TEST_TMPDIR" || return
}

# in_zsh SCRIPT: run SCRIPT in `zsh -f` after sourcing the file under test.
in_zsh() {
  zsh -f -c "source \"\$1\"; $1" zsh "$rc"
}

@test "it parses" {
  run zsh -n "$rc"
  [ "$status" -eq 0 ]
}

@test "it loads silently" {
  run zsh -f -c 'source "$1"' zsh "$rc"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "it sets its options" {
  in_zsh '[[ -o autocd && -o extendedhistory && -o histreduceblanks && -o histfindnodups ]]'
}

@test "space expands history, and ^X^R is redo" {
  run in_zsh "bindkey ' '; bindkey '^X^R'"
  [ "${lines[0]}" = '" " magic-space' ]
  [ "${lines[1]}" = '"^X^R" redo' ]
}

@test ".. and ... are aliases for cd" {
  run in_zsh 'alias .. ...'
  [ "${lines[0]}" = "..='cd ..'" ]
  [ "${lines[1]}" = "...='cd ../..'" ]
}

@test "typing .. at the prompt goes up a directory" {
  mkdir -p up/down
  run zsh -f "$BATS_TEST_DIRNAME/zsh-at-prompt.zsh" "$rc" "$PWD/up/down" '..'
  [ "$status" -eq 0 ]
  [ "$output" = "$PWD/up" ]
}

@test "typing a directory's name at the prompt enters it (AUTO_CD)" {
  mkdir -p up/down
  run zsh -f "$BATS_TEST_DIRNAME/zsh-at-prompt.zsh" "$rc" "$PWD/up" 'down'
  [ "$status" -eq 0 ]
  [ "$output" = "$PWD/up/down" ]
}

@test "chpwd: entering a jj repo prints @ once; moving inside it is quiet" {
  command -v jj >/dev/null || skip "jj is not installed"
  jj git init repo >/dev/null 2>&1
  mkdir repo/sub
  run in_zsh 'cd repo; cd sub; cd ..'
  [ "${#lines[@]}" -eq 1 ]
  [[ ${lines[0]} == *"(empty)"* ]]
}

@test "chpwd: entering a git repo prints its status" {
  git init -q repo
  run in_zsh 'cd repo'
  [ "$output" = "## No commits yet on main" ] || [ "$output" = "## No commits yet on master" ]
}

@test "chpwd: leaving a repository is quiet" {
  git init -q repo
  mkdir plain
  run in_zsh 'cd repo; cd ../plain'
  # Only the line from entering repo.
  [ "${#lines[@]}" -eq 1 ]
  [[ ${lines[0]} == "## No commits yet"* ]]
}

@test "chpwd: a git repo nested in a jj repo reports as git (nearer root wins)" {
  command -v jj >/dev/null || skip "jj is not installed"
  jj git init outer >/dev/null 2>&1
  git init -q outer/inner
  run in_zsh 'cd outer/inner'
  [[ $output == "## No commits yet"* ]]
}
