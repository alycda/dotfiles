# devcontainers / codespaces
{ config, pkgs, ... }:

{
  home.username = "root"; 
  home.homeDirectory = "/root";
  home.stateVersion = "24.05";

  home.packages = with pkgs; [
    gh helix jujutsu just
    docker # on OSX docker/orbstack is installed by homebrew
    ripgrep
  ];

  programs.home-manager.enable = true;
}