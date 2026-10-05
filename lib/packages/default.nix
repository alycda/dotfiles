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

  # From main's core list (lib/core-packages.nix there), for every Nix
  # account, as there. Nix only: mise.toml gets no new tools.
  pkgs.asciinema
  pkgs.bat
  pkgs.clock-rs
  # curl, file and jq are also what agent skills shell out to.
  pkgs.curl
  pkgs.eza
  # pkgs.file
  # pkgs.gawk
  # pkgs.glab
  pkgs.glow
  # GNU sed; the attribute is gnused (pkgs.sed doesn't exist).
  pkgs.gnused
  pkgs.hcloud
  pkgs.hunk
  pkgs.jq
  # For agent plugins whose scripts are stdlib-only Python.
  pkgs.python3
  # agenix's CLIs on PATH, not only in the dev shell (`just edit-secret`).
  pkgs.rage
  pkgs.ragenix
  pkgs.ripgrep
  # A local key-value store for short non-secret strings. Plaintext on disk:
  # secrets stay in agenix.
  pkgs.skate
  pkgs.supabase-cli
  pkgs.vhs
]
++ lib.concatMap (name: import (./. + "/${name}") { inherit pkgs; }) files
