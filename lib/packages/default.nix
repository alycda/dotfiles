# The tools on a Nix account: mise.toml's [tools], and meant to outgrow it.
# mise stays lean for accounts without Nix, so a tool can live here alone.
# Where both have a tool, keep the same major.minor.
#
# The list below is what nixpkgs has as is. A tool that needs more (an
# override, a flake input, a release binary) gets its own file in this
# directory, returning a list of packages; every .nix file here besides this
# one is imported. Adding such a tool is adding a file, so tools added side
# by side never conflict over this list.
{ pkgs }:
let
  inherit (pkgs) lib;

  # huid-task and huid-task-edit, in one bin/ so huid-task-edit finds
  # huid-task beside it.
  huid-tasks = pkgs.runCommandLocal "huid-tasks" { } ''
    mkdir -p $out/bin
    cp ${../../tasks/scripts/huid-task} $out/bin/huid-task
    cp ${../../tasks/scripts/huid-task-edit} $out/bin/huid-task-edit
  '';

  files = lib.filter (name: name != "default.nix" && lib.hasSuffix ".nix" name) (
    builtins.attrNames (builtins.readDir ./.)
  );
in
[
  huid-tasks
  pkgs.claude-code
  pkgs.gh
  pkgs.helix
  pkgs.jujutsu
  pkgs.just
  pkgs.tmux
]
++ lib.concatMap (name: import (./. + "/${name}") { inherit pkgs; }) files
