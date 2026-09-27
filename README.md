# dotfiles

## Mise

bare-bones dotfiles (for accounts without Nix or Docker)

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
installs the same tools. In a devcontainer (user `vscode`), switch with the
home-manager this flake pins:

```sh
USER=$(id -un) nix run .#home-manager -- switch --flake ".#vscode@$(uname -m)-linux"
```

home-manager copies the files into the Nix store instead of linking the
checkout, so an edit under `tools/` takes effect on the next switch. It adds
the same lines mise adds to `~/.zshrc` and `~/.gitconfig` rather than owning
those files. cheat's config is linked globally, since home-manager can't limit
it to this repo the way mise's `[env]` does.

nixpkgs follows `nixos-unstable`, pinned in `flake.lock`. `nix flake update`
moves the pin.

## Tasks

Work is tracked in `tasks/`, one directory per task, named with a HUID: a UTC
timestamp matching `[0-9]{8}-[0-9]{6}`. Create one with `just task "Title"`.

The format, and why a timestamp beats a counter in a repo whose history fans
out and octopus-merges, are in [tasks/README.md](tasks/README.md).

Open tasks are listed in VS Code's Explorer by the extension in
[extensions/vscode-huid-tasks](extensions/vscode-huid-tasks/README.md).

## License

Except where otherwise noted, this work is licensed under a
[Creative Commons Attribution 4.0 International License][cc-by] by Alyssa Evans.

[cc-by]: https://creativecommons.org/licenses/by/4.0/
