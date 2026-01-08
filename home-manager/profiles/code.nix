#
{ config, pkgs, lib, ... }:

{
  home = {
    username = "code";
    homeDirectory = "/Users/code";

    packages = with pkgs; [
      docker # on OSX docker/orbstack is installed by homebrew
      rustup
    ];

    activation = {
      rustupSetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${pkgs.rustup}/bin/rustup default stable
      '';
    };
  };
}