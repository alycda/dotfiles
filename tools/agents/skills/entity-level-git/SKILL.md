---
name: entity-level-git
description: >
  Entity-level git tooling from Ataraxy Labs — sem (entity diffs, blame,
  impact analysis, per-function history), weave (semantic merge driver), and
  inspect (structural-risk review triage). Consult this skill FIRST, before
  git diff/blame/log or grepping for callers, when a task looks like: what
  depends on or breaks if I change this function/class; review, summarize, or
  triage a big diff, branch, or PR ("what actually changed", formatter churn
  drowning the real diff); who last touched this function (especially after a
  formatting commit wrecked line-based blame); merge conflicts in code files,
  above all false conflicts where branches or parallel agents edited different
  functions in the same file. Also use whenever sem, weave, or inspect is
  named, and to interpret the sem entity-diff comment CI posts on PRs. The
  entity-level answer is cheaper and more precise than reading whole files.
# Read-only subcommands only. Deliberately NOT `Bash(sem *)` / `Bash(weave *)`:
# a wildcard would pre-approve `sem config setup|update`, `sem cloud *` and
# weave setup, which the body says never to run unprompted - the permission
# prompt is the backstop for those rules, so the allowlist must not remove it.
# `sem check` is left out too: it runs the project's test suite and checkers,
# which is executing the repo's code, not reading it. Also excluded:
# `inspect review` (sends code to an LLM API) and `inspect comment` (posts to
# GitHub). `weave apply` and `weave patch apply` write working files, so they
# are excluded too; `weave explain`/`check` and `sem graph` are read-only and
# are listed because the body tells the reader to run them - explain and check
# exist only from 0.5.x, so on an older weave they simply do not resolve.
# sem 0.27 renamed callers/refs/context/entities to `find` flags and log/blame
# to `history`; both spellings are listed because the old ones still work.
# `sem certify` only reads the repo and writes to stdout (its temp trees are
# its own), checked in the v0.27.0 source.
allowed-tools: Bash(sem diff *), Bash(sem impact *), Bash(sem callers *), Bash(sem refs *), Bash(sem find *), Bash(sem blame *), Bash(sem log *), Bash(sem history *), Bash(sem entities *), Bash(sem graph *), Bash(sem context *), Bash(sem certify *), Bash(weave preview *), Bash(weave summary *), Bash(weave explain *), Bash(weave check *), Bash(inspect diff *), Bash(inspect predict *), Bash(inspect pr *), Bash(inspect file *), Bash(git status), Bash(git log *), Bash(git diff *)
---

# Entity-Level Git (sem, weave, inspect)

