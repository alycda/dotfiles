# Cross-tool agent skills (issue #40 shape: canonical declared content in the
# repo, each runtime mounts it natively). Skill sources live under
# tools/agents/skills/; out-of-store symlinks so skill edits land in every
# runtime without a rebuild.
#
# Imported by the desktop profiles (home.nix / work.nix), NOT common.nix: the
# oosSymlink targets assume the repo checkout at ~/dotfiles, which doesn't
# hold in the dev devcontainer (workspace mount path) — links would dangle
# silently there.
{ config, ... }:
let
  homeDir = config.home.homeDirectory;
  agentsSkills = "${homeDir}/dotfiles/tools/agents/skills";
  oosSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.file = {
    # html-deck — self-contained single-file HTML slide decks. Tool-agnostic,
    # so one canonical source serves both runtimes. Hermes wants skills nested
    # as ~/.hermes/skills/<category>/<skill>/; `creative` matches its
    # built-in sketch/, p5js/ neighbors.
    ".claude/skills/html-deck".source = oosSymlink "${agentsSkills}/html-deck";
    ".hermes/skills/creative/html-deck".source =
      oosSymlink "${agentsSkills}/html-deck";

    # s3-now — private-S3 + pre-signed-URL file sharing from the personal AWS
    # scratchpad. AWS CLI + shell only, so tool-agnostic like html-deck.
    ".claude/skills/s3-now".source = oosSymlink "${agentsSkills}/s3-now";
    ".hermes/skills/productivity/s3-now".source =
      oosSymlink "${agentsSkills}/s3-now";
  };
}
