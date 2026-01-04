{ config, pkgs, ... }:

{
  imports = [
    ./ide/vscode.nix
    ./dev/nix-lang.nix
    ./tools/cheat.nix
    ./tools/claude.nix
    ./tools/helix.nix
  ];

  home.stateVersion = "25.05";

  # Core packages across all profiles
  # Note: helix is configured via ./tools/helix.nix (programs.helix)
  home.packages = with pkgs; [
    # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
    ripgrep
    jujutsu
    just
    gh
    direnv
  ];

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