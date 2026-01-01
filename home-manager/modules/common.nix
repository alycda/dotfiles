{ config, pkgs, ... }:

{
  imports = [
    ./ide/vscode.nix
    ./dev/nix-lang.nix
  ];

  home.stateVersion = "25.05";

  # Core packages across all profiles
  home.packages = with pkgs; [
    # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
    ripgrep
    helix
    jujutsu
    just
    gh
    direnv
  ];

  # Enable home-manager
  programs.home-manager.enable = true;
}