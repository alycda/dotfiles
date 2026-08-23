---
name: jujutsu
description: >
  Activates first on any git/VCS operation when Alyssa is in a Jujutsu (jj) repository —
  anywhere `.jj/` exists in the project tree. Use for commits, status, bookmarks, push,
  fetch, rebase, history rewriting, file tracking, and `.gitignore` changes. Especially
  trigger before creating new files, running builds, or editing `.gitignore`, since jj
  auto-snapshots everything and retroactive cleanup is expensive if not done right. Pinned
  to jj v0.44. Raw `git` commands in a non-colocated jj repo can corrupt state, so always
  reach for this skill first when she mentions jj, jujutsu, change IDs, revsets, bookmarks,
  or anything VCS-shaped in a jj repo — even if she just says "commit this" or "what's
  the status," because in a jj repo those words mean different operations.
allowed-tools: Bash(jj *), Bash(git status), Bash(git log *)
---

# Jujutsu (jj) Skill

Alyssa uses Jujutsu (jj) as her daily-driver VCS in colocated mode (both `.jj/` and
`.git/` present). This skill teaches Claude to operate in jj repos without reaching for
git muscle memory.

**Pinned version:** jj v0.44. The canonical destination flag for `rebase`, `split`, and
`revert` is `--onto`/`-o` (`--destination`/`-d` survives as an alias). Two flags older
tutorials use are **gone** in v0.44: `jj git push --allow-new` (use `--named
<name>=<rev>`) and `jj describe --edit`. See `references/version-notes.md` for the full
delta.

**Core principle:** jj's auto-snapshot behavior is a power tool. It captures every file
in the working directory automatically — which means if Claude generates an artifact
without checking `.gitignore` first, that artifact is now in version control. Retroactive
cleanup is possible but expensive. The cheapest fix happens **before** the file gets
tracked, not after.

**Detection:** If `.jj/` exists in the project root (or any parent), this is a jj repo.
Use jj commands. Do not fall back to `git` unless the repo is colocated AND you know what
you're doing — see "Colocated Repos" below.

---

## Mental Model

### The working copy is a commit

There is no staging area. There is no `jj add`. The working directory is always a commit,
referenced as `@`. Every time Claude runs any jj command, jj snapshots the working copy
first. New files appear automatically. Deleted files disappear automatically. There is no
`git add`/`git rm` step.

Implication: between `jj` commands, anything in the working directory that isn't
gitignored is effectively committed. Be deliberate about what's in the working directory.

### Change ID vs commit ID

- **Change ID** (e.g., `tqpwlqmp`) — stable across rewrites. Use these when referring to
  commits in conversation, scripts, or sequenced operations. They survive rebase, amend,
  and squash.
- **Commit ID** (e.g., `3ccf7581`) — content hash. Changes whenever the commit's content
  changes. Compatible with git tools.

**Default:** Use change IDs. Only use commit IDs when interoperating with git tooling or
when explicitly asked.

### Revsets

jj uses a small functional language for selecting commits. The ones that come up most:

- `@` — working copy
- `@-` — parent of working copy
- `@--` — grandparent (chain works: `@---`, etc.)
- `trunk()` — the default bookmark of the default remote (usually `main@origin`)
- `trunk()..@` — commits between trunk and `@` (your local stack)
- `<change-id>::` — that change and all descendants
- `::<change-id>` — that change and all ancestors
- `<a>..<b>` — between, exclusive of `<a>`

Pass revsets via `-r`: `jj log -r 'trunk()..@'`. Quote revsets with spaces or special
characters.

### The immutability boundary

By default, `trunk()` and its ancestors are immutable — jj refuses to rewrite them. This
is a safety rail. If Claude tries to `jj edit` or `jj rebase` something in this set, jj
will error out with a hint. **Treat the error as a stop sign.** It almost always means
something pushed has entered the picture. Surface the situation to Alyssa rather than
overriding with `--ignore-immutable`.

### .gitignore semantics in jj (read this carefully)

jj reads `.gitignore` files. But the semantics are not identical to git:

1. **`.gitignore` only prevents auto-tracking of files that aren't yet tracked.** Files
   already tracked in any visible commit stay tracked even if `.gitignore` would match them.
