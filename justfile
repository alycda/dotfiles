# the first recipe is the default
_default: check

update:
    nix flake update

check:
    nix flake check

check-all:
    nix flake check --all-systems

# Run all linters (statix + deadnix)
[group('lint')]
lint: lint-statix lint-deadnix

# Check for Nix anti-patterns with statix
[group('lint')]
lint-statix:
    nix run nixpkgs#statix -- check .

# Check for unused code with deadnix
[group('lint')]
lint-deadnix:
    nix run nixpkgs#deadnix -- .

# Run all CI checks locally (lint + flake check)
[group('lint')]
ci: lint check

export USER := shell("whoami")

manager := if os() == "macos" { "darwin-rebuild" } else { "home-manager" }

# may require sudo
_rebuild USER="alyssa@dev":
    {{manager}} switch --flake .#{{USER}}

# darwin requires sudo, so we use home-manager for non-sudo "code" user on OSX
_rebuild-code:
    home-manager switch -b backup --flake .#code

# requires sudo
[group('darwin')]
darwin-generations:
    darwin-rebuild --list-generations

# requires sudo
[group('darwin')]
rollback-to generation:
    darwin-rebuild --switch-generation {{generation}}

# queries and lists all packages installed in the current user's profile
_list-env:
    nix-env -qaP

# displays the packages currently installed in a specified profile
_list-profile:
    nix profile list

[group('darwin')]
build-dry-run-darwin USER:
    nix build .#darwinConfigurations.{{USER}}.system --dry-run

build-dry-run USER:
    nix build --dry-run --json .#homeConfigurations."{{USER}}".activationPackage 2>&1 | head -20

eval USER:
    nix eval --json .#homeConfigurations."{{USER}}".config.home.stateVersion

# parse file for correct syntax
_nix-check file:
    nix-instantiate --parse {{file}}

_login:
    gh auth login --web
    claude login

# Build the dev container image from this checkout
[group('docker')]
docker-build:
    ./docker/dev.sh build-local

# Run the dev container, mounting the current directory at /work
[group('docker')]
docker-run dir=invocation_directory():
    ./docker/dev.sh run {{dir}}

# Assemble the combined agent instruction capsule (public layers + local overlay)
[group('agents')]
agents-capsule:
    #!/usr/bin/env bash
    set -euo pipefail
    agents="$HOME/.agents"
    printf 'Agent instruction capsule\n'
    printf 'Source: alycda/dotfiles + private overlay\n'
    printf 'Generated: %s\n' "$(date +%Y-%m-%d)"
    printf 'Version/hash: %s\n' "$(git -C {{justfile_directory()}} rev-parse --short HEAD 2>/dev/null || echo unknown)"
    # AGENTS.md first: the capsule must carry the entrypoint's precedence and
    # composition contract, not just the layer bodies. Its @import lines are
    # dropped — inert in a paste, and the layers are inlined right below.
    for f in AGENTS.md company-values.md personal-constitution.md instructions.private.md; do
      if [ -f "$agents/$f" ]; then
        printf '\n<!-- %s -->\n\n' "$f"
        sed '/^@/d' "$agents/$f"
      fi
    done

# Copy the compiled capsule to the clipboard (macOS pbcopy)
[group('agents')]
agents-copy:
    just agents-capsule | pbcopy && echo "Copied agent capsule to clipboard"