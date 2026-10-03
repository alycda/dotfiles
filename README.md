# Dotfiles

## [Jujutsu](https://www.jj-vcs.dev/latest/)

`mise install` gets `jj` too. The repo _may_ be [colocated](https://docs.jj-vcs.dev/latest/git-compatibility/#colocated-jujutsugit-repos) (`.jj/` next to `.git/`),
so git tools keep working; in a fresh clone, `jj git init --colocate` sets it
up.

## [mise-en-place](https://mise.jdx.dev/)

The quickest way to a working setup: `mise install` gets `just` (and `hx`, `tb`), then
`just` lists the recipes.

- `curl https://mise.run | sh` (bash) or `curl https://mise.run/zsh | sh` (see [docs](https://mise.jdx.dev/installing-mise.html#shell-specific-installation-activation))
- `mise install`
- `mise exec -- just identity`: creates an SSH key, logs `gh` in, and sets
  git and jj identity from the GitHub account. Each step skips what is
  already done. Once mise is active in your shell, plain `just identity`.

## Tasks

Work is tracked in `tasks/`, one directory per task, named with a HUID: a UTC
timestamp matching `[0-9]{8}-[0-9]{6}`. Create one with `just task "Title"`.

The format, and why a timestamp beats a counter in a repo whose history fans
out and octopus-merges, are in [tasks/README.md](tasks/README.md).

## License

[MIT](LICENSE)
