# The nix-darwin system layer every Mac gets: what home-manager, which is per
# user, can't set. Hosts add to it from flake.nix (mkDarwin).
#
# Minimal on purpose, see the parity task (tasks/20261004-222929). Homebrew is not
# managed yet, since its cleanup can remove unlisted casks.
{ lib, pkgs, ... }:
{
  # nix-darwin manages the Nix daemon and /etc/nix/nix.conf from here on.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # /etc/zshrc and /etc/zshenv, which put the Nix profiles on PATH for every
  # zsh, login or not. home-manager's zsh (common.nix) is per user, on top.
  programs.zsh = {
    enable = true;
    # /etc/zshrc is read by every account on the Mac, including one with no
    # home-manager. The module's compinit there takes no flags, so on such an
    # account it asks at every login about the completion dirs compaudit
    # rejects: those owned by another user, such as the admin's Homebrew and
    # the shared Nix profile. Ours passes -i, as common.nix does, to skip them
    # instead.
    enableGlobalCompInit = false;
    # An account with home-manager runs compinit from ~/.zshrc, and its
    # ~/.zshenv (read before this) sets skip_global_compinit, so it is run
    # once, not twice. mkAfter keeps this after anything else here that
    # changes FPATH.
    interactiveShellInit = lib.mkAfter ''
      if [[ -z ''${skip_global_compinit-} ]]; then
        autoload -U compinit && compinit -i
      fi
    '';
  };

  # Fira Code with Nerd Font icons, for every app on the Mac: gh-dash's
  # icons, and a terminal font for starship's.
  fonts.packages = [ pkgs.nerd-fonts.fira-code ];

  # The nix-darwin release this was first switched with. Don't change it on
  # an existing Mac; it pins defaults that later releases may change.
  system.stateVersion = 6;
}
