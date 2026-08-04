# Cross-tool agent skills (issue #40 shape: canonical declared content in the
# repo, each runtime mounts it natively). Skill sources live under
# tools/agents/skills/.
#
# Two deployment modes, selected per profile via agentSkills.liveCheckout:
#  - null (default): skills deploy from the store snapshot the flake was built
#    from. No path assumptions, so the module is safe in common.nix and the
#    dev devcontainer (which previously couldn't import it: the oosSymlink
#    target assumed a checkout at ~/dotfiles and dangled silently elsewhere).
#  - a path string: out-of-store symlinks into that live checkout, so skill
#    edits land in the runtime without a rebuild — the desktop dev loop.
#
# Claude only for now. Hermes mounts (nested by category under ~/.hermes/)
# land with the s3-now port (#43).
{ config, lib, ... }:
let
  cfg = config.agentSkills;
  skillSource =
    name:
    if cfg.liveCheckout != null then
      config.lib.file.mkOutOfStoreSymlink "${cfg.liveCheckout}/tools/agents/skills/${name}"
    else
      ../../../tools/agents/skills + "/${name}";
in
{
  options.agentSkills.liveCheckout = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "/Users/alyssa/dotfiles";
    description = ''
      Absolute path to a live dotfiles checkout. When set, skills are
      out-of-store symlinks into it and edits land without a rebuild.
      When null, skills deploy from the store — portable to machines
      without a checkout at any particular path.
    '';
  };

  config = {
    home.file = {
      # html-deck — self-contained single-file HTML slide decks. Tool-agnostic,
      # but only wired for Claude here; other runtimes follow later.
      ".claude/skills/html-deck".source = skillSource "html-deck";

      # jujutsu — operate in jj repos without git muscle memory. Progressive
      # disclosure: SKILL.md carries the mental model and agent rules, with
      # references/ loaded on demand (command mapping, gitignore recovery,
      # version deltas). Pinned to jj v0.43.
      ".claude/skills/jujutsu".source = skillSource "jujutsu";

      # jj-extract-gitignores — retroactively roll .gitignore additions back
      # into named in-between commits after the ancestor that needed them.
      # Narrow companion to the jujutsu skill above.
      ".claude/skills/jj-extract-gitignores".source = skillSource "jj-extract-gitignores";
    };
  };
}
