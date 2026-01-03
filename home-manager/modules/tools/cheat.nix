# Cheat - command-line cheatsheet tool
# Config and cheatsheets live in tools/cheat/ (shared with devShell)
{ pkgs, ... }:
let
  cheatsheetsPath = ../../../tools/cheat/cheatsheets;
  cheatConf = import ../../../tools/cheat/conf.nix { inherit pkgs cheatsheetsPath; };
in
{
  home.packages = [ pkgs.cheat ];
  home.sessionVariables.CHEAT_CONFIG_PATH = "${cheatConf}";
}
