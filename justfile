check:
    nix flake check

export USER := shell("whoami")

manager := if os() == "macos" { "darwin-rebuild" } else { "home-manager" }

_rebuild USER="alyssa@dev":
    {{manager}} switch --flake .#{{USER}}

# darwin requires sudo, so we use home manager on OSX for non-sudo "code" user
_rebuild-code:
    home-manager switch -b backup --flake .#code

# queries and lists all packages installed in the current user's profile
_list-env:
    nix-env -qaP

# displays the packages currently installed in a specified profile
_list-profile:
    nix profile list

# parse file for correct syntax
_nix-check file:
    nix-instantiate --parse {{file}}

build-dry-run:
    nix build .#darwinConfigurations.ditto.system --dry-run