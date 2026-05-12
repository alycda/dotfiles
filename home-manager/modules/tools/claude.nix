# Claude Code - AI coding assistant

{ config, pkgs, ... }:
let
  claudeDir = ../../../tools/claude;
  homeDir = config.home.homeDirectory;
  agentsSkills = "${homeDir}/dotfiles/tools/agents/skills";
  oosSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  # Install claude-code CLI (unfree)
  home.packages = [ pkgs.claude-code ];

  home.file = {
    # Settings — /nix/store symlink. Read-only at runtime by design.
    ".claude/settings.json".source = "${claudeDir}/settings.json";

    # Researcher skill — out-of-store symlink for live editing.
    # Canonical source under tools/agents/skills/researcher/, shared with hermes.
    ".claude/skills/researcher".source = oosSymlink "${agentsSkills}/researcher";

    # Sprint workflow skills — shared with hermes (software-development category there).
    # User-level mount so they're available regardless of cwd.
    ".claude/skills/sprint-planner".source = oosSymlink "${agentsSkills}/sprint-planner";
    ".claude/skills/sprint-execute".source = oosSymlink "${agentsSkills}/sprint-execute";
    ".claude/skills/sprint-retrospective".source = oosSymlink "${agentsSkills}/sprint-retrospective";
  };
}
