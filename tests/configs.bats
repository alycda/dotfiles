#!/usr/bin/env bats
# The plain-file configs [dotfiles] links into $HOME: each loads in the tool
# that reads it, and the git and jj ones never carry identity, which they
# would silently impose over the account's own (see their headers).

setup() {
  repo="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "every TOML file parses" {
  while IFS= read -r f; do
    python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$f" ||
      { echo "does not parse: $f"; return 1; }
  done < <(cd "$repo" && find . -name '*.toml' -not -path './.git/*' -not -path './.jj/*'; echo tools/jujutsu/config)
}

@test "jj loads tools/jujutsu/config as its only user config" {
  JJ_CONFIG="$repo/tools/jujutsu/config" run jj config list
  [ "$status" -eq 0 ]
  [[ $output != *"Config error"* ]]
}

@test "tools/jujutsu/config sets no identity" {
  # Only the file: no JJ_USER/JJ_EMAIL, and outside any repo, so no repo
  # config either.
  cd "$BATS_TEST_TMPDIR" || return
  run env -u JJ_USER -u JJ_EMAIL JJ_CONFIG="$repo/tools/jujutsu/config" jj config list user
  [[ $output != *"user.name"* && $output != *"user.email"* ]]
}

@test "git reads tools/git/config" {
  run git config -f "$repo/tools/git/config" --list
  [ "$status" -eq 0 ]
}

@test "tools/git/config sets no identity or credentials" {
  run git config -f "$repo/tools/git/config" --get-regexp '^(user|credential)\.'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}
