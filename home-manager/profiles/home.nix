# shesfast
{ config, pkgs, ... }:

{
  home.username = "alyssa"; 
  home.homeDirectory = "/Users/alyssa";
  home.stateVersion = "24.05";

  home.packages = with pkgs; [
    gh helix jujutsu just
    # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
    ripgrep
  ];

  programs.home-manager.enable = true;
}