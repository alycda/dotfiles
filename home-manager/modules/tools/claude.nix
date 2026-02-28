# Claude Code - AI coding assistant
# Config files live in tools/claude/ and are symlinked to ~/.claude/
#
# For portable/sandboxed usage without home-manager, see tools/claude/docker/
{ pkgs, ... }:
let
  claudeDir = ../../../tools/claude;
in
{
  # Install claude-code CLI (unfree)
  home.packages = [ pkgs.claude-code ];

  # Symlink settings and skills/agents to ~/.claude/
  home.file = {
    ".claude/settings.json".source = "${claudeDir}/settings.json";

    # Skills
    ".claude/skills/learn.md".source = "${claudeDir}/skills/learn.md";
    ".claude/skills/write-recco.md".source = "${claudeDir}/skills/write-recco.md";
    ".claude/skills/oss-deep-dive.md".source = "${claudeDir}/skills/oss-deep-dive.md";
    ".claude/skills/commit-craft.md".source = "${claudeDir}/skills/commit-craft.md";

    # Agents
    ".claude/agents/code-mentor.md".source = "${claudeDir}/agents/code-mentor.md";
  };
}
