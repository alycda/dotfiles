# the first recipe is the default
_default: check

update:
    nix flake update

check:
    nix flake check

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

# run this ONCE (requires Apple ID)
setup-xcode:
    ./scripts/setup-xcode.sh

# # Complete setup
# setup-all: rebuild "ditto" setup-xcode
#     @echo "✓ Swift dev environment ready!"

# Verify Swift development environment
verify-swift:
    ./scripts/verify-swift-setup.sh