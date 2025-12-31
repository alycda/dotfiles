{ config, pkgs, ... }:

{
  imports = [
    ./ide/vscode.nix
  ];

  # Core packages across all profiles
  home.packages = with pkgs; [
    # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
    ripgrep
    helix
    jujutsu
    just
    gh
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Enable home-manager
  programs.home-manager.enable = true;
}