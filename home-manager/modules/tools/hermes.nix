# Hermes Agent - self-improving AI agent framework (Nous Research)
#
# Install method
# --------------
# nix profile add github:NousResearch/hermes-agent
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
in
{
  home.file = {
    # Default profile persona.
    ".hermes/SOUL.md".source = oosSymlink "${hermesDir}/SOUL.md";
  };
}
