# Dotfiles

## [Jujutsu](https://www.jj-vcs.dev/latest/)

`mise install` gets `jj` too. The repo _may_ be colocated (`.jj/` next to `.git/`),
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
- `mise dotfiles apply`: links the configs in `tools/` (helix, zsh, git, jj,
  just) into `$HOME`. `--dry-run` shows what it would change; it leaves an
  existing file alone unless given `--force`.

## [Nix](https://nixos.org/download/)

`flake.nix` has a (minimal) dev shell.

```sh
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh
# Open a new terminal, then in the checkout:
nix --extra-experimental-features 'nix-command flakes' \
  develop -c sh -c 'jj --version && just --version'
```

Flakes are still experimental in Nix, so the flag enables them for this command only.

### direnv

`.envrc` loads the dev shell on entering the checkout, through direnv and
nix-direnv (which caches it):

```sh
nix --extra-experimental-features 'nix-command flakes' \
  profile add nixpkgs#direnv nixpkgs#nix-direnv
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
mkdir -p ~/.config/direnv
echo 'source $HOME/.nix-profile/share/nix-direnv/direnvrc' \
  > ~/.config/direnv/direnvrc
# Open a new terminal, then in the checkout:
direnv allow
```

### Coming from mise

mise and the dev shell both put `jj` and `just` on `PATH`. Keep one: to drop
mise,

```sh
mise implode --dry-run   # lists what it removes
mise implode             # the mise binary, its tools and caches
sed -i '' '/mise activate/d' ~/.zshrc   # the line mise's installer added
```

`mise implode` keeps `~/.config/mise` (add `--config` to remove it), and the
links `mise dotfiles apply` made into `tools/` keep working. `jj` and `just`
then come from the dev shell, so only inside the checkout.

## Global just recipes

`mise dotfiles apply` links `tools/just/` to `~/.config/just`, so
`just -g <recipe>` works from any directory, and runs there:

- `just -g task "Title"` and `just -g task-edit "Title"`: a HUID task (see
  [Tasks](#tasks)), in `tasks/` where the current directory has one, and
  otherwise in `.tasks/`, which the global git ignore keeps out of other
  repos.
- `just -g tasks`: taskbook (`tb --cli`).

`just -g --list` shows them all. Recipes for one machine only go in
`~/.local/share/just/local.just`, which the global justfile imports when it
exists.

## Tasks

Work is tracked in `tasks/`, one directory per task, named with a HUID: a UTC
timestamp matching `[0-9]{8}-[0-9]{6}`. Create one with `just task "Title"`.

The format, and why a timestamp beats a counter in a repo whose history fans
out and octopus-merges, are in [tasks/README.md](tasks/README.md).

## License

[MIT](LICENSE)
