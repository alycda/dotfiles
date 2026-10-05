# The dev profile: the containers, as root or vscode (the Nix devcontainer,
# the Docker image), the Tart VM, and `code`, the Mac account without sudo.
# What a development account gets and a personal one doesn't goes here.
# main had `code` as a profile of its own; it was this one's docker and
# rustup, so they are one profile here.
#
# A profile is a role, not an account: the user comes from mkHome or
# mkDarwin, so one profile serves several users.
{ pkgs, ... }:
{
  imports = [ ../rust.nix ];

  home.packages = [
    pkgs.codecrafters-cli
    # The CLI only. The engine is the host's: OrbStack on a Mac, the
    # mounted socket in a container. On the Tart VM it has none.
    pkgs.docker
    pkgs.glab
    # Nix's language server; helix finds it on PATH with no config.
    pkgs.nil
    pkgs.nodejs
    pkgs.supabase-cli
  ];
}
