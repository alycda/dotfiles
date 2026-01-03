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

# ──────────────────────────────────────────────────────────────
# Recipe: setup-ruby
# Description: Installs Ruby 3.3.0 via rbenv, makes it the global version,
#              and installs the CocoaPods and Jazzy gems.
#
# Documentation references:
# • rbenv init – https://github.com/rbenv/rbenv#readme
# • rbenv install – https://github.com/rbenv/ruby-build#readme
# • gem install – https://guides.rubygems.org/command-reference/#gem-install
# ──────────────────────────────────────────────────────────────

setup-ruby:
    # Initialise rbenv for the current shell (zsh in this case)
    eval "$(rbenv init - zsh)"

    # Install Ruby 3.3.0 (requires ruby-build plugin)
    rbenv install 3.3.0

    # Make Ruby 3.3.0 the default for all shells
    rbenv global 3.3.0

    # Refresh shims so the newly‑installed Ruby is visible
    rbenv rehash

    # Install the desired gems globally
    gem install cocoapods jazzy