2. **`jj file untrack <path>` only works if `<path>` is already in `.gitignore`** at the
   point you run it. Otherwise the next auto-snapshot retracks it. There is no flag to
   force this — open issue jj-vcs/jj#5225.
3. **Rebasing past a new `.gitignore` does not remove already-tracked content from rebased
   commits.** This is the most common confusion. The diff being reapplied still adds the
   file.

The implication is in the next section.

---

## Agent Environment Rules

### Always use `-m` for messages

Editor prompts hang in non-interactive environments. Every command that accepts `-m` must
get one inline:

```
jj describe -m "message"      # NOT: jj describe
jj new -m "message"           # NOT: jj new (which still works but leaves @ undescribed)
jj commit -m "message"        # NOT: jj commit
jj squash -m "message"        # NOT: jj squash (opens editor for combined description)
```

### Avoid interactive commands

These open TUIs and hang. Use alternatives:

| Avoid | Use instead |
| --- | --- |
| `jj split` (no args) | `jj split <path>...` with explicit fileset, or `jj squash`/`jj restore` patterns |
| `jj squash -i` | `jj squash <path>...` with explicit fileset |
| `jj resolve` | Edit conflict markers directly in the affected files, then `jj st` to verify |
| `jj describe` (no `-m`) | `jj describe -m "..."` |

### Verify after mutation

After any of `squash`, `abandon`, `rebase`, `restore`, `new`, `edit`, or `untrack`, run
`jj st` and `jj log` to confirm the state. jj is good but it's not magic; verify before
moving on. Especially after `restore --from --to`, because that operation modifies a
non-`@` commit and the change isn't visible in working-copy diffs.

### Diff format

Default `jj diff` uses a side-by-side numbered format that does not look like git's
`+`/`-` output. Always use `jj diff --git` to get standard unified diff format. Same goes
for `jj show --git`.

### Colocated repos

Alyssa's repos are colocated (`.jj/` and `.git/` both exist). Rules:

- **Default to `jj` commands for everything.** Including `jj git push`, `jj git fetch`.
  Never run `git push` or `git pull` from the agent.
- **Read-only `git` is fine.** `git log`, `git status`, `git diff` won't corrupt state.
- **Never `git checkout`, `git switch`, `git reset`, `git rebase`, or `git commit`.** Use
  `jj edit`, `jj new`, `jj undo`, `jj rebase`, and `jj commit` respectively.
- **GitHub CLI (`gh`) is fine** for PR-shaped operations after a `jj git push`.

---

## Essential Workflow

### Describe first, then code

Claude's default workflow when starting a new piece of work:

```
# Verify @ is empty (or close work on @ first)
jj st

# Create a new commit on top, with the intended description
jj new -m "What I'm about to do"

# Now make changes — they auto-snapshot into @
```

This pattern surfaces intent before code exists. If Alyssa hasn't told Claude what to
commit message-wise, ask once and then proceed.

### Atomic commits

One logical change per commit. If a commit description starts to need "and" to cover
everything, that's the signal to split. Use the squash/restore patterns to peel out
unrelated changes rather than mashing them in.

Commit message format (Alyssa's convention, matches the team's):
- Imperative verb, sentence case, no trailing period
- `feat:` / `fix:` / `refactor:` / `docs:` / `chore:` prefixes when conventional commits
  are in use in the repo

### Viewing history

```
jj log                          # default log (revset depends on config)
jj log -r '@-::@'               # working copy and parent
jj log -r 'trunk()..@'          # local stack
jj log -p -r <change-id>        # with patch
jj show <change-id>             # show one commit
jj show --git <change-id>       # git-style diff format
jj diff --git                   # working copy diff
```

### Moving between commits

```
jj new                          # new empty commit on top of @
jj new <change-id>              # new empty commit on top of <change-id>
jj edit <change-id>             # set @ to <change-id> (commit becomes the working copy)
jj prev -e                      # set @ to @-
jj next -e                      # set @ to @+
```

**`jj new` vs `jj edit`:** `jj new` creates a fresh empty child. `jj edit` makes an
existing commit the working copy. Default to `jj new`; use `jj edit` only when explicitly
modifying a specific historical change.

