#!/usr/bin/env bats
# tools/effver/bump-effver and check-effver against the EffVer rules in
# CHANGELOG.md's header. Each test runs copies of the scripts in a temp git
# repo with its own VERSION and CHANGELOG.md, so the repo's are never touched.

setup() {
  repo="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  work="$BATS_TEST_TMPDIR/work"
  mkdir -p "$work/tools/effver"
  cp "$repo/tools/effver/bump-effver" "$repo/tools/effver/check-effver" "$work/tools/effver/"
  cd "$work" || return
  # The script finds its root with jj, else git.
  git init -q .
  printf '# Changelog\n\nHeader.\n\n## 0.1.0 (macro) - 2026-10-01\n\n- First.\n' > CHANGELOG.md
}

# bump VERSION EFFORT: write VERSION, then bump it by EFFORT on 2026-10-05.
bump() {
  echo "$1" > VERSION
  run tools/effver/bump-effver "$2" 2026-10-05
}

@test "0.x: meso and micro bump the last number" {
  bump 0.1.0 meso
  [ "$status" -eq 0 ]
  [ "$(cat VERSION)" = 0.1.1 ]
  bump 0.1.1 micro
  [ "$(cat VERSION)" = 0.1.2 ]
}

@test "0.x: macro bumps the middle number and resets the last" {
  bump 0.1.4 macro
  [ "$status" -eq 0 ]
  [ "$(cat VERSION)" = 0.2.0 ]
}

@test "1.x and up: each effort bumps its own number" {
  bump 1.2.3 micro
  [ "$(cat VERSION)" = 1.2.4 ]
  bump 1.2.3 meso
  [ "$(cat VERSION)" = 1.3.0 ]
  bump 1.2.3 macro
  [ "$(cat VERSION)" = 2.0.0 ]
}

@test "the heading goes above the newest version, with the date given" {
  bump 0.1.0 meso
  [ "$status" -eq 0 ]
  [ "$(grep -m 1 '^## ' CHANGELOG.md)" = "## 0.1.1 (meso) - 2026-10-05" ]
  [ "$(grep -c '^## ' CHANGELOG.md)" -eq 2 ]
  # The header above the first heading stays where it was.
  [ "$(sed -n 3p CHANGELOG.md)" = Header. ]
}

@test "a changelog with no version yet gets the heading at the end" {
  printf '# Changelog\n\nHeader.\n' > CHANGELOG.md
  bump 0.0.0 micro
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 CHANGELOG.md)" = "## 0.0.1 (micro) - 2026-10-05" ]
}

@test "an unknown effort fails, changing nothing" {
  cp CHANGELOG.md "$BATS_TEST_TMPDIR/before"
  bump 0.1.0 huge
  [ "$status" -eq 2 ]
  [[ $output == *usage* ]]
  [ "$(cat VERSION)" = 0.1.0 ]
  diff "$BATS_TEST_TMPDIR/before" CHANGELOG.md
}

@test "without VERSION it fails" {
  run tools/effver/bump-effver micro
  [ "$status" -eq 1 ]
  [[ $output == *"no VERSION"* ]]
}

# commit VERSION HEADING [SECTION]: commit VERSION and a CHANGELOG.md whose
# first heading is HEADING, over the tools/ copied in setup. With VERSION
# "-", VERSION is removed.
commit() {
  if [ "$1" = - ]; then rm -f VERSION; else echo "$1" > VERSION; fi
  printf '# Changelog\n\n%s\n\n%s\n' "$2" "${3-- What changed.}" > CHANGELOG.md
  git add -A
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m "$1"
}

check() {
  run tools/effver/check-effver "$@"
}

@test "check-effver: a history of proper bumps passes" {
  commit 0.1.0 "## 0.1.0 (macro) - 2026-10-01"
  commit 0.1.0 "## 0.1.0 (macro) - 2026-10-01" "- What changed, more."
  commit 0.1.1 "## 0.1.1 (meso) - 2026-10-02"
  commit 0.2.0 "## 0.2.0 (macro) - 2026-10-03"
  check HEAD
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "check-effver: commits before VERSION exists are skipped" {
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m "before"
  commit 0.1.0 "## 0.1.0 (macro) - 2026-10-01"
  check HEAD
  [ "$status" -eq 0 ]
}

@test "check-effver: a bump other than the effort calls for fails" {
  commit 0.1.0 "## 0.1.0 (macro) - 2026-10-01"
  commit 0.2.0 "## 0.2.0 (meso) - 2026-10-02"
  check HEAD
  [ "$status" -eq 1 ]
  [[ $output == *"a meso bump of 0.1.0 is 0.1.1"* ]]
}

@test "check-effver: a heading that isn't VERSION fails" {
  commit 0.1.1 "## 0.1.0 (macro) - 2026-10-01"
  check HEAD
  [ "$status" -eq 1 ]
  [[ $output == *"heading is 0.1.0, but VERSION is 0.1.1"* ]]
}

@test "check-effver: a malformed heading fails" {
  commit 0.1.0 "## 0.1.0 - 2026-10-01"
  check HEAD
  [ "$status" -eq 1 ]
  [[ $output == *"not \"## 0.1.0 (macro|meso|micro) - YYYY-MM-DD\""* ]]
}

@test "check-effver: an empty section fails" {
  commit 0.1.0 "## 0.1.0 (macro) - 2026-10-01" ""
  check HEAD
  [ "$status" -eq 1 ]
  [[ $output == *"section of CHANGELOG.md is empty"* ]]
}

@test "check-effver: removing VERSION fails" {
  commit 0.1.0 "## 0.1.0 (macro) - 2026-10-01"
  commit - "## 0.1.0 (macro) - 2026-10-01"
  check HEAD
  [ "$status" -eq 1 ]
  [[ $output == *"VERSION is removed"* ]]
}

@test "check-effver: --require-bump fails a commit that keeps VERSION" {
  commit 0.1.0 "## 0.1.0 (macro) - 2026-10-01"
  commit 0.1.0 "## 0.1.0 (macro) - 2026-10-01" "- More."
  check HEAD
  [ "$status" -eq 0 ]
  check --require-bump HEAD
  [ "$status" -eq 1 ]
  [[ $output == *"VERSION is still 0.1.0"* ]]
}

@test "check-effver: without a range it prints usage" {
  check
  [ "$status" -eq 2 ]
  [[ $output == *usage* ]]
}
