# devcontainers / codespaces
{ pkgs, ... }:

{
  home = {
    username = "root";
    homeDirectory = "/root";

    packages = with pkgs; [
      docker # on OSX docker/orbstack is installed by homebrew
    ];
  };
}