---

## File Tracking and .gitignore

**This section is load-bearing for Alyssa's workflow.** Claude must follow these rules
strictly. See `references/gitignore-recovery.md` for the full scenario walkthroughs.

### Rule 1: Check `.gitignore` BEFORE generating files

Before running any command that creates artifacts (`cargo build`, `npm install`,
`pytest`, `flutter build`, code generators, etc.), check `.gitignore` to confirm the
expected output directories are covered. Common patterns by ecosystem:

- Rust: `target/`, `Cargo.lock` (libraries only)
- Node: `node_modules/`, `dist/`, `.next/`, `coverage/`
- Python: `__pycache__/`, `*.pyc`, `.pytest_cache/`, `.venv/`, `*.egg-info/`
- Flutter/Dart: `.dart_tool/`, `build/`, `.flutter-plugins`
- General: `.env`, `.env.*`, `*.log`, `.DS_Store`, IDE configs

If a relevant pattern is missing and the build is about to happen, add it to
`.gitignore` first. This is the cheapest intervention by orders of magnitude.

### Rule 2: Reflex pattern when an unwanted file is in `@`

If `jj st` shows a file in `@` that shouldn't be tracked, fix it before doing anything
else. Two commands:

```
echo '<pattern>' >> .gitignore
jj file untrack <path>
```

This adds the pattern to `.gitignore`, then untracks the file (which works because the
pattern is now in `.gitignore`). Both edits land in `@`'s snapshot together. Don't move
to a new commit until `jj st` is clean of the unwanted file.

### Rule 3: Retroactive fix for local commits (NOT pushed)

When the file is in earlier local commits in the stack, use the elegant pattern. Three
phases:

**Phase 1 — put `.gitignore` in place as an ancestor commit, without leaving `@`:**

```
# Add the pattern in @ (it auto-snapshots)
echo '<pattern>' >> .gitignore

# Create an empty commit before the earliest tainted change, WITHOUT switching to it
jj new --no-edit --insert-before <earliest-tainted-change> -m "ignore <pattern>"
# Capture the new change ID from output, e.g. `wxyz`

# Move the .gitignore change from @ into the new early commit
jj squash .gitignore --from @ --into wxyz
```

After this, `@` is back to its pre-edit state, and the new commit `wxyz` carries the
`.gitignore` addition. All commits between `wxyz` and `@` were rebased through `wxyz`.

**Phase 2 — remove the file from each tainted commit, still without leaving `@`:**

```
# For each tainted commit, restore the file's (non-existent) state from wxyz
jj restore --from wxyz --to <tainted-change> <path>
```

`jj restore --from X --to Y <path>` copies the state of `<path>` from `X` into `Y`. Since
`<path>` doesn't exist in `wxyz`, this effectively removes it from `<tainted-change>`.
`@` doesn't move. Repeat for each tainted commit.

**Phase 3 — verify:**

```
jj log -p -r 'wxyz::@' -- <path>     # should show the file appearing nowhere
jj st
```

### Rule 4: Pushed already? Stop.

If the tainted commits have been pushed (visible in `jj log` with a remote bookmark or
in the immutable set), do not unilaterally rewrite. Surface the situation:

> "[file] was tracked in <change-id>, which has already been pushed to <remote>.
> Rewriting requires coordinating with anyone who has pulled this branch. Should I
> proceed with rewriting (force-push), or add the file to `.gitignore` and `jj file
> untrack` going forward?"

Wait for Alyssa's decision. The second option preserves history but leaves the file in
the historical commits.

### Rule 5: The `snapshot.auto-track` escape hatch

If Alyssa is in a context where many spurious files appear (e.g., LLM-generated
artifacts, build outputs scattered around), the `snapshot.auto-track` config narrows
what gets snapshotted in the first place. Example:

```
# In .jj/repo/config.toml or via:
jj config set --repo snapshot.auto-track 'glob:"**/*.{rs,toml,md,dart,js,ts}"'
```

