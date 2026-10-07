# cheat at the version mise pins. nixpkgs has 4.5.0; mise pins 5.1, and the
# cheat setup (tools/cheat/conf.yml, .cheat/) is tested on it. 5.x no longer
# ships scripts/cheat.{bash,fish,zsh}, so nixpkgs' completion patch and
# install go; the man page stays.
{ pkgs }:
[
  (pkgs.cheat.overrideAttrs (_: rec {
    version = "5.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "cheat";
      repo = "cheat";
      tag = version;
      hash = "sha256-0c8NZzzLxssMJffEWBI5L3leWWOU/Y0slPIg6bPKzfI=";
    };
    patches = [ ];
    postInstall = "installManPage doc/cheat.1";
  }))
]
