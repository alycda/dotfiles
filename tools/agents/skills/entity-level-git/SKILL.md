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
That degradation is silent, though, and for one language it is verified to be
worse than "graceful" — see **Language coverage: Dart/Flutter** below.
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
- **Check versions against upstream before trusting a capability verdict**
  (`gh release list -R Ataraxy-Labs/<tool>`). As of 2026-09-21 sem 0.25.0 is
  current and inspect 0.1.1 is the latest upstream has, but the
  home-manager-pinned weave 0.3.6 (2026-06-05) is four months behind v0.5.4.
  A missing feature may just be a stale pin.

## Language coverage: Dart/Flutter (verified 2026-09-21)

Measured on `alycda/DittoXCactus`, a Flutter app (~80 Dart entities). Dart is
the worked example of the uneven-coverage caveat above, and it fails quietly
in all three tools — one of them dangerously:

- **sem extracts Dart entities but builds no edges between them.** `diff`,
  `blame`, `log`, `entities` and `context` are all correct and worth using.
  The dependency graph is empty: in a two-file Dart repo where `app.dart`
  constructs a class from `greeter.dart`, `sem graph` reports
  `3 entities, 0 edges`, `sem impact` on the class answers
  `✓ No other entities are affected`, and `callers`/`refs` both say "none".
  The identical shapes in TypeScript produce the edge and the correct
  `← depended on by: function run (ts/app.ts)`. So this is Dart reference
  extraction, not a sem-wide limit. **In a Dart repo that checkmark is a
  false negative, not permission to refactor — `rg` for the callers.**
  Worse, in a mixed-language repo the name matching leaks: `sem callers
  hello --file dart/greeter.dart` returned `function run ts/app.ts:3`, a
  caller in a different file *and a different language*. Treat any
  graph-derived Dart answer as unusable in both directions.
- **inspect does not parse Dart at all.** `inspect diff` on a 7-file branch
  returned 61 `chunk` entities (`lines 161-180`) plus 1 `section` — zero
  functions, zero classes — under a headline of "0 critical, 0 high, 48
  medium, 14 low". Those scores are line counts wearing a costume.
  `inspect predict` said "No entities at risk", which means only that it had
  no graph to predict from. Skip inspect on Flutter work. Upstream has no
  Dart or Flutter issue or PR of any kind, and no release since v0.1.1
  (2026-04-02), so don't expect this to change on its own.
- **weave handles Dart fine** — support merged upstream in PR #85
  (2026-05-11), shipped from v0.3.3. Verified on 0.3.6: two branches
  editing two different methods of one class preview as
  `a.dart — auto-resolved`. Use it normally on Flutter work. **`.arb`
  depends on which build you have.** Flutter localization bundles are JSON
  under another extension, and stock weave doesn't route them to the JSON
  plugin — verified on upstream 0.5.4 with byte-identical content in both
  files: `app_en.json — auto-resolved`, `app_en.arb — CONFLICTS: 1
  (line-level fallback)`. Two branches each adding one message conflict.
  `lib/weave.nix` pins this machine to `alycda/weave#1`, which aliases
  `.arb` onto the JSON plugin, so here both files report `auto-resolved`
  with identical stats. Anywhere without that pin — a sandbox, a
  devcontainer, `nix run nixpkgs#weave` — still line-merges ARB. Check
  `weave --version` isn't 0.3.x and assume stock behavior unless you know
  the pin is in play.

Net: in a Dart repo, use `sem diff` / `blame` / `log` / `entities` /
`context` and `weave` freely, never trust `sem impact` / `callers` / `refs`,
and skip inspect. Dart may not be the only language in this state — before
trusting a graph-dependent answer in an untested language, check that the
tool returned real entity kinds (`method`, `class`) rather than `chunk`s,
and that `sem graph` reports a non-zero edge count.

**Don't repeat my measurement mistake.** The first version of this section
claimed weave couldn't parse Dart, on the evidence of a `weave preview`
where every file reported `CONFLICTS: 1 (line-level fallback)` with
`unchanged: 0`. That was an artifact: the two branches' merge base held 3
files, so every path was an add/add with no common ancestor and weave had
nothing to three-way merge. **`git merge-base A B` and check the file
exists there before concluding anything from a `weave preview`** — and
prefer a synthetic two-branch repo for a real language-support verdict.

**Naming wart** (`sem 0.25.0`, not Dart-specific): the `Class::method` form
resolves for `impact` but is rejected by `callers`
(`error: no entity named 'DittoService::initialize'`). A bare name prints a
disambiguation list; `--entity-id '<path>::class::<Name>'` works everywhere.

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
  `sem callers` is usually the whole answer. **Caveat: the call graph is
  only as good as the language support** — in Dart it is file-local and
  "no other entities are affected" is routinely wrong. See
  **Language coverage: Dart/Flutter** above.
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
weave explain <file>            # read-only: why THIS file conflicted — which guard
                                #   refused, and the hunks both sides wrote in.
                                #   Reads the three merge stages out of the index
weave check                     # read-only: verify a resolution against those stages
                                #   (markers left behind, lines silently dropped,
                                #   references that no longer resolve). Exits 1 on
                                #   findings, so guard it in a `&&` chain
weave summary <file>            # structured summary of weave conflict markers
weave setup                     # enable: writes .gitattributes + merge driver config
weave setup --local             # .git/info/attributes instead (nothing committed)
weave unsetup                   # revert to standard git merge
```

Commands checked against `weave 0.5.4`, which ships three binaries: `weave`
(the CLI above), `weave-driver` (what git/jj invoke), and `weave-mcp`. Older
READMEs call the CLI `weave-cli`; that name does not exist, so don't propose
it. (`setup --global` *does* exist again in 0.5.x — see the setup bullet.)

**0.5.x is newer than nixpkgs.** nixpkgs tracks 0.3.6; `lib/weave.nix` pins
this machine forward to 0.5.4. On a machine without that pin — a sandbox, a
devcontainer, `nix run nixpkgs#weave` — you get 0.3.6, which has no
`explain`, `check`, `patch` or `apply`. Run `weave --version` before relying
on those four.

- **Start with `weave preview`.** It changes nothing, so it's safe to run
  unprompted, and it answers "would weave have dissolved these conflicts?"
  before anyone commits to configuring a merge driver.
- **`weave explain` then `weave check` is the conflict loop** (0.5.x). Both
  are read-only and safe unprompted: `explain` says why a file conflicted
  before you touch it, `check` says whether your resolution silently dropped
  something either side had written. `check` exits 1 when it has findings —
  that's the point, not a failure.
- `weave setup` **mutates repo config and possibly tracked files**
  (`.gitattributes`): propose it and let the user choose the variant; don't
  run it unprompted. `--local` is the least invasive; **`--global` is the most
  — it writes `~/.gitconfig` plus a global attributes file and makes weave the
  default merge driver in every repo on the machine.** Never propose
  `--global` as the default variant.
- **`weave apply` and `weave patch apply` write to working files** — `apply`
  materializes entity edits from the CRDT onto the tree, `patch apply` lands
  typed entity ops as a three-way entity merge. Neither is read-only; treat
  them like any other edit and don't run them to "have a look".
  (`weave patch extract` only reads.)
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
- **Dart/Flutter repo** → `sem diff` / `blame` / `log` / `context` and
  `weave` are fine; `sem impact` / `callers` / `refs` return empty graphs,
  and inspect doesn't parse Dart. See **Language coverage: Dart/Flutter**.
