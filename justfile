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