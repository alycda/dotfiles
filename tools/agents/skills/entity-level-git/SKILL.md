---
name: entity-level-git
description: >
  Entity-level git tooling from Ataraxy Labs — sem (entity diffs, blame,
  impact analysis, per-function history), weave (semantic merge driver), and
  inspect (structural-risk review triage). Consult this skill FIRST, before
  reaching for git diff/blame/log or grepping for callers, whenever a task
  looks like: what depends on this function/class, what breaks if I change or
  rename it; review, summarize, or triage the code changes in a big diff,
  branch, or PR ("what actually changed", "which parts need human review",
  formatter churn drowning the real diff); who last touched this function /
  when did it last change (especially after a formatting commit wrecked
  line-based git blame); merge conflicts in code files — above all false
  conflicts where parallel agents or branches edited different functions in
  the same file — or any request for structure-aware merging. Also use
  whenever sem, weave, or inspect is named, and to interpret the sem
  entity-diff comment CI posts on PRs. The entity-level answer is cheaper and
  more precise than reading whole files — consult the skill even for tasks you
  could muddle through with plain git and grep.
# Read-only subcommands only. Deliberately NOT `Bash(sem *)` / `Bash(weave *)`:
# a wildcard would pre-approve sem setup/login/cloud/update and weave setup,
# which the body says never to run unprompted - the permission prompt is the
# backstop for those rules, so the allowlist must not remove it. Also excluded:
# `inspect review` (sends code to an LLM API) and `inspect comment` (posts to
# GitHub).
allowed-tools: Bash(sem diff *), Bash(sem impact *), Bash(sem callers *), Bash(sem refs *), Bash(sem find *), Bash(sem blame *), Bash(sem log *), Bash(sem entities *), Bash(sem context *), Bash(weave preview *), Bash(weave summary *), Bash(inspect diff *), Bash(inspect predict *), Bash(inspect pr *), Bash(inspect file *), Bash(git status), Bash(git log *), Bash(git diff *)
---

# Entity-Level Git (sem, weave, inspect)

