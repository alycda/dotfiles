# Zellij, on trial against tmux for interactive sessions
# (cmux > docker > multiplexer > claude | hx | glow | jj), plus `fleet`: the
# fire-and-review loop for parallel agents rebuilt on a background zellij
# session instead of `nohup claude -p`. The whole experiment lives in this
# one module so that dropping it is dropping one import; tmux stays in
# lib/core-packages.nix until zellij has earned the swap.
#
# Why zellij can carry the fleet at all (verified against 0.45.1, the version
# in our pinned nixpkgs): every action takes --session and --pane-id, so a
# script can drive a session nobody is attached to. `list-panes --json` reports
# each pane's name, cwd, command, and exit status; a pane whose command exits
# is held open with its exit code rather than vanishing; and a name set with
# `rename-pane` sticks even when the program inside keeps setting OSC titles.
# That last one is what lets an agent's hook label its own pane.
#
# One headless quirk shaped fleet.sh: `new-tab -- cmd` creates the tab but
# never starts the command while no client is attached. An empty `new-tab`
# followed by `run --tab-id` does.
{ config, lib, pkgs, ... }:
let
  fleet = pkgs.writeShellApplication {
    name = "fleet";
    runtimeInputs = [
      config.programs.zellij.package
      pkgs.jq
      pkgs.gh
    ];
    text = builtins.readFile ../../../tools/zellij/fleet.sh;
  };

  # One hooks block serves both agents: codex's hooks.json deliberately
  # mirrors Claude Code's schema (codex-rs/config/src/hooks_tests.rs, 0.158).
  # Events that one agent does not have are ignored by it. Crush has none of
  # them - only PreToolUse - so crush panes report running/exited and nothing
  # finer; its notifications are terminal escapes gated on window focus.
  hooks = ../../../tools/zellij/hooks.json;
in
{
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

  home = {
    packages = [ fleet ];

    file.".codex/hooks.json".source = hooks;

    # Same deep-merge as claudeManagedSettings in ./claude-code.nix, run after
    # it, so this module stays removable on its own. jq's `*` replaces arrays,
    # so this owns the events it names (UserPromptSubmit, PostToolUse,
    # Notification, PermissionRequest, Stop) outright.
    activation.claudeFleetHooks = lib.hm.dag.entryAfter [ "claudeManagedSettings" ] ''
      settings="$HOME/.claude/settings.json"
      run sh -c '"$1" -s ".[0] * .[1]" "$2" "$3" > "$2.tmp" && mv "$2.tmp" "$2"' \
        _ "${pkgs.jq}/bin/jq" "$settings" "${hooks}"
    '';
  };
}
