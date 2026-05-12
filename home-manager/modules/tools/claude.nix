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
  };
}
