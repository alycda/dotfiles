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
  hermesDir = "${homeDir}/dotfiles/tools/hermes";
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

    # Curated hermes profile — gpt-5.6-sol via openai-codex OAuth (ChatGPT
    # subscription, not API billing). Opts out of bundled-skill seeding via
    # the .no-bundled-skills marker so its skill surface is exactly what is
    # mounted here, one skill at a time as each gets ported. Auth is runtime
    # state (hermes owns auth.json): `hermes profile use curated` then
    # `hermes login --provider openai-codex` once after first activation.
    ".hermes/profiles/curated/config.yaml".source =
      oosSymlink "${hermesDir}/profiles/curated/config.yaml";
    ".hermes/profiles/curated/SOUL.md".source =
      oosSymlink "${hermesDir}/profiles/curated/SOUL.md";
    ".hermes/profiles/curated/.no-bundled-skills".text = "";
    ".hermes/profiles/curated/skills/creative/html-deck".source =
      oosSymlink "${agentsSkills}/html-deck";
    ".hermes/profiles/curated/skills/productivity/s3-now".source =
      oosSymlink "${agentsSkills}/s3-now";
  };
}
