# devcontainers / codespaces
{ config, pkgs, ... }:

{
  home = {
    username = "root";
    homeDirectory = "/root";

    packages = with pkgs; [
      docker # on OSX docker/orbstack is installed by homebrew
    ];
  };
}