{ pkgs, ... }:

let
  # Core packages shared with devShells (defined in lib/core-packages.nix)
  # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
  corePackages = import ../../lib/core-packages.nix pkgs;
in
{
  imports = [
    ./ide/vscode.nix
    ./dev/nix-lang.nix
    ./tools/cheat.nix
    ./tools/claude.nix
    ./git.nix
    ./tools/helix.nix
  ];

  home = {
    stateVersion = "25.05";

    # Core packages across all profiles
    # Note: helix is configured via ./tools/helix.nix (programs.helix)
    # Note: claude-code CLI installed here (binary only, config not managed by home-manager)
    packages = corePackages ++ [ pkgs.claude-code ];

    # Set helix as default editor
    sessionVariables = {
      EDITOR = "hx";
    };
  };

  # Enable home-manager
  programs.home-manager.enable = true;

  # Enable direnv for project-specific environments
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}