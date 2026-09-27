# The home-manager side of the root mise.toml: the same plain files in the same
# places, and the same tools, so a Nix account and a mise account share one
# config. Nothing here is written twice; it points at tools/.
#
# home-manager copies these files into the Nix store rather than linking the
# checkout the way mise does, so an edit takes effect on the next switch.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Append a line to a file this profile doesn't own, once. ~/.zshrc and
  # ~/.gitconfig belong to the image (or the user), so taking them over would
  # clobber them. These are the exact lines mise adds, so an account that has
  # run both never gets a line twice.
  appendLine = file: line: ''
    if ! grep -qxF ${lib.escapeShellArg line} ${file} 2>/dev/null; then
      run sh -c 'printf "%s\n" "$1" >> "$2"' _ ${lib.escapeShellArg line} ${file}
    fi
  '';
  sessionVars = "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh";
in
{
  home.packages = import ../lib/packages.nix { inherit pkgs; };

  # mise sets EDITOR in [env]; here it reaches zsh through hm-session-vars.sh,
  # sourced by the second ~/.zshrc line below.
  home.sessionVariables.EDITOR = "hx";

  xdg.configFile = {
    "zsh/dotfiles.zsh".source = ../tools/zsh/interactive.zsh;
    "helix".source = ../tools/helix;
    "git/ignore".source = ../tools/git/ignore;
    # Not ~/.config/git/config: with no ~/.gitconfig, git writes
    # `git config --global` there, which would put identity in the tracked file.
    "git/dotfiles.gitconfig".source = ../tools/git/config;
    # conf.d, not ~/.config/jj/config.toml, which `jj config set --user` writes.
    "jj/conf.d/dotfiles.toml".source = ../tools/jujutsu/config;
    # mise points CHEAT_CONFIG_PATH here only inside the checkout, which
    # home-manager can't scope. Linked globally instead: inside a repo cheat
    # still finds .cheat/; outside one it reports "no cheatpaths specified"
    # where it would otherwise prompt to create a config.
    "cheat/conf.yml".source = ../tools/cheat/conf.yml;
  };

  home.activation.dotfilesLines = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    appendLine "$HOME/.zshrc" "[[ -r ~/.config/zsh/dotfiles.zsh ]] && source ~/.config/zsh/dotfiles.zsh"
    + appendLine "$HOME/.zshrc" "[[ -r ${sessionVars} ]] && source ${sessionVars}"
    + appendLine "$HOME/.gitconfig" "[include] path = ~/.config/git/dotfiles.gitconfig"
  );

  programs.home-manager.enable = true;
  home.stateVersion = "26.05";
}
