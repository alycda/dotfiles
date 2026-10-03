---
name: entity-level-git
description: >
  Entity-level history tooling from Ataraxy Labs: sem (entity diffs, blame,
  impact analysis, per-function history), with notes on its siblings weave
  (semantic merge driver) and inspect (structural-risk review triage). Consult
  this skill FIRST, before reading a whole diff, running blame, or grepping
  for callers, when a task looks like: what changed in this change, in terms
  of functions, sections and keys rather than lines (including to write its
  commit message or to split it by concern); what depends on or breaks if I
  change this function; who last touched this function; formatter churn
  drowning the real diff. Also use whenever sem, weave, or inspect is named.
# Read-only subcommands only. Deliberately NOT `Bash(sem *)`: a wildcard would
# pre-approve sem setup/login/cloud/update/telemetry, which the body says
# never to run unprompted - the permission prompt is the backstop for those.
allowed-tools: Bash(sem diff *), Bash(sem impact *), Bash(sem callers *), Bash(sem refs *), Bash(sem find *), Bash(sem blame *), Bash(sem log *), Bash(sem entities *), Bash(sem graph *), Bash(sem context *), Bash(jj log *), Bash(jj diff *)
---

# Entity-Level History (sem)

[sem](https://github.com/Ataraxy-Labs/sem) parses files with tree-sitter into
**entities** (functions, classes, methods; sections and keys in TOML, YAML,
JSON and Markdown) and diffs, blames and traces those instead of lines. The
payoff is precision per token: "the `tools` section of `mise.toml` changed"
instead of reading the file to reconstruct that yourself.

## Availability

- sem comes from mise in this repo (`mise.toml`). Check with `sem --version`
  where mise is active, or prefix `mise exec --`.
- **Other packages named sem are different programs**: mise's registry has no
  sem (so `mise.toml` names the GitHub repo), and `nixpkgs#sem` is the
  Semaphore CI CLI. Its errors won't say so.
- Don't run `sem update`: mise manages the binary, and a self-update fights
  it.
- weave and inspect are not installed here. If they are named, see the
  siblings section below, and don't install them without asking.

## In this repo: sem on jj

sem reads git, and this is a colocated jj repository, so git sees jj's
changes. Translate as follows:

| You want | Run |
|---|---|
| The working-copy change (`@`) | `sem diff` (git's HEAD is `@-`) |
| Any other change | `sem diff --commit $(jj log --no-graph -r <change> -T commit_id)` |
| A range of changes | `sem diff --from <commit id> --to <commit id>` |

Don't use `sem diff --staged`: jj has no staging area, so it shows nothing
useful.

**For commit messages** (see the Commits section of CLAUDE.md): run `sem diff`
on the change before describing it. The changed entities say what the change
is about, which is what the subject should name, and entities with nothing in
common are the signal to `jj split` by concern.

## sem commands

```bash
sem diff                       # entity-level working-tree diff (git diff syntax works)
sem diff --no-cosmetics        # drop formatting-only changes: the formatter-churn case
sem diff --json                # machine-readable; carries entity IDs for `impact`
sem impact <entity>            # deps, dependents, transitive impact, tests
sem impact <entity> --tests    # only the affected test entities
sem callers <entity>           # direct callers only - cheaper than full impact
sem refs <entity>              # what the entity itself calls
sem find <name>                # locate an entity's definition
sem blame <file>               # who last modified each entity in the file
sem log <entity>               # history of one function/class (-v shows content diffs)
sem log --limit 200            # no entity: repo hotspots + co-change pairs
sem entities <path> --json     # list parsed entities
sem context <entity>           # token-budgeted LLM context for an entity
```

When an entity name is ambiguous, pass `--file <path>`; `--entity-id
'<path>::class::<Name>'` works everywhere, while the `Class::method` form is
rejected by `callers`.

- **Before a refactor**, run `sem impact` on what you're about to change; for
  a rename, `sem callers` is usually the whole answer.
- **The call graph is only as good as the language support.** Before
  trusting a graph answer (`impact`, `callers`, `refs`) in a language you
  haven't seen sem handle, check that it returned real entity kinds rather
  than `chunk`s and that `sem graph` reports a non-zero edge count. In Dart,
  for one, the graph is empty and "no other entities are affected" is a false
  negative.

## What never to run unprompted

- `sem setup` rewires `git diff` output globally (`sem unsetup` reverts it).
  It changes the user's git config: propose it, never run it.
- `sem login`, `sem cloud`, `sem review`, `sem xref` and `sem telemetry on`
  send repo-derived data to Ataraxy's servers. Everything else runs locally,
  and that is the default. That choice is the user's alone: never run them,
  and don't suggest them as a fix.
- `sem mcp` serves these commands as MCP tools. If a sem MCP server is
  already registered in the session, prefer its tools to shelling out.

## The siblings: weave and inspect

Neither is installed here; these notes are for when one is named.

- **weave** is a merge driver that merges at entity granularity, dissolving
  the false conflicts line merges invent when two changes touch nearby lines.
  `weave preview <branch>` is a read-only dry run. `weave setup` changes repo
  or global config: propose it, never run it. It can be registered as a jj
  merge tool, and `jj resolve --tool weave` then runs non-interactively.
- **inspect** triages a diff by structural risk (`inspect diff <range>`), so
  review starts with what matters. Triage is local. `inspect review` sends
  code to an LLM provider and `inspect comment` posts to GitHub: never run
  either unprompted. It does not parse Nix, so a mostly-Nix diff comes back
  as line chunks with meaningless scores.
