{ config, pkgs, ... }:

{
  imports = [
    ./ide/vscode.nix
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
  ];

  # Enable home-manager
  programs.home-manager.enable = true;

  # Enable direnv for project-specific environments
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}