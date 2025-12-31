# Alyssa's dotfiles

These are my dotfiles, managed by [Nix](https://nixos.org/) and [Home Manager](https://github.com/nix-community/home-manager) (via [flakes](https://nixos.wiki/wiki/Flakes)).

```
dotfiles/
├── darwin/
|   ├── modules/
|   |   └── homebrew.nix
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

### Devcontainer (Linux sandboxed environment)

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

### macOS setup (Darwin)

`nix-darwin` manages macOS system configuration declaraively, including dock apps, system defaults (defaults write) and Homebrew packages.

1. [Install Nix](https://nixos.org/download)
1. Bootstrap `nix-darwin` (once)
    - `nix run nix-darwin -- switch --flake .ditto` (work)
1. Rebuild after changes
    - `just _rebuild alyssa@work`

## Why devcontainer first?

As long as you have docker or an [ephemeral environment in the cloud](https://ephemeralenvironments.io/), you can explore my setup without polluting your system.


## How it works







```nix



```

This keeps package management declarative and reproducible across environments.

---

### Resources

- [Zero to Nix](https://zero-to-nix.com/)
- [Nix Pills](https://nixos.org/guides/nix-pills/) — Deep dive (dense but thorough)
- [home-manager](https://github.com/nix-community/home-manager) — Manage dotfiles with Nix
- [home-manager Option Search]
- [nix-darwin]
- [devcontainers](https://containers.dev/) — Container-based dev environments
- [Orbstack](https://orbstack.dev/) — Fast Docker alternative for macOS
- [gh repo clone](https://cli.github.com/manual/gh_repo_clone)

