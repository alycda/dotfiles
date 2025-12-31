{ config, pkgs, ... }:

{
  imports = [
    ./ide/vscode.nix
  ];

  home.stateVersion = "24.05";

  # Core packages across all profiles
  home.packages = with pkgs; [
    # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
    ripgrep
    helix
    jujutsu
    just
    gh
  ];

  # Enable home-manager
  programs.home-manager.enable = true;
}