# The nix-darwin system layer every Mac gets: what home-manager, which is per
# user, can't set. Hosts add to it from flake.nix (mkDarwin).
#
# Minimal on purpose, see the parity task (tasks/20261004-222929). Homebrew is not
# managed yet, since its cleanup can remove unlisted casks.
{ ... }:
{
  # nix-darwin manages the Nix daemon and /etc/nix/nix.conf from here on.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # /etc/zshrc and /etc/zshenv, which put the Nix profiles on PATH for every
  # zsh, login or not. home-manager's zsh (common.nix) is per user, on top.
  programs.zsh.enable = true;

  # The nix-darwin release this was first switched with. Don't change it on
  # an existing Mac; it pins defaults that later releases may change.
  system.stateVersion = 6;
}
