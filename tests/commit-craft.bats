#!/usr/bin/env bats
# commit-craft's check-message: the messages the skill shows as good pass, the
# ones it shows as bad fail, and each mechanical rule reports its own problem.

setup() {
  repo="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  skill="$repo/.claude/skills/commit-craft"
  check="$skill/scripts/check-message"
}

# The Nth ```text block of a Markdown file.
block() {
  awk -v want="$2" '/^```text$/ { n++; on = (n == want); next } /^```$/ { on = 0 } on' "$1"
}

check_msg() {
  run "$check" <<<"$1"
}

@test "the SKILL.md example passes" {
  block "$skill/SKILL.md" 2 >"$BATS_TEST_TMPDIR/msg"
  [ -s "$BATS_TEST_TMPDIR/msg" ]
  run "$check" "$BATS_TEST_TMPDIR/msg"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the good examples pass and the bad ones fail" {
  for n in 1 2 3; do
    run "$check" < <(block "$skill/references/examples.md" "$n")
    [ "$status" -eq 0 ]
  done
  for n in 4 5; do
    run "$check" < <(block "$skill/references/examples.md" "$n")
    [ "$status" -eq 1 ]
  done
}

@test "a subject with a scope, a body and trailers passes" {
  check_msg "$(printf 'hm(zsh): add the history options\n\nWhy and how.\n\nCo-Authored-By: A <a@b>\nClaude-Session: https://x')"
  [ "$status" -eq 0 ]
}

@test "the subject needs an area" {
  check_msg "$(printf 'add the history options\n\nWhy.')"
  [ "$status" -eq 1 ]
  [[ $output == *"<area>(<scope>): <summary>"* ]]
}

@test "the summary starts lowercase, unless it starts with a name in capitals" {
  check_msg "$(printf 'hm: Add the history options\n\nWhy.')"
  [ "$status" -eq 1 ]
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
  [ "$status" -eq 1 ]
  [[ $output == *"the message is empty"* ]]
}
