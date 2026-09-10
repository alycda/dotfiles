# Cheat - command-line cheatsheet tool
# Config and cheatsheets live in tools/cheat/ (shared with devShell)
{ pkgs, ... }:
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
        --set-default CHEAT_CONFIG_PATH "${cheatConf}"
    '';
  };
in
{
  home.packages = [ cheatWrapped ];

  # --set-default above, not --set: --set emits an unconditional
  # `export CHEAT_CONFIG_PATH=...` into the wrapper, which clobbers the
  # caller's value. That made this sessionVariables line dead code, and made
  # `CHEAT_CONFIG_PATH=./conf.yml cheat foo` silently read the store config
  # instead - so previewing an edited sheet needed a full rebuild, or an
  # unwrapped cheat. With --set-default the store config is the fallback and
  # an explicit env var wins, which is what both this line and an ad-hoc
  # override expect.
  home.sessionVariables.CHEAT_CONFIG_PATH = "${cheatConf}";
}
