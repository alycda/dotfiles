# Selected agent skills from skills.sh, pinned via sudosubin/nix-skills.
#
# nix-skills ships an overlay exposing every indexed skill (480k+ across
# ~13k repos) as pkgs.skills.<owner>.<repo>.<skill>. Convenient, but forcing
# any single attribute parses all ~48MB of shard JSON and materializes the
# full attrset: measured at ~65s wall / 3.6GB peak RSS per evaluation
# (2026-08-04, x86_64-linux, nix-skills 55a6bcc). agent-skills.nix is
# imported by every profile, so that cost would be paid on every
# home-manager/darwin-rebuild switch and ~6x in CI's
# `nix flake check --all-systems`.
#
# So instead of applying nix-skills' overlay, this overlay reads only the
# per-first-letter data shard for each repo we install from and calls
# nix-skills' buildSkill directly. Same pins, same derivations (verified
# byte-identical drvPaths against the upstream overlay), still auto-updated
# by `nix flake update nix-skills` - at ~1s eval cost instead of ~65s.
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
