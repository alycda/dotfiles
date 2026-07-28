# Cross-tool agent skills (issue #40 shape: canonical declared content in the
# repo, each runtime mounts it natively). Skill sources live under
# tools/agents/skills/; out-of-store symlinks so skill edits land in the
# runtime without a rebuild.
#
# Imported by the desktop profiles (home.nix / work.nix), NOT common.nix: the
# oosSymlink targets assume the repo checkout at ~/dotfiles, which doesn't
# hold in the dev devcontainer (workspace mount path) — links would dangle
# silently there.
#
# Claude only for now. Hermes mounts (nested by category under ~/.hermes/) land
# in a follow-up once more skills are ported.
{ config, ... }:
let
  homeDir = config.home.homeDirectory;
  agentsSkills = "${homeDir}/dotfiles/tools/agents/skills";
  oosSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.file = {
    # html-deck — self-contained single-file HTML slide decks. Tool-agnostic,
    # but only wired for Claude here; other runtimes follow later.
    ".claude/skills/html-deck".source = oosSymlink "${agentsSkills}/html-deck";
  };
}
