# The dev profile: the containers, as root or vscode (the Nix devcontainer,
# the Docker image), the Tart VM, and `code`, the Mac account without sudo.
# What a development account gets and a personal one doesn't goes here.
#
# A profile is a role, not an account: the user comes from mkHome or
# mkDarwin, so one profile serves several users.
{ lib, pkgs, ... }:
{
  imports = [ ../rust.nix ];

  home.packages = [
    pkgs.codecrafters-cli
    # The CLI only. The engine is the host's: OrbStack on a Mac, the
    # mounted socket in a container. On the Tart VM it has none.
    pkgs.docker
    pkgs.glab
    pkgs.hurl
    # Nix's language server; helix finds it on PATH with no config.
    pkgs.nil
    pkgs.nodejs
    pkgs.supabase-cli
  ];

  # bash's config without home-manager's bash, on Linux. The Docker image's
  # base (nixos/nix) already has bash in root's nix-env profile, and two bash
  # binaries in one profile stop activation at installPackages ("a conflict
  # for the following files ... bin/bash"), after the dotfiles are written:
  # a prompt, and no tools. Not on the Tart Mac, whose own bash is 3.2.
  programs.bash.package = lib.mkIf pkgs.stdenv.hostPlatform.isLinux null;
}
