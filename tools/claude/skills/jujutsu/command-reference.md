# Command Reference

Full git-to-jj command mapping plus less-common jj commands. Load when translating a
specific git workflow Alyssa describes, or when she asks "how do I do <git operation>
in jj?"

## Contents

1. [Status and inspection](#status-and-inspection)
2. [Making commits](#making-commits)
3. [Branching / bookmarks](#branching--bookmarks)
4. [Editing history](#editing-history)
5. [Restoring and undoing](#restoring-and-undoing)
6. [Remote operations](#remote-operations)
7. [Merging and rebasing](#merging-and-rebasing)
8. [Stashing equivalent](#stashing-equivalent)
9. [Less-common operations](#less-common-operations)

---

## Status and inspection

| Git | jj |
| --- | --- |
| `git status` | `jj st` |
| `git log` | `jj log` |
| `git log --oneline` | `jj log -T 'change_id.short() ++ " " ++ description.first_line()'` |
| `git log -p` | `jj log -p` |
| `git log <branch>..HEAD` | `jj log -r '<branch>..@'` |
| `git show <commit>` | `jj show --git <change-id>` |
| `git diff` | `jj diff --git` |
| `git diff <commit>` | `jj diff --git -r <change-id>` |
| `git diff <a> <b>` | `jj diff --git --from <a> --to <b>` |
| `git blame <file>` | `jj file annotate <file>` |
| `git ls-files` | `jj file list` |

**Always pass `--git` to `jj diff` and `jj show`** to get standard unified diff format
instead of jj's side-by-side default.

---

## Making commits

There is no staging area in jj. There is no `jj add`. Files in the working directory
are auto-snapshotted into `@` on every command.

| Git | jj |
| --- | --- |
| `git add <file>` | (not needed — auto-snapshot) |
| `git add -p` | `jj split <path>...` with fileset (or use squash patterns) |
| `git commit -m "msg"` | `jj commit -m "msg"` (commits `@`, creates new `@`) |
| `git commit --amend` | `jj describe -m "msg"` (changes message) OR `jj squash` (changes content) |
| `git commit --amend -a` | edit working copy, then `jj squash` to fold into `@-` |
| Two-step describe-then-code | `jj new -m "msg"` then edit files |

**`jj commit` vs `jj describe`:** `commit` finalizes `@`'s content and creates a fresh
empty `@` on top. `describe` just sets the message on `@` without moving forward. Use
`describe` when describing-first.

---

## Branching / bookmarks

| Git | jj |
| --- | --- |
| `git branch foo` | `jj bookmark create foo -r @` |
| `git branch foo <ref>` | `jj bookmark create foo -r <change-id>` |
| `git checkout foo` | `jj edit foo` (if foo is a bookmark, jumps to its commit) |
| `git checkout -b foo` | `jj new` + `jj bookmark create foo -r @` |
| `git branch -d foo` | `jj bookmark delete foo` |
| `git branch -m foo bar` | `jj bookmark rename foo bar` |
| `git branch --list` | `jj bookmark list` |
| `git branch --set-upstream` | `jj bookmark track foo@<remote>` |

**Key conceptual difference:** Bookmarks don't auto-advance. Creating a commit on top of
a bookmark leaves the bookmark behind. Move it explicitly with `jj bookmark move foo --to @`
before pushing.

---

## Editing history

This is where jj is dramatically better than git. Most history edits don't need an
interactive rebase.

| Git | jj |
| --- | --- |
| `git rebase -i HEAD~5` to reword | `jj describe -r <change-id> -m "new msg"` |
| `git rebase -i HEAD~5` to squash | `jj squash --from <X> --into <Y>` |
| `git rebase -i HEAD~5` to drop | `jj abandon <change-id>` |
| `git rebase -i HEAD~5` to split | `jj split <path>...` (non-interactive when given paths) |
| `git rebase -i HEAD~5` to reorder | `jj rebase -r <change> --before <other>` |
| `git cherry-pick <commit>` | `jj rebase -r <change-id> -d @` OR `jj duplicate <change-id> --onto @` |
| `git revert <commit>` | `jj revert <change-id>` (creates a new commit that undoes it) |

### Inserting a commit mid-chain

```
# Insert AT a position, switch to it
jj new --insert-before <change-id> -m "msg"
jj new --insert-after  <change-id> -m "msg"

# Insert without switching @ — combine with --no-edit
jj new --no-edit --insert-before <change-id> -m "msg"
jj new --no-edit --insert-after  <change-id> -m "msg"
```

### Moving file changes between commits

```
# Move whole commit's changes into another commit
jj squash --from <X> --into <Y>

# Move only specific paths
jj squash <path>... --from <X> --into <Y>

# Pull changes to a path from a range of commits into one commit
jj squash <path> --from <X>::<Y> --into <target>

# Automatic absorption based on blame (less precise, faster)
jj absorb
jj absorb -r <change-id>
```

---

## Restoring and undoing

| Git | jj |
| --- | --- |
| `git restore <file>` | `jj restore <file>` (restore from `@-` into `@`) |
| `git restore --source=<commit> <file>` | `jj restore --from <change-id> <file>` |
| `git checkout <commit> -- <file>` | `jj restore --from <change-id> <file>` |
| (no equivalent — would need rebase) | `jj restore --from <X> --to <Y> <file>` (cross-commit restore without switching `@`) |
| `git reset HEAD~` (keep changes) | `jj abandon @` (and `jj new` from the parent) |
| `git reset --hard HEAD~` | `jj abandon @` (no need to discard — `@`'s changes are abandoned) |
| `git reflog` | `jj op log` |
| `git reflog show <branch>` | `jj evolog -r <change-id>` (per-change history) |

### The undo reflex

```
jj undo                  # undo the last operation; safe and reversible
jj op log                # see all operations
jj op restore <op-id>    # jump to any prior state
```

`jj undo` is non-destructive. It creates a new operation that inverts the last one. You
can `jj undo` the `jj undo` if needed. **Reach for `jj undo` first** whenever something
looks wrong.

---

## Remote operations

All git-side network operations are namespaced under `jj git ...`.

| Git | jj |
| --- | --- |
| `git clone <url>` | `jj git clone <url>` |
| `git clone <url> --colocate` (n/a in git) | `jj git clone <url> --colocate` |
| `git init` + `git remote add` | `jj git init --colocate` (in existing git repo) |
| `git fetch` | `jj git fetch` |
| `git fetch <remote>` | `jj git fetch --remote <name>` |
| `git pull` | `jj git fetch` + `jj rebase -d <bookmark>@<remote>` |
| `git push <branch>` | `jj git push -b <bookmark>` |
| `git push --force-with-lease` | `jj git push` (default behavior) |
| `git push -u origin foo` | `jj git push -b foo` (auto-tracks) |
| Push current state with auto-bookmark | `jj git push --change @` or `jj git push --change @-` |

`jj git push` is `--force-with-lease`-safe by default. It will refuse to overwrite a
remote bookmark that has moved since the last fetch.

---

## Merging and rebasing

| Git | jj |
| --- | --- |
| `git merge <branch>` | `jj new <change-of-branch-A> <change-of-branch-B>` (creates a merge commit) |
| `git rebase <upstream>` | `jj rebase -d <upstream>` |
| `git rebase --onto <new-base> <upstream> <branch>` | `jj rebase -s <branch> -d <new-base>` |
| `git rebase --abort` | `jj undo` (or `jj op restore`) |
| `git rebase --continue` | (not needed — jj completes rebase even with conflicts) |

**Conflict behavior:** jj rebases complete even when conflicts arise. The conflicted
commits are marked but the rebase finishes. Resolve at your own pace by editing the
conflicted files directly. No `--abort` / `--continue` dance.

---

## Stashing equivalent

There is no `jj stash`. The model is different: every state is already a commit, so
"setting aside work" is just leaving `@` and creating a new one.

| Git | jj |
| --- | --- |
| `git stash` | `jj new <somewhere-else>` (the old `@` stays as a sibling commit) |
| `git stash pop` | `jj edit <old-change-id>` (resume the previous `@`) |
| `git stash list` | `jj log -r 'heads(::)'` (all leaf commits — includes set-aside work) |

Set-aside commits get descriptive names if you `jj describe -m "wip: ..."` before leaving
them. They're not lost; they're just other commits.

---

## Less-common operations

### Workspaces (parallel working copies)

```
jj workspace add ../path/to/new-workspace          # create a new workspace
jj workspace list                                   # list workspaces
jj workspace forget <name>                          # forget a workspace
jj workspace update-stale                           # fix "working copy stale" errors
```

Each workspace has its own `@`. Useful for running parallel Claude sessions or for
keeping a long-running task isolated from active work.

### Operation log

```
jj op log                       # full history of operations
jj op log -n 20                 # last 20
jj op restore <op-id>           # restore repo to a prior op
jj op undo                      # undo the last op (alias for jj undo)
jj --at-op <op-id> log          # see what log looked like at a prior op
```

### Evolution log (per-change history)

```
jj evolog -r <change-id>        # all past versions of a single change
jj evolog -p -r <change-id>     # with patches
```

Useful when a commit was amended/squashed and you want to see what it looked like
before.

### Config

```
jj config list                              # all config
jj config get <key>                         # one value
jj config set --user <key> <value>          # user-level (in ~/.config/jj/config.toml)
jj config set --repo <key> <value>          # repo-level (in .jj/repo/config.toml)
jj config path --user                       # show user config file path
jj config edit --user                       # open user config in editor
```

### Templates and revsets

Templates customize output formatting. Revsets select commits.

```
jj log -T '<template-string>'                       # custom log format
jj log -r '<revset-expression>'                     # custom selection

# Common revset functions:
jj log -r 'trunk()..@'                              # local stack
jj log -r 'mine() & ~immutable()'                   # my mutable commits
jj log -r 'heads(::)'                               # all leaf commits
jj log -r 'bookmarks()'                             # commits with bookmarks
jj log -r 'conflicts()'                             # commits with conflicts
jj log -r 'description("regex")'                    # commits matching message
jj log -r 'author("alyssa")'                        # by author
```

Templates and revsets are functional languages. Full reference at
[the jj docs](https://docs.jj-vcs.dev/latest/).
