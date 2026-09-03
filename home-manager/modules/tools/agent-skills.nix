# Cross-tool agent skills (issue #40 shape: canonical declared content in the
# repo, each runtime mounts it natively). Skill sources live under
# tools/agents/skills/.
#
# Canonical install location is ~/.agents/skills/<name> - the Agent Skills
# standard directory that crush and codex scan directly. Claude Code reads
# only ~/.claude/skills, so each skill also gets a ~/.claude/skills/<name>
# symlink pointing at the canonical ~/.agents/skills copy (same pattern cmux
# uses for its hand-installed skills). One deploy, every surface.
#
# The crush half of that claim is worth pinning down, because its own docs
# still contradict it: charmbracelet-crush.mintlify.app/configuration/skills
# lists only ~/.config/crush/skills and ~/.config/agents/skills as the global
# roots, and issue #2072 asking for ~/.agents/skills reads as open. The source
# settles it - config.GlobalSkillsDirs() in internal/config/load.go returns
# ~/.config/crush/skills, ~/.config/agents/skills, ~/.agents/skills and
# ~/.claude/skills, and the ~/.agents entry is present in v0.91.2, which is
# the crush lib/charm-nur.nix pins at the locked rev. So nothing here needs a
# skills_paths entry in tools/crush.nix; if a future bump ever drops that
# path, adding one is the fix (load.go appends the defaults to a configured
# skills_paths rather than replacing them).
#
# Two deployment modes for repo skills, selected per profile via
# agentSkills.liveCheckout:
#  - null (default): skills deploy from the store snapshot the flake was built
#    from. No path assumptions, so the module is safe in common.nix and the
#    dev devcontainer.
#  - a path string: out-of-store symlinks into that live checkout, so skill
#    edits land in the runtime without a rebuild - the desktop dev loop.
#
# External skills (from skills.sh, pinned via the nix-skills flake input and
# selected in lib/skills-sh.nix) always deploy from the store - liveCheckout
# doesn't apply to them since their source isn't in this repo.
#
# Repo skills:
#   brag-doc              - promo-packet impact entries from raw work notes
#   cf-now                - private file sharing from Cloudflare R2 (pre-signed URLs)
#   commit-craft          - commit-message craft + jj describe/push workflow
#   failure-doc           - failures as deliberate-learning records
#   html-deck             - self-contained single-file HTML slide decks
#   jj-extract-gitignores - roll .gitignore additions back into ancestors
#   jujutsu               - operate in jj repos without git muscle memory
#
# One of them is vendored rather than authored:
#   hackmd-cli - upstream's own skill, extracted from the hackmd-cli.skill zip
#     in hackmdio/hackmd-cli (a plain zip of a SKILL.md; the npm tarball does
#     NOT carry it, so it cannot come from the same fetch as the binary). It
#     documents the CLI that ../tools/hackmd.nix installs, so the two are
#     re-synced together - bump instructions live in that module's header.
#
#     Vendored, not verbatim: two blocks marked `LOCAL EDIT (dotfiles)` correct
#     instructions that are actively wrong here. Upstream's Install section
#     says `npm install -g`, which against a read-only store prefix either
#     fails or shadows the pinned build; and the Setup section says nothing
#     about the no-token hang the wrapper now turns into an error. A skill is
#     read by agents as instructions, so leaving a known-wrong command in it to
#     preserve byte-fidelity with upstream trades the thing that matters for
#     one that does not. Re-apply both blocks when re-vendoring; treat any
#     other edit as one the next re-vendor will silently drop.
#
#     It sits in repoSkills because the deployment is identical, but note what
#     liveCheckout then means for it: with a live checkout set it becomes an
#     out-of-store symlink like the others, which for vendored content buys
#     nothing and only makes a stray edit look like it took effect.
#
# (compound-engineering is deliberately NOT here - it ships as a Claude Code
# plugin via the catalog (#65), and installing its 38 ce-* skills again here
# would duplicate every one of them in the picker.)
{ config, lib, pkgs, ... }:
let
  cfg = config.agentSkills;
  skillSource =
    name:
    if cfg.liveCheckout != null then
      config.lib.file.mkOutOfStoreSymlink "${cfg.liveCheckout}/tools/agents/skills/${name}"
    else
      ../../../tools/agents/skills + "/${name}";

  repoSkills = [
    "brag-doc"
    "cf-now"
    "commit-craft"
    "failure-doc"
    "hackmd-cli"
    "html-deck"
    "jj-extract-gitignores"
    "jujutsu"
  ];

  externalSkills = {
    here-now = pkgs.skills-sh.here-now;
    supabase-postgres-best-practices = pkgs.skills-sh.supabase-postgres-best-practices;
  };

  # canonical copies: ~/.agents/skills/<name>
  canonical =
    lib.listToAttrs (
      map (n: lib.nameValuePair ".agents/skills/${n}" { source = skillSource n; }) repoSkills
    )
    // lib.mapAttrs' (n: src: lib.nameValuePair ".agents/skills/${n}" { source = src; })
      externalSkills;

  # claude mount: ~/.claude/skills/<name> -> ~/.agents/skills/<name>
  claudeMount = lib.listToAttrs (
    map (
      n:
      lib.nameValuePair ".claude/skills/${n}" {
        source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills/${n}";
      }
    ) (repoSkills ++ lib.attrNames externalSkills)
  );
in
{
  options.agentSkills.liveCheckout = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "/Users/alyssa/dotfiles";
    description = ''
      Absolute path to a live dotfiles checkout. When set, repo skills are
      out-of-store symlinks into it and edits land without a rebuild.
      When null, skills deploy from the store — portable to machines
      without a checkout at any particular path.
    '';
  };

  config = {
    home.file = canonical // claudeMount;
  };
}
