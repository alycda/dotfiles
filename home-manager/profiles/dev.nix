# devcontainers / codespaces
{ config, pkgs, lib, ... }:

{
  home.username = lib.mkForce "root";
  home.homeDirectory = lib.mkForce "/root";
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    docker # on OSX docker/orbstack is installed by homebrew
  ];
}