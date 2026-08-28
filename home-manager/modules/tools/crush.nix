# Crush (charmbracelet) declarative config slice.
#
# Providers/models stay in the hand-managed ~/.config/crush/crushrc (its
# api-key lines reference $VARs, never literals). This module owns the JSON
# sibling: crush merges crush.json and crushrc from the same directory
# (verified in crush 0.88.1 load.go; crushrc wins on key conflicts and crush
# warns), so the two files compose instead of fighting - as long as the
# crushrc never sets the keys owned here (global_context_paths, hooks).
#
# global_context_paths is crush's key for ABSOLUTE, always-loaded context
# files (plain context_paths entries are project-relative names). Setting it
# replaces the two built-in defaults (~/.config/crush/CRUSH.md and
# ~/.config/AGENTS.md), so those are listed explicitly to keep them live.
# This loads the cross-tool outbound-comment gate from ~/.agents/rules,
# giving crush the same posture Claude Code gets via CLAUDE.md's
# @rules/outbound-comment-gate.md import.
#
# The gate is enforced mechanically too: a PreToolUse hook (tools/crush/
# outbound-gate.sh) blocks outbound-posting tool calls (exit 2) unless a
# one-shot exact-payload approval exists. Deliberateness, not enforcement:
# approve mode is agent-invocable by design; any edit to body or
# destination re-triggers the gate.
{ config, ... }:
let
  hookPath = "${config.xdg.configHome}/crush/hooks/outbound-gate.sh";
in
{
  xdg.configFile = {
    "crush/hooks/outbound-gate.sh" = {
      source = ../../../tools/crush/outbound-gate.sh;
      executable = true;
    };

    "crush/crush.json".text = builtins.toJSON {
      "$schema" = "https://charm.land/crush.json";
      options = {
        global_context_paths = [
          "${config.xdg.configHome}/crush/CRUSH.md"
          "${config.xdg.configHome}/AGENTS.md"
          "${config.home.homeDirectory}/.agents/rules/outbound-comment-gate.md"
        ];
      };
      hooks.PreToolUse = [
        {
          name = "outbound-gate";
          command = hookPath;
          timeout = 15;
        }
      ];
    };
  };
}
