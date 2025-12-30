# Alyssa's dotfiles

These are my dotfiles, managed by [Nix](https://nixos.org/).

```
dotfiles/
├── .devcontainer.json  # NixOS
├── .gitignore          # Nix artifacts
├── README.md           
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

You don't need all three. This repo starts with NixOS in a [devcontainer](https://containers.dev/).


## Getting started

You need ONE of these:

| Option | What you need | Good for |
|--------|--------------|----------|
| **Devcontainer** | Docker + VSCode with [Remote Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) | Exploring without installing Nix locally |
| **[GitHub Codespaces](https://github.com/features/codespaces/)** | A GitHub account | Exploring in the cloud |
| **Local Nix** | [Nix installed](https://nixos.org/download) | Already have Nix or want to install it |

### Devcontainer (sandboxed environment)

1. Clone this repo
    - `gh repo clone alycda/dotfiles`
2. Open in VSCode
    - `ms-vscode-remote.remote-containers`
3. Click "Reopen in Container" when prompted
4. You now have `nix`, `jj` and `gh` available
    - `nix-env`
    - `nix profile`
    - [nix-shell](https://nix.dev/tutorials/first-steps/declarative-shell.html)
    - [github cli](https://cli.github.com/manual/)
    - What is [jujutsu](https://kubamartin.com/posts/introduction-to-the-jujutsu-vcs/)?


## Why devcontainer first?

As long as you have docker or an [ephemeral environment in the cloud](https://ephemeralenvironments.io/), you can explore my setup without polluting your system.


---

### Resources

- [Zero to Nix](https://zero-to-nix.com/)
- [Nix Pills](https://nixos.org/guides/nix-pills/) — Deep dive (dense but thorough)
- [home-manager](https://github.com/nix-community/home-manager) — Manage dotfiles with Nix
- [devcontainers](https://containers.dev/) — Container-based dev environments
- [Orbstack](https://orbstack.dev/) — Fast Docker alternative for macOS
- [gh repo clone](https://cli.github.com/manual/gh_repo_clone)

