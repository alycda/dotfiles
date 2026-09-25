# Crush (charmbracelet) declarative config slice.
#
# This module owns both of crush's global config files: crush.json, built
# below, and crushrc, the shell-form sibling linked from tools/crush/crushrc.
# crush merges the two from the same directory (verified in crush 0.88.1
# load.go; crushrc wins on key conflicts and crush warns), so they compose
# instead of fighting - as long as the crushrc never sets the keys owned here
# (global_context_paths, hooks, permissions.allowed_tools).
#
# crushrc used to be hand-managed, because provider api-key lines were
# expected to hold secrets. It holds none: the one provider it touches,
# Venice, is built into crush's catwalk catalog, and the crushrc only fills in
# the key from envchain at startup. It is a script crush executes, not data,
# so a failing command in it (exit 127 for an unknown one) aborts crush's
# whole config load - which is how the hand-managed copy broke, and why the
# tracked one guards every binary it calls: this module reaches the Linux
# devcontainer via common.nix, and envchain is macOS-only.
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
#
# Prompt fatigue is handled in two places, because crush's native allowlist
# (permissions.allowed_tools) matches "tool" or "tool:action" only:
#   - MCP tools: listed in allowed_tools below, by crush's mcp_<server>_<tool>
#     name. The server name is whatever the crushrc calls it ("linear").
#   - bash commands: every call is "bash:execute", so the list can't narrow
#     to one command. A second PreToolUse hook (tools/crush/allow-commands.sh)
#     returns {"decision":"allow"} for word-prefix matches in
#     tools/crush/allowed-commands. Deny beats allow across hooks, so the
#     outbound gate still wins.
# If the crushrc ever sets permissions.allowed_tools it replaces this list
# (crushrc wins on key conflicts) - keep that key here.
{ config, ... }:
let
  hooksDir = "${config.xdg.configHome}/crush/hooks";
in
{
  xdg.configFile = {
    "crush/hooks/outbound-gate.sh" = {
      source = ../../../tools/crush/outbound-gate.sh;
      executable = true;
    };

    "crush/hooks/allow-commands.sh" = {
      source = ../../../tools/crush/allow-commands.sh;
      executable = true;
    };
    # Read by allow-commands.sh from its own directory.
    "crush/hooks/allowed-commands".source = ../../../tools/crush/allowed-commands;

    "crush/crushrc".source = ../../../tools/crush/crushrc;

    "crush/crush.json".text = builtins.toJSON {
      "$schema" = "https://charm.land/crush.json";
      options = {
        # Verbatim reads, no @-import expansion, missing paths skipped
        # (crush 0.88.1 processContextPath) - so the canonical layers are
        # listed directly instead of the ~/.agents/AGENTS.md entrypoint,
        # in precedence order. CRUSH.md stays as a hand-scribble hatch.
        global_context_paths = [
          "${config.xdg.configHome}/crush/CRUSH.md"
          "${config.home.homeDirectory}/.agents/company-values.md"
          "${config.home.homeDirectory}/.agents/persona-core.md"
          "${config.home.homeDirectory}/.agents/instructions.private.md"
          "${config.home.homeDirectory}/.agents/rules/outbound-comment-gate.md"
        ];
      };
      permissions.allowed_tools = [
        "mcp_linear_get_issue"
        "mcp_linear_list_comments"
        "mcp_linear_list_issues"
      ];
      hooks.PreToolUse = [
        {
          name = "outbound-gate";
          command = "${hooksDir}/outbound-gate.sh";
          timeout = 15;
        }
        {
          name = "allow-commands";
          matcher = "^bash$";
          command = "${hooksDir}/allow-commands.sh";
          timeout = 5;
        }
      ];
    };
  };
}
