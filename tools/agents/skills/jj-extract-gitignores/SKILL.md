---
name: jj-extract-gitignores
description: >
  Extract `.gitignore` changes from buried commits in a jj chain back into named
  in-between commits that sit right after a target ancestor (default - the project's init
  commit). Use when the user says "extract gitignore changes", "split off the gitignores",
  "roll the gitignores back to <commit>", "retroactive gitignore remediation",
  "/jj-extract-gitignores", or wants to land later-committed `.gitignore` additions as
  logical ancestors of the work that uses them. Builds a sequential chain of named
  in-between commits — not siblings — because siblings conflict at squash time when
  they all append to the same end-of-file position. Each in-between commit holds
  exactly one original commit's `.gitignore` delta, preserving its hunk exactly. `@`
  does not move. Also covers a related variant for modifying a tracked path in an
  ancestor commit without `jj edit` (which would let auto-tracking pollute the
  ancestor) — uses `jj restore --from @ --to <new>` instead of squash, with a
  `jj restore --from 'root()'` fix for any delete/modify conflicts downstream.
  Pinned to jj v0.44.
allowed-tools: Bash(jj *), Bash(git log *), Bash(git status), Read, Edit
---

# jj-extract-gitignores

This skill rolls `.gitignore` changes back through a jj chain to land as logical
ancestors instead of staying mixed into feature commits. The result is a tidy chain
where every `.gitignore` addition lives in its own small, named commit positioned right
after the target ancestor.

## When this applies

Alyssa wants to retroactively organize `.gitignore` history when later commits added
ignores that should have been in place earlier. Common phrasing: "extract gitignore
changes", "split off the gitignores", "retroactive gitignore remediation", "roll the
gitignores back to pm". She does not want sibling commits — those conflict at squash
time. She wants in-between commits in the main chain.

## Inputs

- **Target ancestor** (optional, default = the project's init commit, often visible as
  `pm` or whatever the user names). If the user provides a short prefix like `pm`, run
  `jj log -r '<prefix>' --no-graph --limit 1` to confirm resolution.
- **Path filter** (optional, default `.gitignore`). The skill name says "gitignores" but
  the recipe generalizes to any path. If Alyssa points at a different path, use that.

## Preconditions to verify

1. The repo is a jj repo (`.jj/` exists). If not, abort and surface that this skill is
   jj-only.
2. The target is an ancestor of `@`. Check with
   `jj log -r '<target> & ::@' --no-graph --limit 1`. If empty, abort.
3. The target's commits and descendants are not pushed (no remote bookmark, or the
   bookmark sits behind the target). Check with `jj log -r '<target>::@ & remote_bookmarks()'`.
   If pushed, surface and stop — do not rewrite pushed history.
4. There are at least two distinct `.gitignore`-modifying commits in `<target>::@`
   excluding the target itself and `@`. With only zero or one extractable change, this
   skill's overhead isn't worth it — surface that and propose a simpler approach.

## Workflow

### Step 1: identify the extraction set

```
jj log -r 'files("<path>") & <target>::@' --no-graph
```

Capture the list. Order it oldest-first (jj log defaults to newest-first, so reverse
for processing). Exclude the target itself and any `@`-only-touches-`.gitignore` entry
that exists because of in-progress edits in the working copy. Show the list to Alyssa
before proceeding, with the hunk header for each (preview: `jj diff --git -r <id>
<path> | head -1` for each).

### Step 2: identify the main-chain child of the target

```
jj log -r 'children(<target>) & ::@' --no-graph --limit 1
```

This is the commit that the new in-between commits will be inserted before. Call it
`<main-child>`. All subsequent `jj new --insert-before` calls reference `<main-child>`
— jj naturally inserts each new commit between `<main-child>` and the most recent
in-between, building the chain in order.

### Step 3: extract, one commit at a time, oldest first

For each `<orig>` in the ordered list:

```
# Create an empty in-between commit right before <main-child>
jj new --no-edit --insert-before <main-child> -m "ignore <summary> (extracted from <orig-short-desc>)"
# Capture the new change ID from the "Created new commit <id>" line in jj's output

# Move the original commit's <path> delta into the new commit
jj squash <path> --from <orig> --into <new>
```

Verify after each iteration:

```
jj diff --git -r <new> -- <path>     # should show <orig>'s original hunk verbatim
jj diff --git -r <orig> -- <path>    # should be empty
jj log -r '<target>::<main-child>' --no-graph
```

