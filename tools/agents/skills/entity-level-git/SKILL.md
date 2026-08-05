---
name: entity-level-git
description: >
  Entity-level git tooling from Ataraxy Labs: sem (entity diffs, blame, impact
  analysis, hotspots), weave (semantic merge driver that dissolves false
  conflicts), and inspect (structural-risk review triage for diffs and PRs).
  Use whenever the question about a change is semantic rather than textual —
  reviewing or summarizing a diff or PR, "what breaks if I change X", who last
  touched a function, which parts of a large change are risky — and whenever
  merge conflicts appear, especially between parallel agents editing the same
  file. Also trigger on any mention of sem, weave, inspect, entity-level or
  semantic diff/merge, impact analysis, or false conflicts. Prefer these over
  raw `git diff` and whole-file reading when installed; when they're absent
  (common in sandboxes), fall back to the standard git equivalent and say so.
allowed-tools: Bash(sem *), Bash(weave *), Bash(weave-cli *), Bash(inspect *), Bash(git status), Bash(git log *), Bash(git diff *)
---

# Entity-Level Git (sem, weave, inspect)

Three sibling tools from [Ataraxy Labs](https://github.com/Ataraxy-Labs) that
share one mental model: parse code with tree-sitter into **entities**
(functions, classes, methods) and operate on those instead of lines. ~28
languages each. The payoff for an agent is precision per token: "function X
changed, and these callers depend on it" instead of reading whole files to
reconstruct that yourself.

| Tool | Replaces | One-liner |
|---|---|---|
| `sem` | reading diffs/files | entity diffs, blame, impact analysis, per-entity history |
| `weave` | line-based `git merge` | merge driver that auto-resolves false conflicts (~95% reduction) |
| `inspect` | reading a whole PR | triages changed entities by structural risk; optional LLM review |

## Availability and fallback

- **Not in nixpkgs** (as of 2026-08), so `nix run nixpkgs#...` cannot summon
  them. On the darwin machines they come from Homebrew (`sem-cli` from core;
  `weave` and `inspect` from `ataraxy-labs/tap` — see
  `darwin/modules/homebrew.nix`). Elsewhere: `cargo install --git` per each
  repo's README.
- **Sandboxes usually won't have them.** Per the preferred-tooling fallback
  rule: don't hand-install in a throwaway environment — fall back to `git
  diff` / normal merge / reading the diff, and say which path you took.
- Check with `command -v sem weave inspect` before building a plan around them.

## sem — entity diffs, blame, impact

Reach for `sem` when you'd otherwise read a diff or grep for callers:

```bash
sem diff                       # entity-level working-tree diff
sem diff --staged              # staged only
sem diff --format json         # machine-readable (also: markdown, plain)
sem impact <entity>            # dependency graph: what breaks if this changes
sem impact <entity> --tests    # ...including which tests cover it
sem blame <file>               # who last modified each entity in the file
sem log <entity>               # history of one function/class
sem log --limit 200            # no entity: repo hotspots
sem entities <path> --json     # list parsed entities
sem context <entity>           # token-budgeted LLM context for an entity
```

Notes:

- **Before large refactors**, run `sem impact` on the entities you're about to
  change — it's the cheap version of "read every caller".
- `sem setup` rewires `git diff` output globally and `sem unsetup` reverts it.
  That mutates the user's git config: **propose it, never run it unprompted.**
- `sem mcp` serves these as MCP tools (`sem_impact`, `sem_context`, `sem_diff`,
  `sem_entities`, `sem_blame`, `sem_log`). If an `sem` MCP server is already
  registered in the session, prefer its tools over shelling out.
- **In the dotfiles repo, CI already posts a sticky sem entity-diff comment on
  every PR** (`.github/workflows/entity-diff.yml`, `Ataraxy-Labs/sem/action`).
  Don't post duplicate entity-diff comments there — read the existing one.

## weave — semantic merge driver

Line-based merge invents conflicts when two independent changes touch nearby
lines — the standard failure mode of parallel agents editing one file. weave
merges at entity granularity instead; unsupported file types silently fall
back to normal line merging.

```bash
weave setup             # enable: writes .gitattributes + merge driver config
weave setup --local     # .git/info/attributes instead (nothing committed)
weave setup --global    # all repos via ~/.gitconfig
weave unsetup           # revert to standard git merge
weave-cli preview <branch>   # dry-run a merge without committing anything
```

- `weave setup` **mutates repo config and possibly tracked files**
  (`.gitattributes`): propose it and let the user choose the variant; don't
  run it unprompted. `--local` is the least invasive.
- When weave is active, a merge that "just works" on a file both sides edited
  is weave doing its job — don't treat the absence of conflicts as suspicious.
- **jj integration** (relevant here — jj is the house VCS): weave registers as
  a jj merge tool. In `jj config edit --user`:

  ```toml
  [merge-tools.weave]
  program = "weave-driver"
  merge-args = ["$base", "$left", "$right", "-o", "$output", "-l", "$marker_length", "-p", "$path"]
  merge-conflict-exit-codes = [1]
  merge-tool-edits-conflict-markers = true
  conflict-marker-style = "git"
  ```

  Then `jj resolve --tool weave` on conflicted files. Note the jujutsu skill
  says to avoid `jj resolve` because it opens a TUI — `--tool weave` is the
  exception: it runs the driver non-interactively. Entities weave can't
  auto-merge keep git-style conflict markers for manual resolution.

## inspect — review triage by structural risk

Reach for `inspect` when facing a large diff or PR and the question is "where
should review attention go":

```bash
inspect diff HEAD~1              # triage last commit (also ranges: main..feature)
inspect diff HEAD~1 --context    # include dependency details
inspect diff HEAD~1 --min-risk high
inspect diff HEAD~1 --format json     # or markdown
inspect pr 42                    # triage a GitHub PR (shells out to gh)
inspect file src/main.rs         # uncommitted changes in one file
inspect review HEAD~1            # triage + LLM review of highest-risk entities
inspect review HEAD~1 --max-entities 20
```

- **Triage needs no API key** — it classifies entities (text-only / syntax /
  functional) and scores risk from the dependency graph locally. Only
  `inspect review` calls an LLM: Anthropic by default via `ANTHROPIC_API_KEY`,
  or `--provider openai` / `--provider ollama` / `--api-base <url>`. Keys come
  from the environment (agenix-managed), never from tracked files.
- Use triage output to order your own review: read `functional`/high-risk
  entities first, skim or skip text-only ones.
- inspect also ships an MCP server (`inspect-mcp`: `inspect_triage`,
  `inspect_entity`, `inspect_group`, `inspect_file`, `inspect_stats`,
  `inspect_risk_map`) — prefer it if registered in the session.

## Choosing between them

- Understanding a change you or someone else made → `sem diff`
- About to change something → `sem impact` first
- Merge conflict, or planning parallel agents on one codebase → `weave`
- Big diff/PR, limited attention → `inspect diff` / `inspect pr`
- History questions ("when did this function change / who owns it") →
  `sem log` / `sem blame`
