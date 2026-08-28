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
#
# External skills (from skills.sh, pinned via the nix-skills flake input and
# selected in lib/skills-sh.nix) always deploy from the store - liveCheckout
# doesn't apply to them since their source isn't in this repo.
{ config, lib, pkgs, ... }:
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
    # TEMPORARY (revert/squash before push): every ~/.claude/skills entry is
    # commented out so the next switch REMOVES the nix-managed symlinks there.
    # Purpose: evaluate cross-tool skill discovery (crush/codex scan
    # ~/.agents/skills and ~/.claude/skills per the Agent Skills standard) and
    # decide the issue-#40 inversion - canonical deploy to ~/.agents/skills
    # with ~/.claude/skills as symlinks - with a clean slate.
    home.file = { };
    # home.file = {
    #   # html-deck — self-contained single-file HTML slide decks. Tool-agnostic,
    #   # but only wired for Claude here; other runtimes follow later.
    #   ".claude/skills/html-deck".source = skillSource "html-deck";

    #   # jujutsu — operate in jj repos without git muscle memory. Progressive
    #   # disclosure: SKILL.md carries the mental model and agent rules, with
    #   # references/ loaded on demand (command mapping, gitignore recovery,
    #   # version deltas). Pinned to jj v0.43.
    #   ".claude/skills/jujutsu".source = skillSource "jujutsu";

    #   # jj-extract-gitignores — retroactively roll .gitignore additions back
    #   # into named in-between commits after the ancestor that needed them.
    #   # Narrow companion to the jujutsu skill above.
    #   ".claude/skills/jj-extract-gitignores".source = skillSource "jj-extract-gitignores";

    #   # commit-craft — Chris Beams' seven rules for commit messages, plus the
    #   # jj-side workflow (`jj describe` → bookmark → push). Completes the pair
    #   # with the jujutsu skill above: that one covers moving around a jj repo,
    #   # this one covers what to write when a change becomes a commit.
    #   ".claude/skills/commit-craft".source = skillSource "commit-craft";

    #   # brag-doc — extract promo-packet-ready impact entries from raw work
    #   # notes (five fixed categories + aggregate rollups). Pairs with
    #   # failure-doc below: its Learning Log holds summary lines pointing at
    #   # full failure-doc entries.
    #   ".claude/skills/brag-doc".source = skillSource "brag-doc";

    #   # failure-doc — capture failures as deliberate-learning records (the
    #   # failure was load-bearing). Cross-references brag-doc for entries that
    #   # are also brag-eligible, so the two ship together here. Planned to also
    #   # be packaged standalone in Alycda/ffi-workshop later; this copy stays
    #   # canonical for the home environment.
    #   ".claude/skills/failure-doc".source = skillSource "failure-doc";

    #   # External skills from skills.sh (see lib/skills-sh.nix for pinning).
    #   # Note: compound-engineering is deliberately NOT installed this way -
    #   # it's already a Claude Code plugin via the catalog (#65), and its 38
    #   # ce-* skills ship inside the plugin; installing them here too would
    #   # duplicate every one of them in the skill picker.
    #   ".claude/skills/here-now".source = pkgs.skills-sh.here-now;
    #   ".claude/skills/supabase-postgres-best-practices".source =
    #     pkgs.skills-sh.supabase-postgres-best-practices;
    # };
  };
}
