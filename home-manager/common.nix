# The home-manager side of mise.toml's [dotfiles]: the same plain files in the
# same places, and the same tools (lib/packages/), so a Nix account and a
# mise account share one config. Nothing here is written twice; it points at
# tools/.
#
# home-manager copies these files into the Nix store rather than linking the
# checkout the way mise does, so an edit takes effect on the next switch.
{
  lib,
  pkgs,
  ...
}:
let
  # Append a line to a file this profile doesn't own, once. ~/.gitconfig
  # belongs to the user (identity lives there), so taking it over would
  # clobber it. This is the exact line mise adds, so an account that has run
  # both never gets it twice.
  appendLine = file: line: ''
    if ! grep -qxF ${lib.escapeShellArg line} ${file} 2>/dev/null; then
      run sh -c 'printf "%s\n" "$1" >> "$2"' _ ${lib.escapeShellArg line} ${file}
    fi
  '';
in
{
  home.packages = import ../lib/packages { inherit pkgs; };

  # mise sets EDITOR in [env]; here it reaches zsh through ~/.zshenv, which
  # sources hm-session-vars.sh.
  home.sessionVariables.EDITOR = "hx";

  # home-manager owns zsh: ~/.zshenv and ~/.zshrc, with its history defaults
  # and compinit. On an account set up by mise first (or an image's
  # oh-my-zsh), it takes over: switch with -b to move the old ~/.zshrc aside.
  # The settings are still the one plain file mise links, sourced after
  # compinit (initContent's default order), which its ^X^R binding relies on.
  programs.zsh = {
    enable = true;
    initContent = "source ${../tools/zsh/interactive.zsh}";
    # -i: skip completion dirs compaudit rejects instead of asking. It
    # rejects dirs owned by any other user, not just writable ones, so on a
    # shared machine another account's files would prompt at every login (and
    # abort with no terminal).
    completionInit = "autoload -U compinit && compinit -i";
    # Debian and Ubuntu's /etc/zsh/zshrc run their own compinit, without -i,
    # unless this is set. Elsewhere nothing reads it.
    envExtra = "skip_global_compinit=1";
  };

  # direnv loads the flake's dev shell from .envrc; nix-direnv caches it.
  # home-manager hooks it into zsh.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  xdg.configFile = {
    "helix".source = ../tools/helix;
    "git/ignore".source = ../tools/git/ignore;
    # Not ~/.config/git/config: with no ~/.gitconfig, git writes
    # `git config --global` there, which would put identity in the tracked
    # file.
    "git/dotfiles.gitconfig".source = ../tools/git/config;
    # conf.d, not ~/.config/jj/config.toml, which `jj config set --user`
    # writes.
    "jj/conf.d/dotfiles.toml".source = ../tools/jujutsu/config;
    # The directory, so just resolves the global justfile's imports.
    "just".source = ../tools/just;
    # mise points CHEAT_CONFIG_PATH here only inside the checkout, which
    # home-manager can't scope. Linked globally instead: inside a repo cheat
    # still finds .cheat/; outside one it reports "no cheatpaths specified"
    # where it would otherwise prompt to create a config.
    "cheat/conf.yml".source = ../tools/cheat/conf.yml;
  };

  home.activation.dotfilesLines = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    appendLine "$HOME/.gitconfig" "[include] path = ~/.config/git/dotfiles.gitconfig"
  );

  programs.home-manager.enable = true;
  home.stateVersion = "26.05";
}