If `jj squash` reports conflicts, stop and surface. Conflicts at this step indicate
that the intermediate commits between `<orig>` and the new commit's parent DO touch
`<path>` in a way that makes the deltas non-composable. That should be rare for
`.gitignore` (which is typically pure-append), but possible.

### Step 4: report

After processing all originals, show Alyssa:

1. The new chain shape: `jj log -r '<target>::<main-child>'` with descriptive
   commit messages.
2. Each new in-between's diff hunk (one per commit) for verification.
3. Confirmation that the originals have empty deltas for `<path>`.
4. A reminder that these in-between commits can be squashed into `<target>` later,
   but don't do that now unless Alyssa explicitly asks.

## Failure modes and what to do

- **`jj new --insert-before <main-child>` rebases conflicts.** Means descendants of
  `<main-child>` have unrelated unresolved conflicts. Surface them and ask before
  proceeding.
- **`jj squash` produces a conflict in the new commit.** The path-delta from `<orig>`
  doesn't apply cleanly to the new commit's parent. This usually means a commit between
  `<target>` and `<orig>` also touches `<path>` and wasn't in the extraction set. Re-run
  the extraction-set query and look for hidden modifiers. Don't try to force the
  conflict in place — undo with `jj undo` and replan.
- **Target was misidentified.** If the new chain looks weird or descendants get rebased
  through unexpected paths, run `jj op log` and `jj op restore <pre-extraction-op>` to
  revert. Then ask Alyssa to confirm the target.

## What this skill explicitly does NOT do

- Does not squash the in-between commits into the target. That's a separate later step,
  and Alyssa may want to review and selectively squash.
- Does not move `@`. Throughout, `@` stays on whatever working-copy commit Alyssa was
  on. Each `jj new --insert-before` and `jj squash --from/--into` leaves `@` alone.
  (jj will print "Rebased N descendant commits" — that's normal propagation, not `@`
  movement.)
- Does not create sibling commits off the target. Siblings conflict at squash time
  when multiple of them append to the same end-of-file position. The whole point of
  this skill is to avoid that failure mode. This is not a `.gitignore` quirk — it is
  true of any append-only file (changelogs, `SUMMARY.md`), and it applies to merges
  as much as to squashes. The general rule, the anchor-line workaround, and why that
  workaround only relocates the problem are in the jujutsu skill's
  `references/merge-surgery.md`.
- Does not retroactively untrack files that match the new ignores. The patterns become
  effective from the new in-between commit forward, but files already tracked in earlier
  commits stay tracked. If Alyssa wants to remove a file from history too, that's a
  separate follow-up using `jj restore --from <pre-file-commit> --to <each-tainted>
  <path>`.

## Example (verified 2026-05-22 in this repo)

Target `pm`, path `.gitignore`. Extraction set: `nkkvtnwn` (Flutter section),
`kqovyrmn` (Understand-Anything section). Main-chain child of pm: `nxozolsn`.

```
jj log -r 'files(".gitignore") & pm::@' --no-graph
# → kqovyrmn, nkkvtnwn (newest-first; process oldest-first)

# Iteration 1 (nkkvtnwn)
jj new --no-edit --insert-before nxozolsn -m "ignore Flutter/iOS/Android build artifacts + .env (extracted from feat(u1))"
# → Created new commit zmxwztwq
jj squash .gitignore --from nkkvtnwn --into zmxwztwq
# → Rebased 38 descendant commits, no conflicts

# Iteration 2 (kqovyrmn)
jj new --no-edit --insert-before nxozolsn -m "ignore .understand-anything/intermediate, tmp, diff-overlay (extracted from docs+understand)"
# → Created new commit zkworqxk (positioned between zmxwztwq and nxozolsn)
jj squash .gitignore --from kqovyrmn --into zkworqxk
# → Rebased 38 descendant commits, no conflicts
```

Result: `pm → zmxwztwq → zkworqxk → nxozolsn → ... → nkkvtnwn' (no gitignore delta) →
... → kqovyrmn' (no gitignore delta) → ... → @`. Hunks preserved verbatim
(`@@ -63,3 +63,32 @@` in `zmxwztwq`, `@@ -92,3 +92,8 @@` in `zkworqxk`).

## Related variant: modify a tracked path in an ancestor without moving `@`

