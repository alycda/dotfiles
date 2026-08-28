# Crush (charmbracelet) declarative config slice.
#
# Providers/models stay in the hand-managed ~/.config/crush/crushrc (its
# api-key lines reference $VARs, never literals). This module owns the JSON
# sibling: crush merges crush.json and crushrc from the same directory
# (verified in crush 0.88.1 load.go; crushrc wins on key conflicts and crush
# warns), so the two files compose instead of fighting.
#
# global_context_paths is crush's key for ABSOLUTE, always-loaded context
# files (plain context_paths entries are project-relative names). Setting it
# replaces the two built-in defaults (~/.config/crush/CRUSH.md and
# ~/.config/AGENTS.md), so those are listed explicitly to keep them live.
# This loads the cross-tool outbound-comment gate from ~/.agents/rules,
# giving crush the same posture Claude Code gets via CLAUDE.md's
# @rules/outbound-comment-gate.md import. NB: an `option
# global-context-path` line in a sibling crushrc wins this whole key on
# merge - the rule must have exactly one owner.
{ config, ... }:
{
  xdg.configFile."crush/crush.json".text = builtins.toJSON {
    "$schema" = "https://charm.land/crush.json";
    options = {
      global_context_paths = [
        "${config.xdg.configHome}/crush/CRUSH.md"
        "${config.xdg.configHome}/AGENTS.md"
        "${config.home.homeDirectory}/.agents/rules/outbound-comment-gate.md"
      ];
    };
  };
}
