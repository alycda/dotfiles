# Selected agent skills from skills.sh, pinned via sudosubin/agents.nix
# (the `nix-skills` flake input; upstream renamed the repo in 2026-09).
#
# Exposes pkgs.skills-sh.<name> for agent-skills.nix. Three skills, three
# routes, because the index covers only one of them cleanly.
#
# Through upstream's public overlay, not its internals. Until 2026-09 this
# file read nix-skills' per-letter data shards and called nix/build-skill
# directly, because forcing one attribute through the overlay parsed ~48MB of
# JSON (18.8s / 2.2GB on 2026-09-21; ~65s / 3.6GB on 2026-08-04). Upstream
# then rewrote its history, moved to one JSON file per repo and moved
# nix/build-skill, and the scheduled flake update died on
# "path '.../nix/build-skill' does not exist". The restructure also made the
# overlay cheap, so the reason for touching internals was gone:
#
#   nix eval --raw --impure --no-eval-cache -f <expr>   # x86_64-linux
#     upstream overlay, one skill   0.15s / 132MB
#     bare pkgs.hello               0.11s / 112MB
#     (2026-09-29, agents.nix d78c932)
#
# The overlay function is called here rather than added to nixpkgs.overlays,
# so pkgs gains only skills-sh - not agent-skills, and not upstream's
# deprecated pkgs.skills alias, which warns when forced. If a future bump
# makes the overlay expensive again, re-measure before going back to
# internals: those broke once already.
nix-skills: final: prev:
let
  github = (nix-skills.overlays.default final prev).agent-skills.github;
in
{
  skills-sh = {
    # https://www.skills.sh/heredotnow/skill/here-now
    # Publish files/folders to live URLs ({slug}.here.now) from an agent.
    here-now = github.heredotnow.skill.here-now;

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
    # written against upstream master instead of the pinned rev. The rule
    # that survives: write a layering skill against the rev the lock
    # installs, and check every path it names in
    # data/agent-skills/github.com/<owner>/<repo>.json or in
    # ~/.agents/skills/<name>/ before committing it. `ste100` keeps its
    # fallback (lint from the rule table when the script is absent) because
    # the lock can trail any upstream commit by days to weeks.
    #
    # The override is load-bearing. The repo root is the skill (path "."),
    # so upstream names the package after the repo, but the SKILL.md inside
    # says `name: asd-ste100`. It is deployed at
    # ~/.agents/skills/asd-ste100-skill, and Crush skips a skill whose name
    # does not match its directory, with no visible error. Passing `name`
    # makes upstream's builder rewrite the frontmatter to match (yq). The
    # old builder did this unasked; the current one does it only on request.
    asd-ste100-skill = github.danyuchn.asd-ste100-skill.asd-ste100-skill.override {
      name = "asd-ste100-skill";
    };

    # https://www.skills.sh/supabase/agent-skills/supabase-postgres-best-practices
    # Postgres performance/schema/RLS guidance across 8 priority categories.
    #
    # Pinned here by hand, because the index dropped it: agents.nix d78c932
    # lists github:supabase/agent-skills in sources.json but ships no
    # data/agent-skills/github.com/supabase/agent-skills.json, while the
    # upstream repo and skill are live. When that file reappears, switch back
    # to github.supabase.agent-skills.supabase-postgres-best-practices and
    # delete the pin - until then this does not move with
    # `nix flake update nix-skills`; bump rev + hash by hand
    # (`nix flake prefetch github:supabase/agent-skills/<rev>`).
    #
    # A subdirectory of the source is enough, no builder: the skill has no
    # symlinks, and its SKILL.md name already matches the deploy directory.
    supabase-postgres-best-practices =
      let
        src = final.fetchFromGitHub {
          owner = "supabase";
          repo = "agent-skills";
          rev = "544bfc56c89afe2b87b20017a59b2c6e9502a1fb"; # 2026-09-28
          hash = "sha256-14XVs2bpAIh/xdXi+zgSI7tO3e7iWUcOsLJNU75KqwU=";
        };
      in
      "${src}/skills/supabase-postgres-best-practices";
  };
}