Three sibling tools from [Ataraxy Labs](https://github.com/Ataraxy-Labs) that
share one mental model: parse code with tree-sitter into **entities**
(functions, classes, methods) and operate on those instead of lines. Language
coverage is broad but uneven — sem 32, weave 38, inspect 19 (upstream's own
README counts, re-checked 2026-09-22); the mainstream
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
  | `weave` | yes, but stale — see below | `lib/weave.nix`, from home-manager (`profiles/home.nix`, `work.nix`) | both Macs |
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
- sem has a self-updater (`sem config update`; `sem update` before 0.27).
  Don't run it: the binary is brew-managed, and a self-update fights the
  package manager.
- Check with `command -v sem weave inspect` before building a plan around them.
- **Check versions against upstream before trusting a capability verdict**
  (`gh release list -R Ataraxy-Labs/<tool>`). As of 2026-10-14 sem 0.27.0 is
  both upstream's latest and what Homebrew core's `sem-cli` ships, and
  inspect 0.1.1 is the latest upstream has. weave is the awkward
  one: nixpkgs tracks 0.3.6 (2026-06-05) against upstream's 0.5.4, so
  `lib/weave.nix` pins past it — onto `alycda/weave`'s ARB branch rather than
  the upstream tag. A missing weave feature is therefore about *which build
  you have*, not about weave. Run `weave --version` first.

## Language coverage: Dart/Flutter (verified 2026-09-21; sem re-verified 2026-10-14)

Measured on `alycda/DittoXCactus`, a Flutter app (~80 Dart entities). Dart is
the worked example of the uneven-coverage caveat above, and it fails quietly
in all three tools — one of them dangerously:

- **sem: fixed in 0.26.0, now at parity with TypeScript.** On 0.25.0 sem
  extracted Dart entities but built no edges: a two-file repo where
  `app.dart` constructs a class from `greeter.dart` gave `0 edges` and a
  green `✓ No other entities are affected`, and `callers` leaked a TS caller
  into a Dart answer. 0.26.0 fixed Dart call resolution (upstream #491).
  Re-run on 0.27.0 against the same shape plus a typed parameter, in a repo
  holding identical TS twins: `impact` on the Dart class returns
  `← depended on by: function run (dart/app.dart)`, and
  `String typed(Greeter g) => g.hello()` resolves as a caller of `hello`
  exactly as the TS twin does. What is still unresolved —
  `Greeter('x').hello()`, an untyped receiver — is unresolved in TS too.
  sem now says so: an incomplete answer prints `INCOMPLETE` with the reason
  and a "possible callers" list instead of a green check, and that list is
  where a cross-language name match still shows up, labelled as unresolved.
  Re-verified synthetically, not yet on DittoXCactus itself — run `sem
  graph` there and confirm a non-zero edge count before relying on it.
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
  devcontainer, `nix run nixpkgs#weave` — still line-merges ARB. **Don't
  use `weave --version` to decide which you have**: the fork and stock
  0.5.4 both report `weave 0.5.4`. Use the store-path or behaviour probe
  above, and assume stock unless one of them says otherwise.

Net: in a Dart repo on sem ≥ 0.26, use sem and weave as in any other
language. Read `INCOMPLETE` and the possible-caller list before acting on
an `impact` answer, as you would in TS, and skip inspect. On an older sem the
0.25.0 behaviour above applies: never trust `impact` / `callers` / `refs`.
Another language may be in the state Dart was — before trusting a
graph-dependent answer in an untested language, check that the tool
returned real entity kinds (`method`, `class`) rather than `chunk`s, and
that `sem graph` reports a non-zero edge count.

**Don't repeat my measurement mistake.** The first version of this section
claimed weave couldn't parse Dart, on the evidence of a `weave preview`
where every file reported `CONFLICTS: 1 (line-level fallback)` with
`unchanged: 0`. That was an artifact: the two branches' merge base held 3
files, so every path was an add/add with no common ancestor and weave had
nothing to three-way merge. **`git merge-base A B` and check the file
exists there before concluding anything from a `weave preview`** — and
prefer a synthetic two-branch repo for a real language-support verdict.

**Naming** (`sem 0.27.0`): the qualified form is `Class.method` (also
`module.func`, `name@line`), accepted by `find` and `impact`. `Class::method`
is not, but the error now names the `Owner.method` spelling to retry with. When
the name exists in several files, pass `--file` (a directory works too) or
`--entity-id '<path>::class::<Name>'`, which works everywhere.

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
sem impact --diff <range>      # the same for a whole change (e.g. --diff HEAD~1)
sem find <name>                # locate an entity's definition
sem find <entity> --callers    # direct callers only — cheaper than full impact
sem find <entity> --refs       # what the entity itself calls
sem find <entity> --context    # token-budgeted LLM context for an entity
sem find --in <path> --json    # list parsed entities
sem history <entity>           # history of one function/class (-v shows content diffs)
sem history --limit 200        # no entity: repo hotspots + co-change pairs (default scans 50)
sem history --blame <file>     # who last modified each entity in the file
sem graph --json               # every entity and edge (fromEntity/toEntity/refType)
sem certify <range>            # review certificate: signature changes, callers left behind
sem certify <range> --arch --view  # at most 10 ranked architecture items
sem certify <range> --html > f.html  # module-level architecture view, one page
```

Commands checked against `sem 0.27.0`, which folded the old verbs into
these. `callers`, `refs`, `context`, `entities`, `log` and `blame` still
work with identical output (at a terminal they print a one-line note naming
the new spelling), so either form in older notes is fine. When an entity
name is ambiguous, pass `--file <path>` to disambiguate.

Notes:

- **Before large refactors**, run `sem impact` on the entities you're about to
  change — it's the cheap version of "read every caller". For a rename,
  `sem find --callers` is usually the whole answer. **Caveat: the call graph
  is only as good as the language support.** Since 0.26 sem says when its
  answer is partial: `INCOMPLETE` plus a "possible callers" list means
  "none resolved" is *not* "none". Check that list before you refactor.
- **`sem certify` is the "what should a human review" verb** and is local and
  read-only. Use the plain certificate to list signature changes with the
  callers a change left unmodified. Use `--arch --view` for architecture
  deltas (new data paths, side effects, dependencies, cycles). Its `--html`
  page is a *module*-level graph — boxes per directory, not per function.
- `sem check` runs the project's own checkers and tests (exit 0 pass, 1 fail,
  2 undecided). It executes repo code, so treat it like running the test
  suite, not like a read.
- `sem config setup` (`sem setup` before 0.27) rewires `git diff` output
  globally and `sem config unsetup` reverts it. That mutates the user's git
  config: **propose it, never run it unprompted.**
- **Everything above runs locally, and that is the default** — cloud is "off
  until you enable it" and telemetry is "local by default — nothing uploaded"
  (sem's own help text). `sem cloud login|review|xref|enable` and
  `sem config telemetry on` change that by sending repo-derived data to
  Ataraxy's servers. On a machine holding work code that is the user's call
  alone: never run them, and don't suggest them as a performance fix.
- `sem mcp` serves the verbs as MCP tools (`sem_find`, `sem_grep`,
  `sem_impact`, `sem_check`, `sem_certify`, `sem_diff`, `sem_graph`,
  `sem_history`; the pre-0.27 names still answer when called by name). If a
  `sem` MCP server is already registered in the session, prefer its tools
  over shelling out — but not `sem_check` unprompted, for the reason above.
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
this machine forward onto `alycda/weave`'s ARB branch, which is 0.5.4 plus
one patch. On a machine without that pin — a sandbox, a devcontainer,
`nix run nixpkgs#weave` — you get 0.3.6, which has no `explain`, `check`,
`patch` or `apply`. `weave --version` answers *that* question.

**But `--version` cannot tell the fork from stock 0.5.4** — both print
exactly `weave 0.5.4`, because `lib/weave.nix` deliberately keeps
`version = "0.5.4"` so nixpkgs' `versionCheckHook` still passes. When the
difference matters (it matters for `.arb`, below), discriminate one of two
ways: compare `readlink -f $(command -v weave)` against the store path
`lib/weave.nix` evaluates to, or probe the behaviour — merge a scratch
`.arb` and see whether it auto-resolves.

- **Start with `weave preview`.** It changes nothing, so it's safe to run
  unprompted, and it answers "would weave have dissolved these conflicts?"
  before anyone commits to configuring a merge driver.
- **`weave explain` then `weave check` is the conflict loop** (0.5.x). Both
  are read-only and safe unprompted: `explain` says why a file conflicted
  before you touch it, `check` says whether your resolution silently dropped
  something either side had written. `check` exits 1 when it has findings —
  that's the point, not a failure. Exercised end to end on a real conflict:
  `explain` names the refusing guard and the contested hunk (`class Greeter
  — both_modified (F), refused_by: container_member`, listing only hunks
  *both* sides wrote in), and `check` goes from exit 1 / `3 conflict marker
  line(s) still present` to exit 0 / `markers cleared, no unanimous-line
  loss, no duplicated definitions or lines, no dangling references` once the
  file is actually resolved.
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
- **jj integration** (relevant here — jj is the house VCS): weave *can* be
  registered as a jj merge tool, but is not configured on this machine —
  `jj config get merge-tools.weave.program` finds nothing, so this block is
  setup you'd have to propose, not something already in place. In
  `jj config edit --user`:

  ```toml
  [merge-tools.weave]
  program = "weave-driver"
  merge-args = ["$base", "$left", "$right", "-o", "$output", "-l", "$marker_length", "-p", "$path"]
  merge-conflict-exit-codes = [1]
  merge-tool-edits-conflict-markers = true
  conflict-marker-style = "git"
  ```

  The argument shape above is unchanged between 0.3.6 and 0.5.4, so this
  block does not need revisiting with the version. 0.5.x adds `--audit` (or
  `WEAVE_AUDIT=1`, for merge-driver configs that can set env but not add
  flags) to write a per-entity resolution audit as JSON, and
  `WEAVE_FINDINGS=1` to drop a `<path>.weave-findings.json` beside a
  conflicted file.

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
- "What should a human look at in this range?" → `sem certify <range>`
- **Dart/Flutter repo** → sem (≥ 0.26) and `weave` as usual; inspect
  doesn't parse Dart. See **Language coverage: Dart/Flutter**.
