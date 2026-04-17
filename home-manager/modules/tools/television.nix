{ pkgs, ... }:

# television (tv): modern fuzzy finder (Rust), channel-based architecture
# Unlike fzf's single-stream model, tv has typed "channels":
#   tv files, tv text, tv git-log, tv git-refs, tv shell-history, tv env, tv alias
# No automatic shell keybindings — invoked explicitly as `tv [channel]`
# Tradeoff: more structured/visual than fzf, but less drop-in for existing workflows
{
  home.packages = [ pkgs.television ];

  # Wire `tv` into Ctrl+R for shell history as an fzf alternative
  # Remove or adjust if using fzf.nix alongside this module
  programs.zsh.initExtra = ''
    tv_history() {
      local selected
      selected=$(tv shell-history 2>/dev/null)
      LBUFFER="$selected"
      zle redisplay
    }
    zle -N tv_history
    bindkey '^R' tv_history
  '';
}
