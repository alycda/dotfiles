# Every tool on a Nix account. It starts as mise.toml's [tools] and is meant to
# outgrow it: mise stays lean for accounts without Nix, so a tool can live here
# alone. Where both have a tool, keep the same major.minor.
{ pkgs }:
let
  # nixpkgs has cheat 4.5.0; mise pins 5.1, and the cheat setup is tested on it.
  # 5.x no longer ships scripts/cheat.{bash,fish,zsh}, so nixpkgs' completion
  # patch and install go; the man page stays.
  cheat = pkgs.cheat.overrideAttrs (_: rec {
    version = "5.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "cheat";
      repo = "cheat";
      tag = version;
      hash = "sha256-0c8NZzzLxssMJffEWBI5L3leWWOU/Y0slPIg6bPKzfI=";
    };
    patches = [ ];
    postInstall = "installManPage doc/cheat.1";
  });
in
[
  pkgs.bat
  cheat
  pkgs.just
  pkgs.jujutsu
  pkgs.helix
  pkgs.gh
  pkgs.claude-code
  pkgs.tmux
  # formatters for `jj fix`
  pkgs.taplo
  pkgs.rumdl
  pkgs.biome
]
