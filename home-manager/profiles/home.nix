# The home profile. What only that machine gets goes here: personal apps and accounts.
#
# A profile is a role, not an account; see dev.nix.
{ pkgs, ... }:
{
  home.packages = [
    # Tart, macOS only, and unfree (allowed by name in flake.nix).
    pkgs.tart
  ];
}
