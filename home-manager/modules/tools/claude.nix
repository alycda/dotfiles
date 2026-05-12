# Claude Code - AI coding assistant

{ config, pkgs, ... }:
let
  claudeDir = ../../../tools/claude;
in
{
  # Install claude-code CLI (unfree)
  home.packages = [ pkgs.claude-code ];

  home.file = {
    # Settings — /nix/store symlink. Read-only at runtime by design.
    ".claude/settings.json".source = "${claudeDir}/settings.json";
  };
}
