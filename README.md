# dotfiles

## Mise

bare-bones dotfiles (for accounts without Nix or Docker)

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
