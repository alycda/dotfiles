---
name: entity-level-git
description: >
  Entity-level history tooling from Ataraxy Labs: sem (entity diffs, blame,
  impact analysis, per-function history), weave (semantic merge driver) and
  inspect (structural-risk review triage). Consult
  this skill FIRST, before reading a whole diff, running blame, or grepping
  for callers, when a task looks like: what changed in this change, in terms
  of functions, sections and keys rather than lines (including to write its
  commit message or to split it by concern); what depends on or breaks if I
  change this function; who last touched this function; formatter churn
  drowning the real diff; merge conflicts, above all false ones where two
  sides edited different functions of one file; where review attention
  should go in a big diff; drawing what a change reaches as a Mermaid
  diagram. Also use whenever sem, weave, or inspect is named.
# Read-only subcommands only. Deliberately NOT `Bash(sem *)`: a wildcard would
# pre-approve `sem config setup|update|telemetry` and `sem cloud *` (and their
# pre-0.27 spellings), which the body says never to run unprompted - the
# permission prompt is the backstop for those. `sem check` is left out too: it
# runs the project's checkers and tests, which executes the repo's code.
# sem 0.27 renamed callers/refs/context/entities to `find` flags and log/blame
# to `history`; both spellings are listed because the old ones still work.
# `sem certify` only reads the repo and writes to stdout.
# Same for weave: setup/unsetup change config, and apply writes files. And
# for inspect: review sends code to an LLM API, comment posts to GitHub, and
# pr calls gh.
allowed-tools: Bash(sem diff *), Bash(sem impact *), Bash(sem callers *), Bash(sem refs *), Bash(sem find *), Bash(sem blame *), Bash(sem log *), Bash(sem history *), Bash(sem entities *), Bash(sem graph *), Bash(sem context *), Bash(sem certify *), Bash(weave preview *), Bash(weave summary *), Bash(weave explain *), Bash(weave check *), Bash(inspect diff *), Bash(inspect predict *), Bash(inspect file *), Bash(jj log *), Bash(jj diff *)
---

# Entity-Level History (sem)

