# Dotfiles

These are my NIX dotfiles (so why is mise here? for machines that can't/won't install
Nix, and a supporting path to Nix when secrets/passwords are needed during setup).

If you are following along, you DON'T need to install BOTH mise and Nix, jump [ahead](#nix).

Heads-up if you already use Homebrew: these dotfiles will manage it through
nix-darwin (not yet). nix-darwin's Homebrew module installs what its config
lists, and can be set to remove everything else, so applying them to your Mac
would replace your Homebrew setup with mine. Read the config first.

## [Jujutsu](https://www.jj-vcs.dev/latest/)

`mise install` gets `jj` too. The repo _may_ be [colocated](https://docs.jj-vcs.dev/latest/git-compatibility/#colocated-jujutsugit-repos) (`.jj/` next to `.git/`),
so git tools keep working; in a fresh clone, `jj git init --colocate` sets it
up.

## [mise-en-place](https://mise.jdx.dev/)

The quickest way to a MINIMAL working setup: `mise install` gets a few tools, then `just`
lists the recipes.

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

## [Docker](https://docs.docker.com/desktop/)

Optional: the `Dockerfile` builds an image with the home-manager setup
activated in it, for a machine without Nix. `just docker-build`, then
`just docker-run` opens zsh in it with the current directory at `/work`.

On a Mac, either [OrbStack](https://orbstack.dev) or Docker Desktop
provides `docker`. OrbStack is the lighter of the two, and starts faster.
With Homebrew:

```sh
brew install --cask orbstack          # or: brew install --cask docker-desktop
open -a OrbStack                      # or: open -a Docker; accept its terms
docker info                           # answers once the daemon is up
```

Until one of them is running, `just docker-build` fails with "failed to
connect to the docker API at unix:///var/run/docker.sock". Without Homebrew,
download either from its site.

Both run Linux in a VM of their own, so neither runs inside a macOS VM such
as Tart's: nested virtualization is for Linux guests only. To try the image
in a VM, use a Linux one
(`tart clone ghcr.io/cirruslabs/ubuntu:latest ubuntu`), where Docker Engine
runs directly.

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
