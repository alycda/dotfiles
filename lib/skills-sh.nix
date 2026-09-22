# Selected agent skills from skills.sh, pinned via sudosubin/nix-skills.
#
# nix-skills ships an overlay exposing every indexed skill (480k+ across
# ~13k repos) as pkgs.skills.<owner>.<repo>.<skill>. Convenient, but forcing
# any single attribute parses all ~48MB of shard JSON and materializes the
# full attrset. agent-skills.nix is imported by every profile, so that cost
# would be paid on every home-manager/darwin-rebuild switch and ~6x in CI's
# `nix flake check --all-systems`.
#
# So instead of applying nix-skills' overlay, this overlay reads only the
# per-first-letter data shard for each repo we install from and calls
# nix-skills' buildSkill directly. Same pins, same derivations, still
# auto-updated by `nix flake update nix-skills` - at a fraction of the eval
# cost.
#
# Both halves of that claim are measurable, so measure them rather than
# trusting the numbers below: they are a snapshot of one machine and one
# upstream rev, and upstream has already got faster once.
#
#   nix eval --impure --raw --no-eval-cache -f <expr>   # forcing one skill
#
#   this overlay   0.9s / 0.35GB    upstream overlay  18.8s / 2.2GB
#     (2026-09-21, aarch64-darwin, nix-skills 3f79ccc)
#   this overlay   ~1s              upstream overlay  ~65s / 3.6GB
#     (2026-08-04, x86_64-linux, nix-skills 55a6bcc)
#
# The absolute cost fell by 3.5x between those two rows; the ratio did not,
# which is what actually justifies this file - roughly 20x the wall time and
# 6x the peak RSS, on every switch.
#
# The byte-identical-drvPath claim is checkable the same way: build both
# package sets over one nixpkgs and diff the drvPaths. Verified 2026-09-21
# for all three skills below, including the root-path one, whose name is
# load-bearing (see asd-ste100-skill).
#
# Tradeoff: data/by-name/<initial>/skills.json and nix/build-skill are
# nix-skills internals, not its public API; an upstream refactor may require
# adjusting this file. The `lib.elem path entry.skills` check below turns a
# silently-renamed skill path into a loud eval error.
nix-skills: final: _: {
  skills-sh =
    let
      inherit (final) lib;

      buildSkill = final.callPackage "${nix-skills}/nix/build-skill" { };

      mkSkill =
        { owner, repo, path, name }:
        let
          shard = builtins.substring 0 1 owner;
          entries = builtins.fromJSON (
            builtins.readFile "${nix-skills}/data/by-name/${shard}/skills.json"
          );
          entry = lib.findFirst (e: e.source == "github:${owner}/${repo}") (throw
            "skills-sh: github:${owner}/${repo} not found in nix-skills data"
          ) entries;
          checked =
            if lib.elem path entry.skills then
              entry
            else
              throw "skills-sh: skill path ${path} not listed for github:${owner}/${repo}";
        in
        buildSkill {
          # Upstream pname convention: <owner>.<repo>.<skill-name>
          pname = "${owner}.${repo}.${name}";
          inherit owner repo path;
          inherit (checked) rev hash;
        };
    in
    {
      # https://www.skills.sh/heredotnow/skill/here-now
      # Publish files/folders to live URLs ({slug}.here.now) from an agent.
      here-now = mkSkill {
        owner = "heredotnow";
        repo = "skill";
        path = "here-now";
        name = "here-now";
      };

      # https://www.skills.sh/danyuchn/asd-ste100-skill
      # ASD-STE100 (Simplified Technical English) rule engine: the 53-rule
      # summary, the strict / STE-flavored mode split, worked examples, and (on
      # upstream master) a stdlib-only linter, scripts/ste-lint.py. The repo's
      # own `ste100` skill (tools/agents/skills/ste100) carries no rule text and
      # delegates to this one; it maps the rules onto this repo's surfaces.
      #
      # Pin lag, seen once already, and misdiagnosed once too. The first pin
      # (index of 2026-08-30, upstream e4d64d1) had no scripts/ste-lint.py.
      # That SKILL.md was self-consistent: it did not mention a linter. The
      # file that named the absent script was this repo's own ste100 skill,
      # written against upstream master instead of the pinned rev. The index
      # re-resolved on 2026-09-15 and the lock caught up on 2026-09-18. The
      # rule that survives: write a layering skill against the rev the lock
      # installs, and check every path it names in the shard or in
      # ~/.agents/skills/<name>/ before committing it. `ste100` keeps its
      # fallback (lint from the rule table when the script is absent) because
      # the lock can trail any upstream commit by days to weeks.
      # Path "." means the repo root is the skill, and that fixes the name:
      # nix-skills' getSkillName returns null for "." and falls back to the
      # repo, so upstream's pname is danyuchn.asd-ste100-skill.asd-ste100-skill
      # and its yq pass writes `name: asd-ste100-skill` into SKILL.md. Passing
      # the same name here is what keeps the byte-identical-drvPath claim in
      # this file's header true for a root-path skill; a prettier `asd-ste100`
      # would be a different derivation with different frontmatter. The
      # price is the directory name ~/.agents/skills/asd-ste100-skill.
      asd-ste100-skill = mkSkill {
        owner = "danyuchn";
        repo = "asd-ste100-skill";
        path = ".";
        name = "asd-ste100-skill";
      };

      # https://www.skills.sh/supabase/agent-skills/supabase-postgres-best-practices
      # Postgres performance/schema/RLS guidance across 8 priority categories.
      supabase-postgres-best-practices = mkSkill {
        owner = "supabase";
        repo = "agent-skills";
        path = "skills/supabase-postgres-best-practices";
        name = "supabase-postgres-best-practices";
      };
    };
}
