# Personal desktops: shesfast (aarch64-darwin, via nix-darwin or standalone
# as alyssa@home) and slowpoke (x86_64-linux, via the NixOS module).
#
# Unlike work.nix, this profile is never instantiated for a container, so it
# has no headless variant to gate against: everything here assumes a real
# machine with a ~/dotfiles checkout.
{ config, pkgs, ... }:

let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  imports = [
    ../modules/ide/vscode.nix
  ];

  # Live-edit agent skills from the local checkout (module imported via
  # common.nix; store-copy mode is the default elsewhere). This used to be
  # darwin-gated "for symmetry with work.nix", but work.nix gates it because
  # that profile doubles as a Linux *devcontainer* with no checkout - a
  # container fact, not a Linux one. The Linux desktop has the checkout, so
  # the gate here would have silently downgraded it to store-copy mode.
  agentSkills.liveCheckout = "${config.home.homeDirectory}/dotfiles";

  # HackMD: the personal account, matching this machine's identity.
  hackmd.account = "personal";

  home = {
    username = "alyssa";
    # macOS and Linux disagree on where home directories live. Under the
    # nix-darwin / NixOS modules home-manager derives this from the system
    # user and these values must merely agree with it; standalone
    # (alyssa@home) they are the only definition.
    homeDirectory = if isDarwin then "/Users/alyssa" else "/home/alyssa";

    packages = [
      pkgs.taskbook # interim CLI task manager; desktop-only (Node closure, not for containers)
      # docker on OSX is installed by homebrew (Docker Desktop/Orbstack).
      # Not installed on the Linux desktop either: the dev container existed
      # to get a modern toolchain onto frozen macOS, and native NixOS on the
      # same hardware makes it moot. `virtualisation.docker` in the NixOS
      # profile is the switch if that changes.
    ];
  };
}
