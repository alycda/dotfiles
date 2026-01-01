# ditto
{ config, pkgs, ... }:

{
  imports = [
    ../modules/dev/rust.nix
  ];

  home.username = "alyssaevans";
  home.homeDirectory = "/Users/alyssaevans";
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