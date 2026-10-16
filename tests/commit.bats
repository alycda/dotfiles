#!/usr/bin/env bats
# The commit message checks: check-commit-msg's rules, and check-commits over
# git and jj ranges. Every repo is a scratch one, with a scratch HOME.
# From alycda/dotfiles#196, without the tests for the skill, the jj config
# and the git hook, which this repo does not have yet.

setup() {
  repo="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  check="$repo/tools/commit/check-commit-msg"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export PATH="$repo/tools/commit:$PATH"
  export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t \
    GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  export JJ_CONFIG=/dev/null JJ_USER=t JJ_EMAIL=t@t
  good=$'hm(zsh): add the history options\n\nWhy and how.'
  bad='Updated stuff.'
}

check_msg() {
  run "$check" <<<"$1"
}

git_repo() {
  cd "$BATS_TEST_TMPDIR" && git init -q r && cd r || return
}

jj_repo() {
  command -v jj >/dev/null || skip "no jj"
  cd "$BATS_TEST_TMPDIR" && jj git init r >/dev/null 2>&1 && cd r || return
}

@test "a subject with a scope, a body and trailers passes" {
  check_msg "$(printf '%s\n\nCo-Authored-By: A <a@b>\nClaude-Session: https://x' "$good")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a compound-engineering plan unit can end the subject" {
  check_msg "$(printf 'hm(zsh): add the history options (U3)\n\nWhy.')"
  [ "$status" -eq 0 ]
}

@test "the subject needs an area" {
  check_msg "$(printf 'add the history options\n\nWhy.')"
  [ "$status" -eq 1 ]
  [[ $output == *"<area>(<scope>): <summary>"* ]]
}

@test "the summary starts lowercase, unless it starts with a name in capitals" {
  check_msg "$(printf 'hm: Add the history options\n\nWhy.')"
  [[ $output == *'lowercase ("add", not "Add")'* ]]
  check_msg "$(printf 'huid: HUID check for task files\n\nWhy.')"
  [ "$status" -eq 0 ]
}

@test "past tense and 'this commit' are refused" {
  check_msg "$(printf 'hm: fixed the history options\n\nWhy.')"
  [[ $output == *'"fixed": say what the commit does'* ]]
  check_msg "$(printf 'hm: this commit adds options\n\nWhy.')"
  [[ $output == *'"this": say what the commit does'* ]]
}

@test "the subject has no period and at most 72 characters" {
  check_msg "$(printf 'hm: add the history options.\n\nWhy.')"
  [[ $output == *"ends with a period"* ]]
  check_msg "hm: $(printf 'x%.0s' {1..70})"$'\n\nWhy.'
  [[ $output == *"74 characters, more than 72"* ]]
}

@test "a body is required, after a blank line" {
  check_msg "hm: add the history options"
  [[ $output == *"there is no body"* ]]
  check_msg "$(printf 'hm: add the history options\n\nCo-Authored-By: A <a@b>')"
  [[ $output == *"there is no body"* ]]
  check_msg "$(printf 'hm: add the history options\nWhy.')"
  [[ $output == *"a blank line separates"* ]]
}

@test "body lines wrap at 72, except indented lines and URLs" {
  long="$(printf 'x %.0s' {1..40})"
  check_msg "$(printf 'hm: add the history options\n\n%s' "$long")"
  [[ $output == *"line 3: 80 characters"* ]]
  check_msg "$(printf 'hm: add the history options\n\nWhy.\n    %s\nSee https://example.com/%s' "$long" "$long")"
  [ "$status" -eq 0 ]
}

@test "an empty message fails" {
  check_msg ""
  [[ $output == *"the message is empty"* ]]
}

@test "check-commits names each failing git commit and skips merges" {
  git_repo
  git commit -q --allow-empty -m "$good"
  base="$(git rev-parse HEAD)"
  git commit -q --allow-empty -m "$bad"
  git commit -q --allow-empty -m "$good"
  git checkout -q -b side "$base"
  git commit -q --allow-empty -m "$good"
  git checkout -q -
  git merge -q --no-ff --no-edit side
  run check-commits "$base..HEAD"
  [ "$status" -eq 1 ]
  [[ $output == *" Updated stuff."* ]]
  [ "$(grep -c '^[0-9a-f]' <<<"$output")" -eq 1 ]
  run check-commits "HEAD~1..HEAD"
  [ "$status" -eq 0 ]
}

@test "check-commits --jj checks the stack and skips an empty undescribed @" {
  jj_repo
  jj describe -m "$good" 2>/dev/null
  jj new -m "$bad" 2>/dev/null
  jj new 2>/dev/null
  run check-commits --jj
  [ "$status" -eq 1 ]
  [[ $output == *" Updated stuff."* ]]
  jj describe -r @- -m "$good" 2>/dev/null
  run check-commits --jj
  [ "$status" -eq 0 ]
}
