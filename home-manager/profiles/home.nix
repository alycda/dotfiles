# shesfast
{ config, lib, pkgs, ... }:

{
  imports = [
    ../modules/ide/vscode.nix
    # Deliberately here rather than common.nix: it builds from Go source,
    # and the devcontainer image would freeze the whole toolchain into a
    # layer for a CLI it has no key for. See the module's header comment.
    ../modules/tools/workflowy.nix
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
      # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
    ];
  };
}