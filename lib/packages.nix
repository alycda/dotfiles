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

  # taskbook's Rust port (mise has it as github:taskbook-sh/taskbook). Its own
  # overlay.nix installs the release binaries as they are, which on Linux ask
  # for /lib64/ld-linux and so don't run on NixOS; built from source instead.
  # The workspace's server (axum, sqlx, Postgres) is left out.
  taskbook = pkgs.rustPlatform.buildRustPackage (finalAttrs: {
    pname = "taskbook";
    version = "1.5.0";
    src = pkgs.fetchFromGitHub {
      owner = "taskbook-sh";
      repo = "taskbook";
      tag = "v${finalAttrs.version}";
      hash = "sha256-zG/w3xUg6dicFFx1Bd/fcsRAS6RxibPp8mwB9fy5fog=";
    };
    cargoHash = "sha256-NLuOE7rdvgqPOEa06u36b+EmWOLWEC3ygJM8lo19ksQ=";
    cargoBuildFlags = [ "--package=taskbook-client" ];
    cargoTestFlags = [
      "--package=taskbook-client"
      "--package=taskbook-common"
    ];
    meta.mainProgram = "tb";
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
  taskbook
  # formatters for `jj fix`
  pkgs.taplo
  pkgs.rumdl
  pkgs.biome
]
