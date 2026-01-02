# devcontainers / codespaces
{ config, pkgs, ... }:

{
  home.username = "root"; 
  home.homeDirectory = "/root";

  home.packages = with pkgs; [
    docker # on OSX docker/orbstack is installed by homebrew
  ];
}