Three sibling tools from [Ataraxy Labs](https://github.com/Ataraxy-Labs) that
share one mental model: parse code with tree-sitter into **entities**
(functions, classes, methods) and operate on those instead of lines. Language
coverage is broad but uneven — sem ~32, weave ~28, inspect ~19; the mainstream
languages (Rust, TS/JS, Python, Go, Java, C/C++) are covered everywhere, and
files a tool can't parse degrade gracefully (weave falls back to line merge).
The payoff for an agent is precision per token: "function X changed, and these
callers depend on it" instead of reading whole files to reconstruct that
yourself.

| Tool | Replaces | One-liner |
|---|---|---|
| `sem` | reading diffs/files | entity diffs, blame, impact analysis, per-entity history |
| `weave` | line-based `git merge` | merge driver that auto-resolves false conflicts (~95% reduction) |
| `inspect` | reading a whole PR | triages changed entities by structural risk; optional LLM review |

## Availability and fallback

- **Each comes from a different place** (verified 2026-09-16):

  | Tool | nixpkgs | Installed via | Where |
  |---|---|---|---|
  | `weave` | yes — `nixpkgs#weave` | home-manager (`profiles/home.nix`, `work.nix`) | both Macs |
  | `sem` | **no — and the name is taken** | Homebrew core, as `sem-cli` | both Macs |
  | `inspect` | no | `lib/inspect.nix` — upstream's release binary, repointed at nixpkgs' openssl | both Macs |

  None of the three reach the linux devcontainers. inspect is **not** installed
  from Ataraxy's Homebrew tap, and must not be: that formula's pinned checksum
  went stale when upstream moved the release tag, so it cannot install, and a
  brew that cannot install aborts `darwin-rebuild`. `lib/inspect.nix` has the
  full story. If inspect is ever missing, don't reach for the tap.

- **`nixpkgs#sem` is a different program** (the Semaphore CI CLI). `nix run
  nixpkgs#sem` summons the wrong tool and its errors won't say so. Only weave
  can be borrowed with the nix-summon trick: `nix run nixpkgs#weave -- ...`.
- **Sandboxes usually won't have them.** Per the preferred-tooling fallback
  rule: `nix run` weave if nix is present; for sem and inspect don't
  hand-install in a throwaway environment — fall back to `git diff` / reading
  the diff, and say which path you took.
- sem has a `sem update` self-updater. Don't run it: the binary is
  brew-managed, and a self-update fights the package manager.
- Check with `command -v sem weave inspect` before building a plan around them.

## sem — entity diffs, blame, impact

Reach for `sem` when you'd otherwise read a diff or grep for callers:

```bash
sem diff                       # entity-level working-tree diff (git diff syntax works)
sem diff --staged              # staged only
sem diff --no-cosmetics        # drop formatting-only changes: the formatter-churn case
sem diff --json                # machine-readable; carries entity IDs for `impact`
sem impact <entity>            # deps, dependents, transitive impact, tests
sem impact <entity> --tests    # only the affected test entities
sem impact <entity> --depth 0  # unlimited transitive depth (default is 2)
sem callers <entity>           # direct callers only — cheaper than full impact
sem refs <entity>              # what the entity itself calls
sem find <name>                # locate an entity's definition
sem blame <file>               # who last modified each entity in the file
sem log <entity>               # history of one function/class (-v shows content diffs)
sem log --limit 200            # no entity: repo hotspots + co-change pairs (default scans 50)
sem entities <path> --json     # list parsed entities
sem context <entity>           # token-budgeted LLM context for an entity
```

Commands checked against `sem 0.25.0`. When an entity name is ambiguous, pass
`--file <path>` to disambiguate.

Notes:

- **Before large refactors**, run `sem impact` on the entities you're about to
  change — it's the cheap version of "read every caller". For a rename,
  `sem callers` is usually the whole answer.
- `sem setup` rewires `git diff` output globally and `sem unsetup` reverts it.
  That mutates the user's git config: **propose it, never run it unprompted.**
- **Everything above runs locally, and that is the default** — cloud is "off
  until you enable it" and telemetry is "local by default — nothing uploaded"
  (sem's own help text). `sem login`, `sem cloud`, `sem review`, `sem xref`
  and `sem telemetry on` change that by sending repo-derived data to Ataraxy's
  servers. On a machine holding work code that is the user's call alone:
  never run them, and don't suggest them as a performance fix.
- `sem mcp` serves these as MCP tools (`sem_impact`, `sem_context`, `sem_diff`,
  `sem_entities`, `sem_blame`, `sem_log`). If a `sem` MCP server is already
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
weave preview <branch>          # dry-run merging <branch> into HEAD; read-only
weave preview <branch> --file f # ...for one file
weave summary <file>            # structured summary of weave conflict markers
weave setup                     # enable: writes .gitattributes + merge driver config
weave setup --local             # .git/info/attributes instead (nothing committed)
weave unsetup                   # revert to standard git merge
```

Commands checked against `weave 0.3.6`, which ships three binaries: `weave`
(the CLI above), `weave-driver` (what git/jj invoke), and `weave-mcp`. Older
READMEs call the CLI `weave-cli` and show a `setup --global`; neither exists
in this version, so don't propose them.

- **Start with `weave preview`.** It changes nothing, so it's safe to run
  unprompted, and it answers "would weave have dissolved these conflicts?"
  before anyone commits to configuring a merge driver.
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
should review attention go".

```bash
inspect diff HEAD~1                 # triage a commit or range (main..feature, abc123)
inspect diff HEAD~1 --min-risk high # critical | high | medium | low
inspect diff HEAD~1 --context       # add dependency context
inspect diff HEAD~1 --dependents    # ...plus full source of callers/consumers
inspect diff HEAD~1 --format json   # terminal (default) | json | markdown
inspect predict HEAD~1              # UNCHANGED entities at risk of breaking
inspect file src/main.rs            # uncommitted changes in one file
inspect pr 42                       # a PR, diffed from local refs
inspect pr 42 --remote owner/repo   # ...via the GitHub API, no checkout needed
```

Commands checked against `inspect 0.1.1` (there is no `--version`; `-C <path>`
points any subcommand at another repo). `inspect pr` in local mode runs a
read-only `gh pr view` to learn the branch names; `--remote` authenticates
with `GITHUB_TOKEN`, falling back to `gh`'s login.

- **Triage is local and needs no API key** — verified by running it with every
  key unset. The JSON carries, per entity, `risk_level`
  (Critical/High/Medium/Low), a `risk_score`, `classification` (`Text`,
  `Functional`, or combinations such as `TextFunctional`), `blast_radius`,
  and dependent/dependency names. Order your own review by it: functional and
  high-risk first, `Text`-only last.
- **Check `entity_type` before trusting the scores.** inspect parses ~19
  languages (Rust, TS/JS, Python, Go, Java, C/C++, Bash, ...) — **not Nix**.
  A file it cannot parse is cut into 20-line `chunk` entities named like
  `lines 21-40`, with no dependency graph behind them; Markdown becomes
  `heading`s and TOML `property`s. On the dotfiles repo one real commit came
  back as 19 nix chunks, 10 headings, and 2 actual shell `function`s. Chunk
  scores say "lines changed", not "this is risky" — for a mostly-Nix diff,
  inspect adds little over reading it.
- **Two subcommands write to GitHub: `inspect comment` posts review comments
  on a PR, and the MCP tool `inspect_post_review` does the same.** Posting is
  outward-facing and covered by the outbound message gate
  (`tools/agents/rules/outbound-comment-gate.md`): show the rendered
  body and the destination, and wait for approval. Never run either
  unprompted. (`inspect grep --remote` only reads.)
- **`inspect review` sends code to an LLM provider.** It is the only
  subcommand that does: Anthropic by default via `ANTHROPIC_API_KEY`
  (default model `claude-sonnet-4-5-20250929`, top 10 entities), or
  `--provider openai|ollama`, or `--api-base <url>`. Treat it like any other
  upload of work code — the user's call. It also accepts `--api-key <KEY>`:
  never use that flag, because a key on the command line lands in shell
  history and the process list. Keys come from the environment.
- MCP: upstream's `inspect-mcp` exposes `inspect_triage`, `inspect_entity`,
  `inspect_group`, `inspect_file`, `inspect_stats`, `inspect_risk_map`,
  `inspect_search`, `inspect_predict`, `inspect_pr`, and the write tool
  `inspect_post_review` (names read from the v0.1.1 source, not from a running
  server). It is **not installed here**: upstream publishes no release binary
  for it, and `lib/inspect.nix` packages the CLI only.

## Choosing between them

- Understanding a change you or someone else made → `sem diff`
- About to change something → `sem impact` first
- Merge conflict, or planning parallel agents on one codebase → `weave`
- Big diff/PR, limited attention → `inspect diff` / `inspect pr`
- "What did this change put at risk that it didn't touch?" → `inspect predict`
- History questions ("when did this function change / who owns it") →
  `sem log` / `sem blame`
