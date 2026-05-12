# Alyssa's dotfiles

These are my dotfiles, managed by [Nix](https://nixos.org/), [Nix-Darwin](https://nix-darwin.org) and [Home Manager](https://github.com/nix-community/home-manager) (via [flakes](https://nixos.wiki/wiki/Flakes)).

```
dotfiles/
├── darwin/
|   ├── profiles/
|   |   ├── alyssa.nix
|   |   └── ditto.nix
|   └── configuration.nix
├── home-manager/
|   ├── modules/
|   |   ├── ide/vscode  # extensions & settings
|   |   └── common.nix
|   └── profiles/
|       ├── dev.nix     # for devcontainers
|       ├── home.nix
|       └── work.nix
├── .devcontainer.json  # Nix Package Manager
├── .gitignore          # Nix artifacts
├── flake.lock
├── flake.nix           # Home Manager config
├── justfile            # Task Runner recipes
└── README.md           
```

### Quickstart
[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/alycda/dotfiles)

## What is Nix?

Nix is three things:

| Thing | What it is | You might use it to... |
|-------|-----------|------------------------|
| **Nix** (language) | A purely functional [language](https://nixos.org/manual/nix/stable/language/) for defining packages and configurations | Write `.nix` files |
| **Nix** (package manager) | A [package manager](https://nixos.org/manual/nixpkgs/stable/) that installs packages in isolation. Like [homebrew](https://brew.sh/). | `nix profile install nixpkgs#ripgrep` |
| **NixOS** (os) | A Linux [distro](https://nixos.org/manual/nixos/stable/) configured entirely by Nix files | Run a fully reproducible system |

You don't need all three. This repo leverages Home Manager with flakes in a [devcontainer](https://containers.dev/) (lightweight Debian with Nix Package Manager).


## Getting started

You need ONE of these:

| Option | What you need | Good for |
|--------|--------------|----------|
| **Devcontainer** | Docker + VSCode with [Remote Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) | Exploring without installing Nix locally |
| **[GitHub Codespaces](https://github.com/features/codespaces/)** | A GitHub account | Exploring in the cloud |
| **Local Nix** | [Nix installed](https://nixos.org/download) | Already have Nix or want to install it |

### macOS setup (Darwin)

`nix-darwin` manages macOS system configuration declaratively, including dock apps, system defaults (defaults write) and Homebrew packages.

Verified end-to-end on a clean tart VM (macOS Tahoe base image), 2026-07-01.

1. [Install Nix](https://nixos.org/download) (official multi-user installer)
1. Enable flakes — the official installer doesn't:
    - `echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf`
    - `sudo launchctl kickstart -k system/org.nixos.nix-daemon`
1. install a few tools to help you get started: `nix profile install helix gh github:NousResearch/hermes-agent`
    - `hx` for editing files before dotfiles are fully configured
    - `gh` convenient to clone these dotfiles, but requires login (git clone https is ok)
    - `hermes` — installed via flake reference here; folds into home-manager once it lands in nixpkgs
1. Trust the third-party Homebrew taps (new `brew` requires this; also needed
   once on existing machines after a brew update):
    - `brew trust cirruslabs/cli getditto/build-infra`
    - `getditto/build-infra` is **private** — `brew bundle` clones it over
      https, so authenticate GitHub first (`gh auth login` + credential helper)
      or pre-tap it from an SSH clone.
1. Move aside the `/etc` files nix-darwin wants to own (first activation only):
    - `for f in /etc/nix/nix.conf /etc/bashrc /etc/zshrc; do sudo mv "$f" "$f.before-nix-darwin"; done`
1. Bootstrap `nix-darwin` (once) — build from this repo's pinned input rather
   than `nix run nix-darwin` (which resolves upstream HEAD via the GitHub API:
   version skew + rate-limited on shared IPs):
    - `nix build .#darwinConfigurations.ditto.system`
    - `sudo ./result/sw/bin/darwin-rebuild switch --flake .#ditto`
1. Rebuild after changes
    - `just _rebuild ditto` (the only `darwinConfiguration` is `ditto`;
      `alyssa@*` names are Linux/devcontainer `homeConfigurations`)

> Gotchas seen on a fresh machine: the user the flake hardcodes
> (`alyssaevans`) must exist before switching; the Homebrew prefix must be
> owned by that user (`sudo chown -R alyssaevans /opt/homebrew`) because
> nix-darwin now runs `brew` as that user; `tailscale-app`'s pkg installer
> fails inside VMs (system-extension approval) — expected in CI, fine on
> hardware.

### Devcontainer (Linux sandboxed environment)

> ! does not support nix-darwin

1. Clone this repo
    - `gh repo clone alycda/dotfiles`
1. Open in VSCode
    - `ms-vscode-remote.remote-containers`
1. Click "Reopen in Container" when prompted
    - or <kbd>CMD</kbd>+<kbd>SHIFT</kbd>+<kbd>P</kbd> > **Dev Containers**
1. You now have `nix` available:
    - `nix-env`
    - `nix profile`
    - [nix-shell](https://nix.dev/tutorials/first-steps/declarative-shell.html)
1. Bootstrap Home Manager (once)
    - `nix run home-manager/master -- switch --flake .#alyssa@dev`
1. You now have `gh`, `hx`, `jj` and `just` available:
    - [github cli](https://cli.github.com/manual/)
    - What is [jujutsu](https://kubamartin.com/posts/introduction-to-the-jujutsu-vcs/)?
    - rebuild with `just` or `just _rebuild`

### Other (Flake) devShell (without Home Manager)

- `nix develop github:alycda/dotfiles` or
- `nix develop github:alycda/dotfiles#tools`
  + `-c cheat -l` immediately run a command AND EXIT

## Why a devcontainer?

As long as you have docker or an [ephemeral environment in the cloud](https://ephemeralenvironments.io/), you can explore my setup without polluting your system.


## How it works

### Structure

| Directory | Tool | Purpose |
|-----------|------|---------|
| `darwin/` | nix-darwin | macOS system config (dock, defaults, homebrew)
| `home-manager/` | Home Manager | User packages and dotfiles (cross-platform)

This keeps package management declarative and reproducible across environments.

---

#### /etc/nix/nix.conf (without nix-darwin)

```nix
allowed-users = @nix-users
build-users-group = nixbld

extra-experimental-features = nix-command flakes
```

### Resources

- [Zero to Nix](https://zero-to-nix.com/)
- [Nix Pills](https://nixos.org/guides/nix-pills/) — Deep dive (dense but thorough)
- [home-manager](https://github.com/nix-community/home-manager) — Manage dotfiles with Nix
- [hame-manager Option Search](https://home-manager-options.extranix.com/)
- [nix-darwin](https://nix-darwin.org)
- [devcontainers](https://containers.dev/) — Container-based dev environments
- [Orbstack](https://orbstack.dev/) — Fast Docker alternative for macOS
- [gh repo clone](https://cli.github.com/manual/gh_repo_clone)
