# dotfiles

## Mise

bare-bones dotfiles (for accounts without Nix or Docker)

### taskbook and Claude Code

`tb` ([taskbook](https://github.com/taskbook-sh/taskbook)) is a global mise
tool ([tools/mise/global.toml](tools/mise/global.toml)), so it works from any
directory. `mise run claude-hooks` registers a Claude Code `SessionEnd` hook
that leaves one task per session on the `@claude` board:

```text
resume: claude --resume <session id> (in <directory>, <reason>)
```

The reason is Claude's: `clear`, `resume`, `logout`, `prompt_input_exit` or
`other`. The root `mise.toml` links the hook script,
[session-end-taskbook.sh](tools/claude/hooks/session-end-taskbook.sh), into
`~/.claude/hooks/`. The settings entry is merged in by
[install-hooks](tools/claude/install-hooks), since Claude writes
`~/.claude/settings.json` itself. Without `tb` on the machine the hook exits
quietly. The mise devcontainer runs the same task and bind-mounts the host's
`~/.taskbook`, so a session inside it lands on the same board.

## Nix

The flake grows towards the full setup one testable step at a time. So far it
has a dev shell with the Nix package list, which starts as the tools the root
`mise.toml` installs, at the same versions:

```sh
nix develop       # a shell with the mise tools
nix flake check   # evaluate the flake
```

The package list is [lib/packages.nix](lib/packages.nix). It's meant to
outgrow `mise.toml`, which stays lean for accounts without Nix. Where both have
a tool, keep the versions matched: nixpkgs is behind on cheat, so the list
builds the version mise pins.

### home-manager

[home-manager/common.nix](home-manager/common.nix) is the Nix side of the root
`mise.toml`: it puts the same files from `tools/` in the same places and
installs the same tools. The Nix devcontainer (`.devcontainer.json`) switches
to it on create, so it matches the mise one. To switch again after an edit, in
the container (user `vscode`), use the home-manager this flake pins:

```sh
USER=$(id -un) nix run .#home-manager -- switch -b backup --flake ".#vscode@$(uname -m)-linux"
```

home-manager copies the files into the Nix store instead of linking the
checkout, so an edit under `tools/` takes effect on the next switch.
home-manager owns zsh (`~/.zshrc` and `~/.zshenv`), sourcing the same
`tools/zsh/interactive.zsh` mise links. On an account mise set up first, or
with the image's oh-my-zsh `~/.zshrc`, it takes over: `-b backup` keeps the
old file as `~/.zshrc.backup`. `~/.gitconfig` holds identity, so there it only
adds the line mise adds. cheat's config is linked globally, since
home-manager can't limit it to this repo the way mise's `[env]` does.

nixpkgs follows `nixos-unstable`, pinned in `flake.lock`. `nix flake update`
moves the pin.

## Tasks

Work is tracked in `tasks/`, one directory per task, named with a HUID: a UTC
timestamp matching `[0-9]{8}-[0-9]{6}`. Create one with `just task "Title"`.
The recipe is in just's global justfile ([tools/just](tools/just/justfile)), so
`just -g task` works in any repo.

The format, and why a timestamp beats a counter in a repo whose history fans
out and octopus-merges, are in [tasks/README.md](tasks/README.md).

Open tasks are listed in VS Code's Explorer by the extension in
[extensions/vscode-huid-tasks](extensions/vscode-huid-tasks/README.md).

## jj-stash

[tools/jj-stash](tools/jj-stash/README.md) parks chains of commits out of every
jj UI (`jj log`, VisualJJ, jjk) and restores them unchanged: `push`, `list`,
`show`, `index`, `pop` and `drop`. It's vendored from the jj fork (see
`tools/jj-stash/UPSTREAM`), and mise links it into `~/.local/bin`. It needs
bash 4 or later, which mise can't supply: macOS's `/bin/bash` is 3.2.

## License

Except where otherwise noted, this work is licensed under a
[Creative Commons Attribution 4.0 International License][cc-by] by Alyssa Evans.

[cc-by]: https://creativecommons.org/licenses/by/4.0/
