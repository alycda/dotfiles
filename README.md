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

`flake.nix` has a (minimal) dev shell. Install Nix:

```sh
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh
```

Then open a new terminal, and in the checkout:

```sh
nix --extra-experimental-features 'nix-command flakes' \
  develop -c sh -c 'jj --version && just --version'
```

Flakes are still experimental in Nix, so the flag enables them for this command only.

### /etc/nix/nix.conf

Without nix-darwin, which writes this file itself, it is yours to edit. The
installer puts only `build-users-group = nixbld` in it; this adds two lines:

```
allowed-users = @nix-users
build-users-group = nixbld

extra-experimental-features = nix-command flakes
```

- `extra-experimental-features` turns flakes on for every command, so the
  flag above can be dropped.
- `allowed-users` limits who can use the Nix daemon; the default `*` is every
  account. The installer doesn't create `nix-users`, so create it and add
  yourself first, or only root can use Nix:

  ```sh
  sudo dseditgroup -o create nix-users
  sudo dseditgroup -o edit -a "$USER" -t user nix-users
  ```

  (On Linux, `sudo groupadd nix-users` and `sudo usermod -aG nix-users "$USER"`.)

The daemon reads the file when it starts, so restart it:
`sudo launchctl kickstart -k system/org.nixos.nix-daemon` on macOS, or
`sudo systemctl restart nix-daemon` on Linux.

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
```

Then open a new terminal, and in the checkout run `direnv allow`.

### Coming from mise

mise and the dev shell both put `jj` and `just` on `PATH`. Keep one. To drop
mise, `mise implode --dry-run` lists what it would remove; then remove the
mise binary, its tools and caches, and the line mise's installer added to
`~/.zshrc`:

```sh
mise implode
sed -i '' '/mise activate/d' ~/.zshrc
```

`mise implode` keeps `~/.config/mise` (add `--config` to remove it), and the
links `mise dotfiles apply` made into `tools/` keep working. `jj` and `just`
then come from the dev shell, so only inside the checkout.

### Secrets

home-manager installs the [agenix](https://github.com/yaxitech/ragenix)
secrets in `secrets/` into `~/.local/share/agenix/`, decrypted with the age
key at `~/.age/personal-key.txt`. Without the key it warns and carries on.
The Nix devcontainer and `just docker-run` mount `~/.age` read-only, so the
secrets install there too.

> The secrets here are encrypted to my key. On a fork, make your own key in
> the dev shell. `rage-keygen` writes it readable by you only, and prints its
> public key:

```sh
mkdir -p ~/.age
rage-keygen -o ~/.age/personal-key.txt
```

Then put that public key in `secrets/recipients.txt` in place of mine,
delete my `.age` files, and run `just edit-secret NAME` to create
`secrets/NAME.age` (or edit it) in `$EDITOR`.

## [Docker](https://docs.docker.com/desktop/)

Optional: the `Dockerfile` builds an image with the home-manager setup
activated in it, for a machine without Nix. `just docker-build`, then
`just docker-run` opens zsh in it with the current directory at `/work`.
When `~/.age` exists, `docker-run` mounts it read-only and the container
installs the [secrets](#secrets) as it starts.

On a Mac, either [OrbStack](https://orbstack.dev) or Docker Desktop
provides `docker`. OrbStack is the lighter of the two, and starts faster.
With Homebrew:

```sh
brew install --cask orbstack
open -a OrbStack
```

For Docker Desktop instead, the cask is `docker-desktop` and the app
`Docker`; start it once and accept its terms. Either way, opening the app
starts the daemon, and `docker info` answers once it's up.

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
