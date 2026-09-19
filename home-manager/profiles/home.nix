# shesfast
{ config, lib, pkgs, ... }:

{
  imports = [
    ../modules/ide/vscode.nix
  ];

  # Live-edit agent skills from the local checkout (module imported via
  # common.nix; store-copy mode is the default elsewhere). Darwin-gated
  # for symmetry with work.nix, which doubles as a Linux devcontainer.
  agentSkills.liveCheckout =
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "${config.home.homeDirectory}/dotfiles";

  # HackMD: the personal account, matching this machine's identity.
  hackmd.account = "personal";

  # Offsite backup of $HOME (../modules/tools/restic.nix). Darwin only: this
  # is the laptop; a container has nothing to snapshot.
  resticBackup.enable = pkgs.stdenv.hostPlatform.isDarwin;

  home = {
    username = "alyssa";
    homeDirectory = "/Users/alyssa";

    packages = with pkgs; [
      taskbook # interim CLI task manager; desktop-only (Node closure, not for containers)
      # VM management, for verifying a switch on a clean macOS image. Was a
      # cirruslabs/cli brew until that tap's formula stopped loading under
      # Homebrew 6.0 and took activation down with it; pinned below current
      # because tart 2.35.0+ only runs on macOS 26. Both in lib/tart.nix.
      (import ../../lib/tart.nix pkgs)
      # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
    ];
  };
}