# shesfast
{ config, pkgs, lib, ... }:

{
  home.username = lib.mkForce "alyssa";
  home.homeDirectory = lib.mkForce "/Users/alyssa";
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
  ];
}