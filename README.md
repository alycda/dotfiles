# dotfiles

## Mise

bare-bones dotfiles (for accounts without Nix or Docker)

## Nix

The flake grows towards the full setup one testable step at a time. So far it
has a single dev shell with `jj` and `just`, the same two tools the Nix
devcontainer installs:

```sh
nix develop       # a shell with jj and just
nix flake check   # evaluate the flake
```

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
