# Claude Code - AI coding assistant

{ config, pkgs, ... }:
let
  claudeDir = ../../../tools/claude;
  homeDir = config.home.homeDirectory;
  claudeSkills = "${homeDir}/dotfiles/tools/claude/skills";
  agentsSkills = "${homeDir}/dotfiles/tools/agents/skills";
  oosSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  # Install claude-code CLI (unfree)
  home.packages = [ pkgs.claude-code ];

  home.file = {
    # Settings — /nix/store symlink. Read-only at runtime by design.
    ".claude/settings.json".source = "${claudeDir}/settings.json";

    # Global instructions + slash commands — out-of-store symlinks for live editing.
    ".claude/CLAUDE.md".source = oosSymlink "${homeDir}/dotfiles/tools/claude/CLAUDE.md";
    ".claude/commands".source = oosSymlink "${homeDir}/dotfiles/tools/claude/commands";

    # Claude-Code-native skills (tools/claude/skills). researcher and the sprint
    # trio are the Claude-native forks — the Hermes-flavored originals stay in
    # tools/agents/skills and are deployed to Hermes, not here.
    ".claude/skills/c4-design".source = oosSymlink "${claudeSkills}/c4-design";
    ".claude/skills/communication-bridge".source = oosSymlink "${claudeSkills}/communication-bridge";
    ".claude/skills/html-deck".source = oosSymlink "${claudeSkills}/html-deck";
    ".claude/skills/jj-extract-gitignores".source = oosSymlink "${claudeSkills}/jj-extract-gitignores";
    ".claude/skills/jujutsu".source = oosSymlink "${claudeSkills}/jujutsu";
    ".claude/skills/researcher".source = oosSymlink "${claudeSkills}/researcher";
    ".claude/skills/sprint-planner".source = oosSymlink "${claudeSkills}/sprint-planner";
    ".claude/skills/sprint-execute".source = oosSymlink "${claudeSkills}/sprint-execute";
    ".claude/skills/sprint-retrospective".source = oosSymlink "${claudeSkills}/sprint-retrospective";

    # Cross-tool skills shared via ~/.agents/skills (cmux + here-now).
    ".agents/skills/cmux-artifact".source = oosSymlink "${agentsSkills}/cmux-artifact";
    ".agents/skills/cmux-browser".source = oosSymlink "${agentsSkills}/cmux-browser";
    ".agents/skills/cmux-cli".source = oosSymlink "${agentsSkills}/cmux-cli";
    ".agents/skills/cmux-customize".source = oosSymlink "${agentsSkills}/cmux-customize";
    ".agents/skills/cmux-freestyle".source = oosSymlink "${agentsSkills}/cmux-freestyle";
    ".agents/skills/cmux-groups".source = oosSymlink "${agentsSkills}/cmux-groups";
    ".agents/skills/cmux-ref".source = oosSymlink "${agentsSkills}/cmux-ref";
    ".agents/skills/cmux-settings".source = oosSymlink "${agentsSkills}/cmux-settings";
    ".agents/skills/cmux-workspace".source = oosSymlink "${agentsSkills}/cmux-workspace";
    ".agents/skills/here-now".source = oosSymlink "${agentsSkills}/here-now";
  };
}