This makes jj snapshot ONLY files matching the fileset; everything else needs an
explicit `jj file track`. This is more aggressive than `.gitignore` and is worth
suggesting if Rules 1–3 aren't holding the line. Documented in
[the working-copy reference](https://docs.jj-vcs.dev/latest/working-copy/).

---

## The Elegant Moves

These three operations are what makes jj qualitatively easier than git for history
work. They have no clean git equivalent.

### `jj squash <path>... --from <X> --into <Y>`

Move specific file changes between two arbitrary commits without switching `@`. `--from`
takes a revset (can resolve to many commits — changes are squashed out of all of them).
`--into` takes a single commit.

```
# Move just the .gitignore change from @ into an earlier commit
jj squash .gitignore --from @ --into <earlier>

# Pull all changes to `vendor/` from a range of commits into one consolidated commit
jj squash vendor --from r1::rN --into <target>
```

Default: if `--into` is omitted, defaults to `@`. If `--from` is omitted, defaults to `@`.

### `jj new --no-edit --insert-before <change>` (or `--insert-after`)

Create a new commit at an arbitrary position in the chain without setting `@` to it.
Descendants get rebased through the new commit automatically.

```
jj new --no-edit --insert-before <change-id> -m "description"
jj new --no-edit --insert-after  <change-id> -m "description"
```

Combined with `jj squash <path> --from @ --into <new-change>`, this is the canonical way
to insert ancestor content (like a `.gitignore` update, a setup file, a config change)
into an existing chain without disrupting the working copy.

**When this combo produces conflicts:** the squash-from-@ pattern assumes the path's delta
at `@` (relative to `@-`) can apply cleanly when re-parented onto `<new-change>`'s parent.
If `@-` and `<new-change>`'s parent have **diverged significantly in the contents of that
path** — e.g., 30+ accumulated lines in `.gitignore` between them — jj's 3-way merge will
mark the new commit as conflicted. The conflict isn't downstream propagation; it's in the
target itself.

Diagnostic: `jj show --git <new-change>` and look for `<<<<<<< Conflict` markers in the
file. If the conflict spans the whole intermediate diff, the squash approach won't
produce a clean commit no matter how you slice the source delta.

Workarounds, in order of preference:
1. **Squash from the original commit, not from `@`.** If the change you want already
   exists in an ancestor commit (e.g., `nkkvtnwn`'s `.gitignore` addition lives in
   `nkkvtnwn`, not in `@`), then `jj squash .gitignore --from <orig> --into <new>`
   computes the delta as `<orig>-vs-<orig-parent>` and applies it to `<new>`'s parent.
   When `<orig-parent>` and `<new>`'s parent have the same content for that path,
   3-way merge resolves cleanly. **This is the right tool for "extract a path change
   from a buried commit and pull it closer to an ancestor."** See "Extract path changes
   backward" below for the full recipe.
2. **Insert closer to `@`.** If `<new-change>` can be placed near `@` instead of near an
   ancient ancestor, the parent-trees converge and the squash applies cleanly.
3. **Accept brief `@` movement.** `jj edit <new-change>`, write the target content
   directly on disk, `jj edit <original-@>`. Noisy but reliable. Batch multiple
   target-side edits in a single outbound trip to minimize working-copy churn (each
   `jj edit` materializes the destination tree, which can be hundreds of files).
4. **Git plumbing.** `git commit-tree` with a manually-constructed tree and the desired
   parent, then `jj git import` to re-sync. Use when (1)–(3) are unacceptable.

Do NOT try to "force" the squash with the resulting conflict in place — squashing a
conflicted commit further propagates the conflict and produces worse outcomes than
the workarounds above.

### Extract path changes backward (the verified recipe)

When you want to roll a set of path changes (typically `.gitignore` additions) closer to
an ancestor commit `T` so they land logically as ancestors of the rest of the work:

**Setup.** Identify the target `T`. Find every commit in `T::@` that modifies the path,
oldest first:

```
jj log -r 'files("<path>") & T::@' --no-graph
```

**Per-commit extraction.** For each gitignore-modifying commit `<orig>`, oldest first:

```
# Insert empty in-between commit right before T's main-chain continuation
jj new --no-edit --insert-before <main-chain-child-of-T> -m "<descriptive message>"
# Capture the new change ID from output, call it <new>

# Move the original commit's path delta into the new commit
jj squash <path> --from <orig> --into <new>
```

After the first iteration, the next `jj new --no-edit --insert-before <main-chain-child>`
inserts the second in-between commit between the first in-between and the original child
— each new commit naturally stacks in the chain in order.

**Why this works without conflicts.** Each `<orig>` commit's diff is `<orig>` vs
`<orig>`'s parent. When the intermediate commits between `T` and `<orig>` don't touch
the path, `<orig>`'s parent has identical path content to `T` — so applying that diff
to a new commit whose parent is `T` (or whose parent is a previous in-between that
appended to `T`) lands at the same byte position. The hunk header from the original
commit (e.g., `@@ -63,3 +63,32 @@`) is preserved exactly in the new commit.

**Why NOT siblings of `T`.** A sibling holding "+X after end of T's gitignore" conflicts
at squash time with any other sibling that also appends to T's gitignore. The first
squash succeeds; the second hits a 3-way-merge conflict because they both want to occupy
the same trailing position. The in-between chain has no such problem: each commit's
append position is naturally distinct (each appends after the previous).

**Verification:**

```
jj diff --git -r <new-1>                # should show <orig-1>'s original hunk
jj diff --git -r <orig-1> -- <path>     # should be empty
jj log -r 'T | T::@ & files("<path>")'  # should now show only the new in-between commits
```

**Skill shortcut.** When this pattern matches what Alyssa wants, invoke
`/jj-extract-gitignores` (or its `args` form `/jj-extract-gitignores <target>`) for
the automated workflow.

### `jj absorb`

Distribute the changes in `@` (or another commit) into the ancestor commits that last
modified those same lines. Like Mercurial's `hg absorb`.

```
jj absorb           # distribute @ into ancestors based on blame
jj absorb -r <id>   # distribute that commit's changes instead
```

Use when accumulating fixes that should logically attach to earlier commits in a stack.
Less precise than manual `jj squash`, but fast. Verify after with `jj log -p` because
absorb's heuristic can be wrong.

---

## Bookmarks and Pushing

### Bookmarks aren't branches

A bookmark is a named pointer at a commit. Unlike a git branch, **it does not auto-advance
when you commit on top of it.** When you create new commits past a bookmark, the bookmark
stays where it was. You must move it explicitly before pushing.

```
jj bookmark create my-feature -r @          # create at @
jj bookmark move   my-feature --to @         # move to @
jj bookmark advance                           # move the closest bookmark(s) to @ (v0.44)
jj bookmark list                              # show bookmarks
jj bookmark delete my-feature                 # delete (commits stay)
jj bookmark track <name>@<remote>             # track a remote bookmark
```

`jj bookmark advance` is the ergonomic form of the explicit move — it advances whichever
bookmarks are closest behind `@`. It is still an explicit command; nothing advances on
its own.

### Pushing

```
jj git fetch                                  # fetch all from default remote
jj git push -b <bookmark>                     # push specific bookmark
jj git push --change @                        # push @ with an auto-generated bookmark
jj git push --change @-                       # same, for parent (common when @ is empty)
```

`jj git push` uses force-with-lease semantics by default. Safe in normal use.

### Before pushing

1. `jj log -r 'trunk()..@'` — confirm what's in the stack
2. `jj bookmark list` — confirm the bookmark points where intended
3. `jj diff --git -r <bookmark>` — review final content
4. `jj git push -b <bookmark>` — push only after Alyssa explicitly says so

**Never push unprompted.** Pushing is an Alyssa-only decision.

---

## Conflicts

jj allows committing with conflicts. A rebase doesn't halt mid-way; it completes, and
conflicted commits stay conflicted until resolved.

```
jj st                              # shows "There are unresolved conflicts" with paths
```

To resolve: edit the conflicted file directly. Conflict markers look like git's
`<<<<<<<` / `=======` / `>>>>>>>` blocks with extra context lines explaining each side.
Remove markers, save, then run `jj st` to confirm resolution. Do not use `jj resolve` —
it's interactive.

If conflicts arose from a rebase and Claude isn't sure which side wins, **stop and ask**.
Don't guess on conflict resolution.

---

## Recovery

jj's operation log makes most mistakes recoverable.

```
jj undo                  # undo the last jj operation (almost always what you want)
jj op log                # full operation history
jj op restore <op-id>    # restore to a specific operation
jj evolog -r <change>    # evolution of a specific change (all past versions)
```

**Reflex:** If something looks wrong after a jj command, run `jj undo` first. It's
non-destructive — it just adds another operation to the log. You can `jj undo` the
`jj undo` if needed.

`jj evolog` is useful when a commit was rewritten and you want to see what it looked
like before. Each past version is recoverable via `jj restore --from <evolog-commit-id>`.

---

## Quick Reference

| Action | Command |
| --- | --- |
| Status | `jj st` |
| Log (default) | `jj log` |
| Log (local stack) | `jj log -r 'trunk()..@'` |
| Diff (git format) | `jj diff --git` |
| Show commit | `jj show --git <change-id>` |
| New commit | `jj new -m "msg"` |
| New commit inserted | `jj new --no-edit --insert-before <id> -m "msg"` |
| Describe | `jj describe -m "msg"` |
| Squash to parent | `jj squash -m "msg"` |
| Squash specific path | `jj squash <path> --from <X> --into <Y>` |
| Absorb | `jj absorb` |
| Restore file from rev | `jj restore --from <X> --to <Y> <path>` |
| Untrack file | `jj file untrack <path>` (must be in `.gitignore` first) |
| Rebase | `jj rebase -s <src> -d <dest>` |
| Abandon | `jj abandon <change-id>` |
| Undo | `jj undo` |
| Op log | `jj op log` |
| Bookmark create | `jj bookmark create <name> -r @` |
| Bookmark move | `jj bookmark move <name> --to @` |
| Fetch | `jj git fetch` |
| Push bookmark | `jj git push -b <name>` |
| Push current change | `jj git push --change @` |

---

## Reference Files

Load these when the situation matches. Don't load them otherwise — they're separate to
keep this file under context budget.

- **`references/gitignore-recovery.md`** — Detailed walkthroughs of file-tracking
  recovery scenarios: file in `@` only, file in one local commit, file in many local
  commits, file in pushed commits, `snapshot.auto-track` configuration. Load when a
  Rule 2 or Rule 3 situation is more complex than the patterns above, or when Alyssa
  asks about the recovery patterns in detail.

- **`references/command-reference.md`** — Full git-to-jj command mapping table, plus
  less-common commands not in the Quick Reference above. Load when Claude needs to
  translate a specific git workflow Alyssa describes, or when she asks "how do I do
  <git operation> in jj?"

- **`references/version-notes.md`** — jj v0.44-specific behavior: flags removed since
  the tutorials were written (`--allow-new`, `describe --edit`), the
  `--destination`/`-d` → `--onto`/`-o` rename, current config-key names, and the
  migration notes that matter for muscle memory. Load when commands are erroring
  with unfamiliar messages, when an example from an older tutorial doesn't work, or
  when Alyssa asks about version specifics.

---

## Edge Cases

**Empty `@`.** If `@` is empty (no description, no changes), `jj new` creates a child of
`@` but doesn't abandon `@` automatically unless you move away. To clean up: just
`jj edit @-` and run another command — empty undescribed commits get abandoned when you
move away. (Note: this is configurable; behavior assumes default config.)

**Detached HEAD warnings from git.** Normal in colocated repos. jj keeps git's HEAD in
detached state and updates it as `@` moves. Ignore git's warnings about "detached HEAD";
they're not actionable in jj.

**"Commit is immutable" error.** Means you're trying to rewrite something in `trunk()`
or its ancestry (usually because it's been pushed). Do not pass `--ignore-immutable`
without explicit go-ahead from Alyssa. Surface the situation instead.

**"working copy stale" message.** Run `jj workspace update-stale`. If it asks about a
recovery commit, accept and verify with `jj log`.

**Multiple workspaces.** Alyssa occasionally uses `jj workspace add` to run parallel
Claude sessions against the same repo (see Slava Kurilyak's parallel Claude pattern).
Each workspace has its own `@`. Commands apply to the current workspace's `@` unless
specified otherwise.
