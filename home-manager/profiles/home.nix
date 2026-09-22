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
      # Entity-level merge driver (Ataraxy Labs; see the entity-level-git
      # skill). From nixpkgs, not the ataraxy-labs brew tap, for the same
      # reason as tart above: a tap formula that raises aborts activation,
      # and nixpkgs has this one. Desktop-only: ~230 MiB closure, too heavy
      # for lib/core-packages.nix. Ships weave, weave-driver and weave-mcp.
      # Pinned forward: nixpkgs tracks 0.3.6, upstream is on 0.5.4. See
      # lib/weave.nix.
      (import ../../lib/weave.nix pkgs)
      # Entity-level review triage, weave's sibling. Upstream release binary
      # repointed at nixpkgs' openssl - not the brew tap, whose formula can no
      # longer pass its checksum. The reasoning is in lib/inspect.nix.
      (import ../../lib/inspect.nix pkgs)
      # docker on OSX is installed by homebrew (Docker Desktop/Orbstack)
    ];
  };
}