# Claude Code - AI coding assistant
#
# Skill and agent markdown files are mounted into ~/.claude/ as OUT-OF-STORE
# symlinks pointing at ~/dotfiles/tools/claude/. Edits in either path are
# reflected in both, without re-running darwin-rebuild. This is the friction
# fix for agent-mutable config under nix-darwin.
#
# settings.json stays as a /nix/store symlink — read-mostly, version-locked
# with the flake. Edit via the dotfiles repo + rebuild.
#
# For portable/sandboxed usage without home-manager, see tools/claude/docker/
{ config, pkgs, ... }:
let
  claudeDir = ../../../tools/claude;
  oosSymlink = config.lib.file.mkOutOfStoreSymlink;
  liveClaude = "${config.home.homeDirectory}/dotfiles/tools/claude";
in
{
  # Install claude-code CLI (unfree)
  home.packages = [ pkgs.claude-code ];

  home.file = {
    # Settings — /nix/store symlink. Read-only at runtime by design.
    ".claude/settings.json".source = "${claudeDir}/settings.json";

    # Skills — out-of-store symlinks; freely editable in place.
    ".claude/skills/learn.md".source = oosSymlink "${liveClaude}/skills/learn.md";
    ".claude/skills/write-recco.md".source = oosSymlink "${liveClaude}/skills/write-recco.md";
    ".claude/skills/oss-deep-dive.md".source = oosSymlink "${liveClaude}/skills/oss-deep-dive.md";
    ".claude/skills/commit-craft.md".source = oosSymlink "${liveClaude}/skills/commit-craft.md";

    # Agents — out-of-store symlinks.
    ".claude/agents/code-mentor.md".source = oosSymlink "${liveClaude}/agents/code-mentor.md";
  };
}
