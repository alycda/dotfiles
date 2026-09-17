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
      # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
    ];
  };
}