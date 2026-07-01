# Gitignore Recovery Patterns

Detailed walkthroughs for file-tracking scenarios that exceed the rules in `SKILL.md`'s
"File Tracking and .gitignore" section. Load this when Claude needs to recover from a
non-trivial tracking situation.

## Contents

1. [Foundational facts](#foundational-facts) — why these patterns exist
2. [Scenario A](#scenario-a-file-in--only-the-easy-case): File in `@` only (the easy case)
3. [Scenario B](#scenario-b-file-in-one-local-commit-back): File in one local commit back
4. [Scenario C](#scenario-c-file-in-multiple-local-commits): File in multiple local commits
5. [Scenario D](#scenario-d-file-in-pushed-commits): File in pushed commits
6. [Scenario E](#scenario-e-directory-of-junk): Whole directory of junk artifacts
7. [snapshot.auto-track configuration](#snapshotauto-track-configuration)
8. [Verification checklist](#verification-checklist)

---

## Foundational facts

Three jj behaviors drive these patterns. Internalize them before doing recovery work.

**Fact 1.** `.gitignore` only prevents auto-tracking of files that aren't already tracked
in any visible commit. Adding a pattern to `.gitignore` does not retroactively untrack.

**Fact 2.** `jj file untrack <path>` requires `<path>` to be in `.gitignore` at the
moment the command runs. Otherwise the next auto-snapshot retracks. This is jj-vcs/jj
issue #5225, open as of jj v0.36.

**Fact 3.** Rebasing past a new ancestor commit does not strip already-tracked content
from the rebased commits. The rebase reapplies each commit's diff, and that diff still
adds the unwanted file.

Together, these mean recovery has two phases:
- Get `.gitignore` in place as an ancestor of every tainted commit
- Surgically remove the file from each tainted commit's content

---

## Scenario A: File in `@` only (the easy case)

The file just appeared in the working copy. No prior commits have it.

```
$ jj st
Working copy changes:
A foo.log
A src/main.rs       # legitimate
```

**Fix:**

```
echo 'foo.log' >> .gitignore
jj file untrack foo.log
jj st               # confirm foo.log is gone, src/main.rs remains
```

Done. The `.gitignore` change lands in `@`'s snapshot alongside whatever real work is
there.

**Variant — file should be untracked but kept on disk:** Same commands. `jj file untrack`
removes the file from jj's tracking but leaves it on disk in the working directory.

**Variant — file should be deleted entirely:** Add to `.gitignore`, then `rm foo.log`.
The deletion auto-snapshots.

---

## Scenario B: File in one local commit back

The file is in `@-` (or some other recent commit) but not in `@`. Not pushed.

```
$ jj log -r 'trunk()..@'
@  abcdefgh  feat: add login form
○  ijklmnop  feat: scaffold auth     # foo.log got tracked here
○  trunk

$ jj log -p -r ijklmnop -- foo.log
○ ijklmnop  feat: scaffold auth
   + foo.log     (the unwanted file)
```

**Fix (three phases):**

```
# Phase 1 — put .gitignore in place as an ancestor of ijklmnop
echo 'foo.log' >> .gitignore       # auto-snapshots into @
jj new --no-edit --insert-before ijklmnop -m "ignore foo.log"
# Output prints the new change ID, e.g. wxyzabcd

jj squash .gitignore --from @ --into wxyzabcd
# @ no longer has the .gitignore change; wxyzabcd has it

# Phase 2 — remove foo.log from ijklmnop's content
jj restore --from wxyzabcd --to ijklmnop foo.log
# Restores foo.log's state in wxyzabcd (it doesn't exist there) into ijklmnop
# ijklmnop no longer contains foo.log

# Phase 3 — verify
jj log -p -r 'trunk()..@' -- foo.log    # should be empty
jj st                                    # @ should be unchanged
```

**Why this works:**
- `jj new --no-edit --insert-before` creates a new commit at the position you want
  without making it the working copy. Descendants rebase through it automatically.
- `jj squash <path> --from @ --into <new>` moves just the `.gitignore` change out of
  `@` into the new ancestor. `@` stays put.
- `jj restore --from X --to Y <path>` copies `<path>`'s state in `X` into `Y`. Since
  `<path>` doesn't exist in the new ancestor, restoring it into `ijklmnop` removes it.

---

## Scenario C: File in multiple local commits

The file appeared in `@---` and has carried forward through the stack. Not pushed.

```
$ jj log -r 'trunk()..@'
@   aaaa1111  feat: add tests
○   bbbb2222  feat: integration logic
○   cccc3333  feat: scaffold api      # foo.log first appeared here
○   trunk
```

**Fix:**

```
# Phase 1 — same as Scenario B
echo 'foo.log' >> .gitignore
jj new --no-edit --insert-before cccc3333 -m "ignore foo.log"
# Note new change ID: wxyzabcd

jj squash .gitignore --from @ --into wxyzabcd

# Phase 2 — remove foo.log from each tainted commit
# Option 1: loop (works for any number of commits)
for cmt in $(jj log -r 'wxyzabcd::@ ~ wxyzabcd' --no-graph --template 'change_id ++ "\n"'); do
  jj restore --from wxyzabcd --to "$cmt" foo.log
done

# Option 2: explicit, when there are only a few
jj restore --from wxyzabcd --to cccc3333 foo.log
jj restore --from wxyzabcd --to bbbb2222 foo.log
jj restore --from wxyzabcd --to aaaa1111 foo.log

# Phase 3 — verify
jj log -p -r 'trunk()..@' -- foo.log    # empty
```

**Note on the revset:** `wxyzabcd::@ ~ wxyzabcd` means "all descendants of wxyzabcd
inclusive, except wxyzabcd itself" — i.e., the tainted commits.

**Note on running the loop:** The loop uses `jj log --no-graph --template 'change_id'`
to produce a clean list of change IDs. Don't use plain `jj log` for this — its default
output has graph characters that will break the loop.

---

## Scenario D: File in pushed commits

The tainted commit is in `trunk()` or has been pushed to a remote.

```
$ jj log -r 'trunk()..@'
@  aaaa1111  feat: latest work
◆  cccc3333  feat: scaffold api  main@origin    # foo.log here, already pushed
○  trunk
```

**Do not unilaterally rewrite.** Force-pushing rewritten history past `trunk()` requires
coordinating with anyone who has pulled from the remote. This is a workflow decision,
not a tooling one.

**Surface the situation. Verbatim template Claude can adapt:**

> `foo.log` was tracked in change `cccc3333` ("feat: scaffold api"), which is at
> `main@origin`. Two options:
>
> 1. **Stop tracking going forward.** Add `foo.log` to `.gitignore` in a new commit on
>    top, then `jj file untrack foo.log` in that commit. The file remains in history
>    but doesn't accumulate further. No force-push, no coordination needed.
>
> 2. **Rewrite history.** Apply the Scenario C pattern, then `jj git push --force-with-lease`.
>    Anyone with a local copy of this branch will need to re-fetch and reset. Coordinate
>    first.
>
> Option 1 is the default. Option 2 only if the file contains secrets (credentials,
> tokens, keys) or otherwise must be removed from history. Which?

Wait for Alyssa's decision.

### Option 1 walkthrough (preserve history)

```
# Create a new commit on top of the stack with the ignore
jj new -m "ignore foo.log"
echo 'foo.log' >> .gitignore
jj file untrack foo.log

# Push when ready
jj bookmark move main --to @
jj git push -b main
```

### Option 2 walkthrough (rewrite history — only with explicit go-ahead)

```
# Run Scenario C pattern as written.
# Then bypass the immutability check to push:
jj git push --force-with-lease -b main
```

If jj refuses the rebase with "commit is immutable," it means the bookmark/remote
configuration has the affected commits in the immutable set. The override is
`--ignore-immutable` — but only with Alyssa's explicit OK on that specific operation.

---

## Scenario E: Directory of junk

Sometimes it's not one file — it's `node_modules/` or `target/` getting tracked
wholesale.

The pattern is identical to Scenarios A–C; just operate on the directory:

```
# In Phase 1, ignore the directory
echo 'node_modules/' >> .gitignore

# In Phase 2, untrack/restore the directory path
jj file untrack node_modules/                          # for @
jj restore --from <ignore-cmt> --to <tainted> node_modules/   # for earlier commits
```

`jj file untrack` and `jj restore` both accept directory paths and operate recursively.

**Warning on large directories:** If `node_modules/` has thousands of files, the squash
and restore operations are cheap (they're metadata operations, not file content), but
the subsequent working-copy materialization may need to write/delete many files. Expect
the first `jj st` after the cleanup to be slow.

---

## snapshot.auto-track configuration

If the same kind of cleanup keeps happening, the structural fix is to narrow what jj
snapshots automatically. By default jj snapshots all non-`.gitignore`'d files. The
`snapshot.auto-track` setting changes that to "only files matching this fileset."

```
# In .jj/repo/config.toml:
[snapshot]
auto-track = 'glob:"**/*.{rs,toml,md}"'

# Or via the CLI:
jj config set --repo snapshot.auto-track 'glob:"**/*.{rs,toml,md,dart,js,ts,json,yml,yaml}"'
```

**What this does:** Files matching the pattern auto-track normally. Files NOT matching
the pattern are visible (untracked) until explicitly added via `jj file track <path>`.
This is the opposite default from git: track-by-allowlist instead of track-everything.

**When to suggest this:**
- The repo has lots of generated artifacts that recur
- Alyssa is running parallel Claude sessions that generate lots of throwaway files
- The team has standardized on a specific set of file extensions

**Tradeoff:** New legitimate file types now need explicit `jj file track`. This is a
small friction but a hard guard against accidental tracking.

The fileset language is documented at the [filesets reference](https://docs.jj-vcs.dev/latest/filesets/).
Globs use `glob:"<pattern>"`. Multiple patterns combine with `|`. Negation with `~`.

---

## Verification checklist

After any recovery operation, run all of these:

```
# 1. The file shouldn't appear in any commit's diff
jj log -p -r 'trunk()..@' -- <path>     # expect empty

# 2. Working copy should be clean (or have only what you expect)
jj st

# 3. The file should be in .gitignore, in the correct ancestor commit
jj log -p -r 'trunk()..@' -- .gitignore

# 4. If colocated, the git side should agree
git log --all -- <path>                 # expect to NOT see new commits adding <path>

# 5. The op log should show your recovery operations (for undo if needed)
jj op log -n 10
```

If something looks wrong: `jj undo` repeatedly until back to a safe state. The op log
makes recovery reversible.
