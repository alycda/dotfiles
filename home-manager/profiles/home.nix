# shesfast
{ config, pkgs, ... }:

{
  home.username = "alyssa"; 
  home.homeDirectory = "/Users/alyssa";

  home.packages = with pkgs; [
    # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
  ];
}