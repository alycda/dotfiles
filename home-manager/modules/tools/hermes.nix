# Hermes Agent - self-improving AI agent framework (Nous Research)
#
# Install method
# --------------
# nix profile add github:NousResearch/hermes-agent
#
# Out-of-store symlinks point ~/.hermes/<path> at
# ~/dotfiles/tools/hermes/<path> so edits to personas and profile
# config land in both places without darwin-rebuild.
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
  hermesDir = "${homeDir}/dotfiles/tools/hermes";
  oosSymlink = config.lib.file.mkOutOfStoreSymlink;

  # Profiles whose config.yaml + SOUL.md are tracked in dotfiles.
  # Adding to this list requires the corresponding directory to exist
  # under tools/hermes/profiles/<name>/.
  trackedProfiles = [
    "distinguished-engineer"
    "engineer"
    "principal-engineer"
    "researcher-claude"
    "researcher-codex"
    "researcher-gemini"
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
  };
}
