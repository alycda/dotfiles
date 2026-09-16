# shesfast
{ config, lib, pkgs, ... }:

{
  imports = [
    ../modules/ide/vscode.nix
    # presenterm + its language server. A desktop-profile import rather than
    # a common.nix one: the VS Code extension carries a nodejs closure and the
    # server is a from-source Rust build, neither of which the headless
    # devcontainer has any use for.
    ../modules/tools/presenterm.nix
  ];

  # Live-edit agent skills from the local checkout (module imported via
  # common.nix; store-copy mode is the default elsewhere). Darwin-gated
  # for symmetry with work.nix, which doubles as a Linux devcontainer.
  agentSkills.liveCheckout =
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "${config.home.homeDirectory}/dotfiles";

  # HackMD: the personal account, matching this machine's identity.
  hackmd.account = "personal";

  home = {
    username = "alyssa";
    homeDirectory = "/Users/alyssa";

    packages = with pkgs; [
      taskbook # interim CLI task manager; desktop-only (Node closure, not for containers)
      # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
    ];
  };
}