# shesfast
{ config, pkgs, ... }:

{
  home = {
    username = "alyssa";
    homeDirectory = "/Users/alyssa";

    packages = with pkgs; [
      # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
    ];
  };
}