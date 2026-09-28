# Zellij, on trial against tmux for interactive sessions
# (cmux > docker > multiplexer > claude | hx | glow | jj). The whole
# experiment lives in this one module so that dropping it is dropping one
# import; tmux stays in lib/core-packages.nix until zellij has earned the swap.
_: {
  programs.zellij = {
    enable = true;

    # home-manager defaults these to home.shell.enableShellIntegration (on),
    # which starts zellij from every interactive zsh - including the shells
    # inside zellij's own panes and inside `docker exec`. Opt in by typing
    # `zellij`, not by opening a terminal.
    enableZshIntegration = false;
    enableBashIntegration = false;

    settings = {
      # Start locked: every key goes to the program in the pane until Ctrl g.
      # Unlocked, zellij's defaults take Ctrl p/n/o/s/t/h - all of which
      # helix and claude use - and that collision is most of what makes a
      # multiplexer feel broken around an editor.
      default_mode = "locked";

      # Without a config, a fresh session opens a setup wizard in a floating
      # pane. Harmless attached; in a session nobody is attached to it is
      # focus-stealing clutter.
      show_startup_tips = false;
      show_release_notes = false;
    };
  };
}
