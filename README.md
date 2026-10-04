# Dotfiles

## [mise-en-place](https://mise.jdx.dev/)

The quickest way to a working setup: `mise install` gets `just` (and `hx`, `tb`), then
`just` lists the recipes.

- `curl https://mise.run | sh` (bash) or `curl https://mise.run/zsh | sh` (see [docs](https://mise.jdx.dev/installing-mise.html#shell-specific-installation-activation))
- `mise install`

## Tasks

Work is tracked in `tasks/`, one directory per task, named with a HUID: a UTC
timestamp matching `[0-9]{8}-[0-9]{6}`. Create one with `just task "Title"`.

The format, and why a timestamp beats a counter in a repo whose history fans
out and octopus-merges, are in [tasks/README.md](tasks/README.md).

## License

[MIT](LICENSE)
