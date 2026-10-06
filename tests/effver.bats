#!/usr/bin/env bats
# tools/effver/bump-effver against the EffVer rules in CHANGELOG.md's header.
# Each test runs a copy of the script in a temp git repo with its own VERSION
# and CHANGELOG.md, so the repo's are never touched.

setup() {
  repo="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  work="$BATS_TEST_TMPDIR/work"
  mkdir -p "$work/tools/effver"
  cp "$repo/tools/effver/bump-effver" "$work/tools/effver/"
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
