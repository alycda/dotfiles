{ config, pkgs, ... }:

let
  # Core packages shared with devShells (defined in lib/core-packages.nix)
  # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
  corePackages = import ../../lib/core-packages.nix pkgs;
in
{
  imports = [
    ./shell.nix
    ./ide/vscode.nix
    ./dev/nix-lang.nix
    ./tools/cheat.nix
    ./tools/helix.nix
  ];

  home.stateVersion = "25.05";

  # Core packages across all profiles
  # Note: helix is configured via ./tools/helix.nix (programs.helix)
  home.packages = corePackages;

  # Enable home-manager
  programs.home-manager.enable = true;

  # Enable direnv for project-specific environments
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  
  # Set helix as default editor
  home.sessionVariables = {
    EDITOR = "hx";
  };
}