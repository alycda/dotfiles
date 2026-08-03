{ pkgs, ... }:

let
  # Core packages shared with devShells (defined in lib/core-packages.nix)
  # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
  corePackages = import ../../lib/core-packages.nix pkgs;
in
{
  imports = [
    # Deliberately NOT ./ide/vscode.nix here. common.nix is inherited by every
    # profile, including the headless `dev` devcontainer - and baking the VS Code
    # GUI closure into the x86 image is pure dead weight that overflowed Docker's
    # disk mid-build on the 2012 MBP (see PR #34). GUI editors belong in the
    # desktop profiles (home.nix / work.nix), which import modules/ide/vscode.nix
    # directly. In a container you use VS Code Remote: the GUI runs on the host
    # and connects in, so `code` is never needed inside.
    ./dev/nix-lang.nix
    ./tools/agents.nix
    ./tools/cheat.nix
    ./tools/claude-code.nix
    ./tools/fzf.nix
    ./tools/gh-dash.nix
    ./tools/helix.nix
    ./git.nix
  ];

  home = {
    stateVersion = "25.05";

    # Core packages across all profiles
    # Note: helix is configured via ./tools/helix.nix (programs.helix)
    # Note: claude-code CLI installed here (binary only; global rules managed by ./tools/claude-code.nix)
    packages = corePackages ++ [ pkgs.claude-code pkgs.presenterm ];

    # Set helix as default editor
    sessionVariables = {
      EDITOR = "hx";
    };
  };

  programs = {
    home-manager.enable = true;

    # Enable zsh so home-manager can inject shell hooks (e.g. direnv)
    zsh.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}