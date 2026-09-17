# Alyssa's dotfiles

These are my dotfiles, managed by [Nix](https://nixos.org/), [Nix-Darwin](https://nix-darwin.org) and [Home Manager](https://github.com/nix-community/home-manager) (via [flakes](https://nixos.wiki/wiki/Flakes)).

```
dotfiles/
├── darwin/                 # nix-darwin (macOS system config)
|   ├── modules/
|   |   └── homebrew.nix
|   ├── profiles/
|   |   └── ditto.nix
|   └── configuration.nix
├── home-manager/
|   ├── modules/
|   |   ├── dev/            # language tooling (nix-lang, rust)
|   |   ├── ide/vscode*     # extensions & settings
|   |   ├── tools/          # cheat, helix, gh-dash, agents, claude-code
|   |   ├── common.nix      # shared CLI tools (no GUI)
|   |   └── git.nix
|   └── profiles/           # code, dev (devcontainer), home, work
├── lib/
|   └── core-packages.nix   # packages shared by devShells + home-manager
├── tools/                  # non-Nix tool content
|   ├── agents/             # agent-instruction overlay (AGENTS.md, ...)
|   ├── cheat/              # cheatsheets + cheatpath config
|   ├── claude/             # Claude rules
|   └── helix/              # helix config
├── secrets/                # agenix/ragenix encrypted secrets
├── docker/                 # container notes (per-arch CLAUDE.md) + entrypoint
├── Dockerfile              # multi-arch (x86_64 + arm64) dev image
├── .devcontainer.json      # Nix Package Manager
├── .gitignore              # Nix artifacts
├── flake.lock
├── flake.nix               # Home Manager + darwin config
├── justfile                # Task Runner recipes
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

### Fastest path to a working environment

Step 0 is always the same: stage the age personal key from an existing
machine, or you get a working-but-anonymous environment (activation warns;
no decrypted git identity, no private overlay). Then follow the tree:

```mermaid
flowchart TD
    K0["STEP 0 — always: stage the age personal key<br/>~/.age/personal-key.txt from an existing machine<br/>(without it: no git identity, no private overlay)"]
    K0 --> Q1{admin rights?}

    Q1 -- "yes — fresh machine" --> Q2{nix installed?}
    Q2 -- no --> N1["install Nix, multi-user<br/>(issue #29 one-liner)"]
    N1 --> Q3{OS?}
    Q2 -- yes --> Q3
    Q3 -- macOS --> W1["⚠ ditto only: gh auth BEFORE the switch —<br/>brew bundle clones a private tap over https<br/>mid-activation"]
    W1 --> D1["darwin-rebuild switch --flake .#ditto"]
    Q3 -- Linux --> D2["home-manager switch --flake .#alyssa@work-dev"]

    Q1 -- "no — new user on a set-up machine" --> Q4{"docker app installed globally?<br/>(OrbStack / Docker Desktop, admin's brew)"}
    Q4 -- yes --> C1["open -a OrbStack<br/>(daemon + CLI context for THIS user)"]
    C1 --> C2["curl -fsSL https://raw.githubusercontent.com/<br/>alycda/dotfiles/main/docker/dev.sh | sh -s -- up"]
    C1 -.-> C3["alt: git clone https + VS Code devcontainer<br/>(needs the same daemon)"]
    Q4 -- no --> Q5{"/nix exists? (global daemon)"}
    Q5 -- yes --> Q6{"in nix-users group?<br/>(daemon socket is group-locked)"}
    Q6 -- no --> A1["admin, once:<br/>sudo dseditgroup -o edit -a USER -t user nix-users"]
    A1 --> Q6
    Q6 -- yes --> H1["home-manager switch --flake .#code<br/>⚠ blocked today: profile hardcodes user 'code'"]
    Q5 -- no --> A2[ask admin: install OrbStack or Nix]

    D1 --> S1["STEP 1 — always: just _login<br/>(gh auth login --web + claude login)<br/>per-device OAuth, by design — see note below"]
    D2 --> S1
    C2 --> S1
    H1 --> S1
```

**Step 1 is always `just _login`** (gh + Claude, one recipe): each machine
mints its own per-device OAuth tokens, revocable individually.

> **Why no encrypted PAT?** agenix *could* carry a GitHub PAT
> (`gh` honors `GH_TOKEN`; `gh auth login --with-token` reads one), which
> would make gh work with zero ceremony the moment the age key is staged. I'm
> aware of that path and chose against it: one token shared across machines
> means shared blast radius and revoke-everywhere semantics, and fine-grained
> PAT expiry turns the one-time per-machine login into a recurring
> rotate-and-rekey chore. If you're adapting this repo, that path exists and
> works — it's just not for me.

You need ONE of these:

| Option | What you need | Good for |
|--------|--------------|----------|
| **Devcontainer** | Docker + VSCode with [Remote Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) | Exploring without installing Nix locally |
| **[GitHub Codespaces](https://github.com/features/codespaces/)** | A GitHub account | Exploring in the cloud |
| **Local Nix** | [Nix installed](https://nixos.org/download) | Already have Nix or want to install it |
| **Plain Docker** | Just Docker (no VSCode, no Nix, no gh) | Locked-down machines — e.g. a non-admin macOS user |

### macOS setup (Darwin)

`nix-darwin` manages macOS system configuration declaratively, including dock apps, system defaults (defaults write) and Homebrew packages.

Verified end-to-end on a clean tart VM (macOS Tahoe base image), 2026-07-01.

1. [Install Nix](https://nixos.org/download) (official multi-user installer)
1. Enable flakes — the official installer doesn't:
    - `echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf`
    - `sudo launchctl kickstart -k system/org.nixos.nix-daemon`
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

### Plain Docker (no Nix, no VSCode, no gh — not even git)

For a machine (or user account) where all you have is `docker` — e.g. a fresh
non-admin user on a Mac whose Nix install belongs to another account. Docker
fetches the repo itself (BuildKit remote build context over https):

```sh
curl -fsSL https://raw.githubusercontent.com/alycda/dotfiles/main/docker/dev.sh | sh -s -- up
```

Run it from whatever directory you want mounted at `/work`. Rebuilding after
a flake change is the same one-liner again — there's no local checkout to
keep in sync.

`docker/dev.sh` is the single source of truth for the build and run commands:
the volume set, the working directory and the network mode all live there, and
the `just docker-*` recipes delegate to it. This README deliberately points at
the script rather than repeating its flags — hand-written copies of that
command have drifted from the real one before (#86). The `Dockerfile` header
carries the one annotated copy, with the optional extras (ssh-agent
forwarding, the ragenix key) and troubleshooting.

If you *do* want a local checkout (e.g. to hack on the dotfiles from the
host):

```sh
git clone https://github.com/alycda/dotfiles && cd dotfiles
./docker/dev.sh build-local && ./docker/dev.sh run
```

The build bakes the home-manager closure for your CPU into the image (arm64 →
`alyssa@dev`, amd64 → `alyssa@dev-x86`) and activation happens at container
start. `devhome` persists nix/jj/ssh state across `--rm`; `claude-home` keeps
Claude Code auth in its own volume so a devhome reset never logs you out.
Authenticate `gh` and `claude` once inside; see the `Dockerfile` header for
ragenix keys, ssh-agent forwarding, and troubleshooting.

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
| `lib/` | Nix | `core-packages.nix`, imported by both devShells and home-manager so ephemeral `nix develop` and persistent profiles stay consistent
| `tools/` | (plain files) | Non-Nix tool content wired in by modules: `agents/` instruction overlay, `cheat/` cheatsheets, `claude/` rules, `helix/` config
| `secrets/` | agenix/ragenix | age-encrypted secrets, split by account: `personal/` (git config, private agent overlay), `work/`
| `docker/` + `Dockerfile` | Docker | multi-arch dev image: born for a frozen 2012 MacBook Pro (x86, `docker/CLAUDE.md`), also the no-Nix bootstrap on Apple Silicon (arm64, `docker/CLAUDE-arm64.md`)

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
