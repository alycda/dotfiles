export USER := shell("whoami")

_rebuild:
    home-manager switch --flake .#alyssa@dev

# queries and lists all packages installed in the current user's profile
_list-env:
    nix-env -qaP

# displays the packages currently installed in a specified profile
_list-profile:
    nix profile list

# parse file for correct syntax
_nix-check file:
    nix-instantiate --parse {{file}}