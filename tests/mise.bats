#!/usr/bin/env bats
# The root mise.toml is formatted. mise runs against a scratch HOME, never
# yours. Whether its tools install is the test job's own `mise install`.

setup() {
  repo="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
  unset MISE_DATA_DIR MISE_CONFIG_DIR MISE_STATE_DIR MISE_CACHE_DIR MISE_GLOBAL_CONFIG_FILE
  # mise also loads every mise.toml in the directories above, so a checkout
  # nested in another (a jj workspace under .claude/worktrees/) would pick up
  # the outer one. Stop the search at the repo.
  MISE_CEILING_PATHS="$(dirname "$repo")"
  export MISE_CEILING_PATHS
  mise trust --quiet "$repo" >/dev/null 2>&1
}

@test "mise.toml is formatted" {
  run mise --cd "$repo" fmt --check
  [ "$status" -eq 0 ]
}
