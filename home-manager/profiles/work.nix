# ditto
{ config, pkgs, lib, ... }:

{
  home.username = lib.mkForce "alyssaevans";
  home.homeDirectory = lib.mkForce "/Users/alyssaevans";
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
    teleport # kubectl
    cmake
    # flutter - managed by puro (manually installed)
    openjdk
    # swig - installed via homebrew (locked tap)
  ];
}