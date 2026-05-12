# Hermes Agent - self-improving AI agent framework (Nous Research)
#
# Install method
# --------------
# Today: upstream curl installer
#   (see https://hermes-agent.nousresearch.com/docs/getting-started/quickstart)
#
# Planned: `nix profile install` against an upstream Hermes flake, once
# Nous publishes one (or we vendor one here). Reasons to migrate:
#   - Imperative install lives outside the flake — not reproducible across
#     machines, no rollback, no `nix profile list`.
#   - `home.packages = [ pkgs.hermes ]` (the claude.nix pattern) would be
#     even better, but requires hermes in nixpkgs. `nix profile` is the
#     stepping stone: declarative install of an out-of-tree flake without
#     waiting on nixpkgs upstreaming.
#
# This module manages only the tracked config subset under ~/.hermes/
# regardless of which install method delivers the hermes binary.
#
# Same pattern as claude.nix: OUT-OF-STORE symlinks point ~/.hermes/<path>
# at ~/dotfiles/tools/{agents,hermes}/<path> so edits are live in both
# places, without darwin-rebuild on every skill tweak.
#
# Not managed by nix (Hermes owns these at runtime):
#   - state.db / kanban.db / models_dev_cache.json
#   - sessions/, logs/, checkpoints/, state-snapshots/, memories/
#   - audio_cache/, image_cache/, pastes/
#   - .env, auth.json, .hermes_history, .update_check, processes.json
#   - The upstream hermes-agent/ checkout (managed by `hermes update`)
{ config, ... }:
let
  homeDir = config.home.homeDirectory;
  agentsSkills = "${homeDir}/dotfiles/tools/agents/skills";
  hermesDir = "${homeDir}/dotfiles/tools/hermes";
  oosSymlink = config.lib.file.mkOutOfStoreSymlink;

  # Profiles whose config.yaml + SOUL.md are tracked in dotfiles.
  # Adding to this list requires the corresponding directory to exist under
  # tools/hermes/profiles/<name>/.
  trackedProfiles = [
    "distinguished-engineer"
    "engineer"
    "principal-engineer"
    "researcher-claude"
    "researcher-codex"
    "staff-engineer"
    "writer"
  ];

  # Per-profile file mounts (config.yaml + SOUL.md each).
  profileFiles = builtins.foldl'
    (acc: name: acc // {
      ".hermes/profiles/${name}/config.yaml".source =
        oosSymlink "${hermesDir}/profiles/${name}/config.yaml";
      ".hermes/profiles/${name}/SOUL.md".source =
        oosSymlink "${hermesDir}/profiles/${name}/SOUL.md";
    })
    { }
    trackedProfiles;
in
{
  home.file = profileFiles // {
    # Default profile persona.
    ".hermes/SOUL.md".source = oosSymlink "${hermesDir}/SOUL.md";

    # Researcher skill — canonical source under tools/agents/skills/research/
    # (tools/hermes/skills/research/researcher is a stub symlink to this path).
    ".hermes/skills/research/researcher".source =
      oosSymlink "${agentsSkills}/research";

    # Sprint skills — live under ~/.hermes/skills/software-development/.
    ".hermes/skills/software-development/sprint-planner".source =
      oosSymlink "${agentsSkills}/sprint-planner";
    ".hermes/skills/software-development/sprint-execute".source =
      oosSymlink "${agentsSkills}/sprint-execute";
    ".hermes/skills/software-development/sprint-retrospective".source =
      oosSymlink "${agentsSkills}/sprint-retrospective";

    # Orchestration skill — Hermes-specific (decompose.py + kanban patterns).
    ".hermes/skills/orchestration".source =
      oosSymlink "${hermesDir}/skills/orchestration";
  };
}
