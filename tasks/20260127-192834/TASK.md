# Zsh

- STATUS: CLOSED
- TAGS: issue-15, zsh, shell, home-manager

## Description

see: <https://github.com/alycda/dotfiles/issues/15>

## Closed

Everything on #15's list is in `tools/zsh/interactive.zsh`, tested by
`tests/zsh.bats`: redo on `^X^R`, magic-space, the chpwd repo hook,
EXTENDED_HISTORY, HIST_REDUCE_BLANKS, HIST_FIND_NO_DUPS, AUTO_CD and the
`..`/`...` aliases. `EDITOR=hx` is set by mise and home-manager. home-manager
owns zsh and sources that file, checked in CI by nix.yml's home job. The issue
itself is closed on GitHub.