Sometimes the goal isn't extraction but **modification**: Alyssa wants to change a
file that already exists in an ancestor commit (e.g. fix a bug in a script committed
in `ouk`), and the alternative — `jj edit <ancestor>` — would materialize the
ancestor's tree on disk and let auto-snapshot pollute it with whatever stray files
are sitting in the working directory.

The same in-between-commit shape works, with two adjustments: use `jj restore`
(content-level copy) instead of `jj squash` (diff move), and proactively resolve
the delete/modify conflict that arises if the path is deleted somewhere downstream.

### Pattern

```sh
# 1. Make the edit in @'s working copy (auto-snapshots into @ as an addition
#    if the path's been deleted between the ancestor and @, or as a
#    modification if it's still alive). The content is what matters.
$EDITOR <path>

# 2. Create an empty in-between commit right after the ancestor.
jj new --no-edit --insert-after <ancestor> -m "<change description>"
# → Created new commit <new>

# 3. Content-copy the modified file into <new>. NOT squash — squash treats
#    @'s "addition" as a diff that conflicts with the ancestor's existing
#    file; restore is content-level and just sets <new>'s version of the
#    path to @'s.
jj restore --from @ --to <new> <path>

# 4. If the path is deleted in any descendant of <ancestor> (e.g. a
#    self-destructing setup script), that delete commit now sees the
#    modified content and recorded its delete-diff against the original
#    content → delete/modify conflict cascades through all descendants.
#    Resolve by making the delete content-agnostic:
jj restore --from 'root()' --to <delete-commit> <path>
# → conflicts cleared in the entire descendant chain

# 5. Clean @'s spurious addition: remove the file from the working dir
#    so auto-snapshot stops capturing it.
rm <path>
jj st    # should report "The working copy has no changes."
```

### Why restore, not squash

`jj squash <path> --from @ --into <new>` moves the *diff* of `<path>` from `@` (and
its parent) into `<new>`. When `@`'s parent doesn't have the file (because some
intermediate commit deleted it), `@`'s diff is "+file with modified content" — an
addition. Applying that addition on top of `<new>`'s tree (which already has the
file via inheritance from `<ancestor>`) is a content conflict between two adds.

`jj restore --from X --to Y <path>` is content-level. It sets `Y`'s version of
`<path>` to `X`'s, regardless of how `X` got that content (addition, modification,
or unchanged from parent). The delta in `Y` becomes whatever it needs to be relative
to `Y`'s parent — typically a clean modification.

### The delete/modify cascade

When `<ancestor>` has the file at content `A`, downstream commit `<del>` deletes
it, and you insert `<new>` between `<ancestor>` and `<del>` with modified content
`B`: `<del>`'s recorded diff is "remove file with content `A`", but after rebase
it's looking at content `B`. jj records this as a delete/modify conflict in `<del>`
and propagates the conflict marker through every descendant.

`jj restore --from 'root()' --to <del> <path>` rewrites `<del>`'s tree to
explicitly have no file at `<path>`. The delete becomes path-level rather than
content-aware. All descendants inherit "no file" and the conflict cascade clears.

### Verified 2026-05-22 in `~/Experiments/project`

Target `ouk` (template foundation, has `.agents/skills/setup/scripts/init-gitignore.sh`).
Goal: add Global/ fallback to the script. Downstream `ywrummmo` (commit 2a) self-destructs
the skill directory.

```sh
# Edit the file in @'s working dir
$EDITOR .agents/skills/setup/scripts/init-gitignore.sh

# Insert + restore content
jj new --no-edit --insert-after ouk -m "init-gitignore.sh: fallback to Global/ subpath + case-insensitive resolve"
# → Created new commit xyqzrrzv
jj restore --from @ --to xyqzrrzv .agents/skills/setup/scripts/init-gitignore.sh
# → Rebased 45 descendant commits, conflicts in 34 (all descendants of ywrummmo)

# Resolve the self-destruct's delete/modify conflict
jj restore --from 'root()' --to ywrummmo .agents/skills/setup/scripts/init-gitignore.sh
# → Existing conflicts were resolved or abandoned from 34 commits.

# Clean @
rm -rf .agents/skills/setup
jj st    # → The working copy has no changes.
```

Result: `ouk → xyqzrrzv (modified script) → ywrummmo (file gone) → ... → @`.
`@` never moved. ouk's tree was unaffected (the change rides on xyqzrrzv, not on
ouk itself — if Alyssa wants to fold it in, that's a follow-up `jj squash --from
xyqzrrzv --into ouk`, which composes cleanly because xyqzrrzv's diff is a
modification, not an addition).