[sem](https://github.com/Ataraxy-Labs/sem) parses files with tree-sitter into
**entities** (functions, classes, methods; sections and keys in TOML, YAML,
JSON and Markdown) and diffs, blames and traces those instead of lines. The
payoff is precision per token: "the `tools` section of `mise.toml` changed"
instead of reading the file to reconstruct that yourself.

## Availability

- sem, weave and inspect come from mise in this repo (`mise.toml`), or from
  home-manager on a Nix account (`lib/packages/`), at the same versions.
  Check with `sem --version`; under mise, where it is active, or prefix
  `mise exec --`.
- weave is two tools: `weave` (the CLI) and `weave-driver` (what jj and git
  invoke to merge).
- **Other packages named sem are different programs**: mise's registry has no
  sem (so `mise.toml` names the GitHub repo), and `nixpkgs#sem` is the
  Semaphore CI CLI. Its errors won't say so.
- Don't run `sem config update` (`sem update` before 0.27): mise or Nix
  manages the binary, and a self-update fights it.
- The commands below are written for sem 0.27. Check `sem --version`: on
  0.25 the pre-0.27 spellings are the ones that exist, and Dart's call graph
  is empty (see the language note).

## In this repo: sem on jj

sem reads git, and this is _probably_ a colocated jj repository, so git sees jj's
changes. Translate as follows:

| You want | Run |
|---|---|
| The working-copy change (`@`) | `sem diff` (git's HEAD is `@-`) |
| Any other change | `sem diff --commit $(jj log --no-graph -r <change> -T commit_id)` |
| A range of changes | `sem diff --from <commit id> --to <commit id>` |

Don't use `sem diff --staged`: jj has no staging area, so it shows nothing
useful.

**For commit messages** (the commit-craft skill): run `sem diff
--no-cosmetics` on the change before describing it. The changed entities say
what the change is about, which is what the subject should name, and
entities with nothing in common are the signal to `jj split` by concern.

## sem commands

```bash
sem diff                       # entity-level working-tree diff (git diff syntax works)
sem diff --no-cosmetics        # drop formatting-only changes: the formatter-churn case
sem diff --json                # machine-readable; carries entity IDs for `impact`
sem impact <entity>            # deps, dependents, transitive impact, tests
sem impact <entity> --tests    # only the affected test entities
sem impact <entity> --depth 0  # unlimited transitive depth (default is 2)
sem find <name>                # locate an entity's definition
sem find <entity> --callers    # direct callers only - cheaper than full impact
sem find <entity> --refs       # what the entity itself calls
sem find <entity> --context    # token-budgeted LLM context for an entity
sem find --in <path> --json    # list parsed entities
sem history <entity>           # one entity's history (-v: content diffs)
sem history --limit 200        # no entity: repo hotspots + co-change pairs
sem history --blame <file>     # who last modified each entity in the file
sem graph --json               # every entity and edge
sem certify <range>            # signature changes, callers left behind
sem certify <range> --arch --view    # top 10 architecture items
sem certify <range> --html > f.html  # module-level view, one page
```

sem 0.27 folded `callers`, `refs`, `context`, `entities`, `log` and `blame`
into the verbs above. The old spellings still work with identical output, so
either form in older notes is fine.

Naming: the qualified form is `Class.method` (also `module.func`,
`name@line`), accepted by `find` and `impact`; `Class::method` is not, and the
error names the spelling to retry with. When the name exists in several
files, pass `--file` (a directory works too) or `--entity-id
'<path>::class::<Name>'`, which works everywhere.

- **Before a refactor**, run `sem impact` on what you're about to change; for
  a rename, `sem find --callers` is usually the whole answer.
- **An `INCOMPLETE` answer is not "none".** Since 0.26 sem says when it could
  not resolve every call: it prints `INCOMPLETE` with the reason and a
  "possible callers" list instead of a green check. Read that list before
  acting on an `impact` answer. Cross-language name matches surface there,
  labelled as unresolved.
- **The call graph is only as good as the language support.** Before
  trusting a graph answer in a language you haven't seen sem handle, check
  that it returned real entity kinds rather than `chunk`s and that `sem graph`
  reports a non-zero edge count. Dart was the example: on 0.25 its graph was
  empty and "no other entities are affected" was a false negative. 0.26 fixed
  Dart call resolution (upstream #491); re-checked on 0.27 on a synthetic
  Dart + TypeScript repo, where Dart resolves as the TS twin does, but not yet
  on a real Flutter app.
- **`sem certify` is the "what should a human review" verb**, local and
  read-only. Its `--html` page is a self-contained, module-level graph (boxes
  per directory, not per function), so it complements the entity diagram
  below rather than replacing it.
- `sem check` runs the project's own checkers and tests. It executes repo
  code: treat it like running the test suite, not like a read.

## What never to run unprompted

- `sem config setup` (`sem setup` before 0.27) rewires `git diff` output
  globally (`sem config unsetup` reverts it). It changes the user's git
  config: propose it, never run it.
- `sem cloud login|review|xref|enable` and `sem config telemetry on` (before
  0.27: `sem login`, `review`, `xref`, `telemetry on`) send repo-derived data
  to Ataraxy's servers. Everything else runs locally, and that is the
  default. That choice is the user's alone: never run them, and don't suggest
  them as a fix.
- `sem mcp` serves these commands as MCP tools. If a sem MCP server is
  already registered in the session, prefer its tools to shelling out, but
  not `sem_check` unprompted, for the reason above.

## Drawing it: Mermaid from sem's graph, never from reading code

When a picture explains a change better than a list ("what does touching
this reach?"), draw it from sem's data. An edge invented from reading the
code looks exactly as authoritative as a real one, so **every node and edge
in the diagram comes from sem output.**

**Impact as a flowchart:** run the renderer in this skill's directory.

```bash
s=.claude/skills/entity-level-git/scripts/sem-mermaid.py
$s -- <entity> --file <path>      # args after -- go to sem impact
$s --max-nodes 30 -C ../repo -- --entity-id '<id>' --depth 1
```

It takes nodes from `sem impact --json` and edges from `sem graph --json`,
filtered to those nodes, because impact's JSON gives each entity's depth but
not which entity it was reached through. The target is bold, resolved edges
solid, possible callers dotted and labelled `unresolved`, and `%%` comments
carry `INCOMPLETE` reasons. Paste it in a ```` ```mermaid ```` block. It
refuses rather than draw something misleading:

- **exit 2** when `sem graph` has no edges in the target's language: an empty
  graph drawn as a diagram reads as "nothing depends on this". Fall back to
  `rg`.
- **exit 3** above `--max-nodes` (default 20). Lower `--depth` before raising
  the cap.
- Possible callers from another language family are dropped and counted in a
  `%%` line.

**Diff as a text tree, not Mermaid.** For "what changed", an entity tree read
off `sem diff --json` beats a graph: it has no edges, so nothing in it can be
invented. **Architecture:** `sem certify <range> --html`. One diagram per
question, next to the sentence it supports; if the answer fits in two
sentences, don't draw.

## weave: entity-level merges

Line merges invent conflicts when two changes touch nearby lines, which is
what happens when Lanes or parallel agents edit one file. weave merges at
entity granularity instead; file types it can't parse fall back to a line
merge, silently.

```bash
weave preview <branch>          # dry-run merging <branch> into HEAD; read-only
weave preview <branch> --file f # ...for one file
weave explain <file>            # read-only: why this file conflicted, and the
                                #   hunks both sides wrote in
weave check                     # read-only: verify a resolution (markers left,
                                #   lines dropped, references that no longer
                                #   resolve); exits 1 on findings
weave summary <file>            # structured summary of weave conflict markers
```

- `weave preview`, `explain`, `check` and `summary` change nothing: run them
  unprompted. `check` exiting 1 is a finding, not a failure.
- `weave preview` takes git refs. In jj, pass commit IDs, and check that the
  file exists at the merge base (`jj log -r 'heads(::A & ::B)'`) before
  concluding anything: an add/add has no base to merge from, so every file
  shows as a line-level conflict.
- `weave setup` writes `.gitattributes` and merge-driver config, and
  `--global` does it for every repo on the machine. Propose it with the
  `--local` variant first; never run it unprompted.
- `weave apply` and `weave patch apply` write to working files. They are
  edits, not a way to have a look.
- For resolving jj conflicts with weave, see the jujutsu skill.

## inspect: review triage by structural risk

Reach for inspect when facing a large diff and the question is where review
attention should go.

```bash
inspect diff <range>                # triage a commit or range (A..B, a commit ID)
inspect diff <range> --min-risk high # critical | high | medium | low
inspect diff <range> --context      # add dependency context
inspect diff <range> --format json  # terminal (default) | json | markdown
inspect predict <range>             # UNCHANGED entities at risk of breaking
inspect file <path>                 # uncommitted changes in one file
```

- In jj, pass commit IDs: `inspect diff $(jj log --no-graph -r <change> -T
  commit_id)`.
- Triage is local and needs no API key. Order review by its risk level:
  functional and high-risk first, text-only last.
- **Check the entity types before trusting the scores.** inspect does not
  parse Nix or Dart: a file it can't parse is cut into line chunks with no
  dependency graph, and their scores only say how many lines changed.
- `inspect review` sends code to an LLM provider, and `inspect comment` posts
  review comments to GitHub. Never run either unprompted, and never pass an
  API key on the command line.
