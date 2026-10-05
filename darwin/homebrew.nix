# Homebrew, managed by nix-darwin, for what Nix can't provide: GUI apps as
# casks, and the odd formula. A host with Homebrew imports this (mkDarwin's
# `modules`) and lists its own taps, brews and casks.
#
# nix-darwin doesn't install Homebrew; the Mac must have it already, owned by
# the primary user (system.primaryUser), who runs `brew bundle` at activation.
{ lib, ... }:
{
  homebrew = {
    enable = true;

    # Nothing is removed, updated or upgraded unless the host says so. A host
    # whose lists match what is installed can set cleanup = "zap", which
    # removes anything unlisted on every switch: an omission then uninstalls
    # an app.
    onActivation = {
      cleanup = lib.mkDefault "none";
      autoUpdate = lib.mkDefault false;
      upgrade = lib.mkDefault false;
    };

    # Casks with `auto_updates true` are skipped by `brew upgrade`, on the
    # assumption the app updates itself, which it can't when another account
    # owns it. greedy makes brew upgrade them too (`--greedy`).
    greedyCasks = true;

    # HOMEBREW_BUNDLE_FILE in /etc/zshenv, pointing at the generated Brewfile,
    # so `brew bundle` outside a switch uses the same lists.
    global.brewfile = true;
  };

  # brew on PATH for every account's interactive zsh, from /etc/zshrc, as on
  # main. Not ~/.zprofile, where Homebrew's installer puts it: home-manager
  # takes that file over on the first switch.
  programs.zsh.interactiveShellInit = ''
    eval "$(/opt/homebrew/bin/brew shellenv)"
  '';
}
