#
{ config, pkgs, lib, ... }:

{
  home.username = lib.mkForce "code";
  home.homeDirectory = lib.mkForce "/Users/code";
  home.stateVersion = "25.05";

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