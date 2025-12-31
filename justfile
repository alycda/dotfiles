export USER := shell("whoami")

_rebuild USER="alyssa@dev":
    home-manager switch --flake .#{{USER}}

# queries and lists all packages installed in the current user's profile
_list-env:
    nix-env -qaP

# displays the packages currently installed in a specified profile
_list-profile:
    nix profile list

# parse file for correct syntax
_nix-check file:
    nix-instantiate --parse {{file}}