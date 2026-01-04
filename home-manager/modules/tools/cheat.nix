# Cheat - command-line cheatsheet tool
# Config and cheatsheets live in tools/cheat/ (shared with devShell)
{ config, pkgs, ... }:
let
  cheatsheetsPath = ../../../tools/cheat/cheatsheets;
  cheatConf = import ../../../tools/cheat/conf.nix { inherit pkgs cheatsheetsPath; };
  
  # Create a wrapped version of cheat that always has the right config
  cheatWrapped = pkgs.symlinkJoin {
    name = "cheat";
    paths = [ pkgs.cheat ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/cheat \
        --set CHEAT_CONFIG_PATH "${cheatConf}"
    '';
  };
in
{
  home.packages = [ cheatWrapped ];
  
  # Also set it in session variables for consistency
  home.sessionVariables.CHEAT_CONFIG_PATH = "${cheatConf}";
}
