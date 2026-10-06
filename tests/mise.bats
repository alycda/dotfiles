#!/usr/bin/env bats
# The root mise.toml: formatted, its [dotfiles] apply cleanly to a fresh HOME
# (and a second apply changes nothing), zsh started there gets the config, and
# a bad version pin is caught. mise runs against a scratch HOME, never yours.

setup() {
  repo="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
  unset MISE_DATA_DIR MISE_CONFIG_DIR MISE_STATE_DIR MISE_CACHE_DIR MISE_GLOBAL_CONFIG_FILE
  # mise also loads every mise.toml in the directories above, so a checkout
  # nested in another (a jj workspace under .claude/worktrees/) would pick up
  # the outer one's [dotfiles]. Stop the search at the repo.
  MISE_CEILING_PATHS="$(dirname "$repo")"
  export MISE_CEILING_PATHS
  mise trust --quiet "$repo" >/dev/null 2>&1
}

apply() {
  mise --cd "$repo" dotfiles apply --yes
}

@test "mise.toml is formatted" {
  run mise --cd "$repo" fmt --check
  [ "$status" -eq 0 ]
}

@test "every [dotfiles] entry applies to a clean HOME" {
  apply
  run mise --cd "$repo" dotfiles status
  [ "$status" -eq 0 ]
  [[ $output != *missing* && $output != *differs* ]]
  [ -L "$HOME/.config/zsh/dotfiles.zsh" ]
  [ -e "$HOME/.config/zsh/dotfiles.zsh" ]
}

@test "applying again changes nothing" {
  apply
  apply
  [ "$(grep -c 'dotfiles.zsh' "$HOME/.zshrc")" -eq 1 ]
  run mise --cd "$repo" dotfiles diff
  [ "$status" -eq 0 ]
  [[ $output != *differs* ]]
}

@test "zsh started from that HOME gets the config" {
  apply
  # -f skips rc files; source ~/.zshrc explicitly, as a login shell would.
  zsh -f -c 'source ~/.zshrc; [[ -o autocd ]] && alias .. >/dev/null'
}

@test "a bad version pin fails install, which a dry run doesn't catch" {
  fixture="$BATS_TEST_TMPDIR/pin"
  mkdir -p "$fixture"
  # A semver range: mise warns and a dry run passes, but installing fails.
  printf '[tools]\njust = ">=1"\n' > "$fixture/mise.toml"
  mise trust --quiet "$fixture" >/dev/null 2>&1
  run mise --cd "$fixture" install --dry-run
  [ "$status" -eq 0 ]
  run mise --cd "$fixture" install
  [ "$status" -ne 0 ]
}
