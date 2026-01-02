# 
{ config, pkgs, lib, ... }:

{
  home.username = "code"; 
  home.homeDirectory = "/Users/code";

  home.packages = with pkgs; [
    docker # on OSX docker/orbstack is installed by homebrew
    rustup
  ];

  home.activation = {
    rustupSetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run ${pkgs.rustup}/bin/rustup default stable
    '';
  };
}