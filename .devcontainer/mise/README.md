# extremely minimal dotfiles

A dev container for the account with no Nix and no admin rights.

## Why mise

These are Nix dotfiles. mise is a way to get there, not where they end up.

- **It breaks the bootstrap cycle.** Getting this repo onto a machine takes
  tools that the dotfiles are what install. mise is the smallest thing that
  installs them first.
- **Some machines will never run Nix.** On an account without admin rights, or
  on a machine too old or too temporary to be worth it, mise is the whole
  setup.
- **Nothing is written twice.** Config lives in plain files, such as
  `tools/zsh/interactive.zsh`. The root `mise.toml` links them into `$HOME`
  now, and home-manager can read the same files once it arrives.

## Why Mise AND Nix

The Nix configuration is default, and the rest of the repo builds towards it.
This one checks that the no-Nix path still works on its own. The two provision
the machine by different means, so each gets its own config and its own checks.

## What it checks at this commit

Only the root `mise.toml`: its `[dotfiles]` table is the whole test.

1. mise is installed before VS Code attaches (`onCreateCommand`).
2. `mise trust`, `mise dotfiles apply -y`, then `mise dotfiles status`. Both
   entries should stop reading `missing`.
3. A new terminal opens in zsh. Typing `..` should move up a directory, which
   works only if `~/.zshrc` sourced `interactive.zsh` (it sets `AUTO_CD`).
