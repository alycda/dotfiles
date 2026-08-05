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
    ./tools/agent-skills.nix
    ./tools/agents.nix
    ./tools/cheat.nix
    ./tools/claude-code.nix
    ./tools/fzf.nix
    ./tools/gh-dash.nix
    ./tools/git-worktree-clone.nix
    ./tools/helix.nix
    ./tools/starship.nix
    ./tools/television.nix
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

    # ...and bash, so those hooks exist there too. The container's root shell in
    # /etc/passwd is the base image's bash, so `docker exec -it dev bash` lands
    # in bash no matter what the Dockerfile CMD says - and until now that shell
    # got NO home-manager config at all (hence the bare `bash-5.3#`). Enabling
    # it makes bash a real fallback rather than a dead end: home-manager writes
    # ~/.bash_profile -> ~/.profile + ~/.bashrc, which is what picks up starship
    # and direnv.
    #
    # NOT free in the container, despite appearances: this module also installs
    # bashInteractive, which collides with the bash the nixos/nix base image
    # already has in root's nix-env profile and aborts activation outright. The
    # dev profile therefore sets `programs.bash.package = null` to take the
    # config without the binary - see home-manager/profiles/dev.nix and
    # docs/solutions/build-errors/home-manager-bash-collides-with-base-image-profile.md.
    bash.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}