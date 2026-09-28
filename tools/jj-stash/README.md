# jj-stash

Park commit chains out of every jj UI, then bring them back unchanged.

A prototype, as a shell script over jj and git, of something jj does not have: a
way to take a chain of commits out of the visible graph without losing it. The
use case is a repo with a wide fan-out of open threads, viewed in a UI that
cannot filter by revset. VisualJJ 0.35.3 has no revset setting at all, so
`revsets.log` and aliases do not reach it. The only way to shrink its graph is to
make commits invisible to jj itself.

```
jj-stash push NAME 'REVSET'        park a chain; children outside it are detached
jj-stash list                      parked chains, with what each needs popped first
jj-stash index                     rewrite .claude/stashes/INDEX.md now
jj-stash show NAME                 the plaintext, under a live needs / needed-by header
jj-stash pop [--with-deps] NAME    bring the chain back and drop the stash
jj-stash drop NAME                 forget the stash without bringing it back
```

## How a chain is parked

Two things are written, then the chain is abandoned:

- **`.claude/stashes/NAME.md`, plaintext for reading.** It records what the chain
  sits on, its bookmarks, then every commit oldest first, each with its change
  ID, commit ID, parents, author, full description and `--git` diff. It exists
  so the chain can be read before deciding whether and when to bring it back.
  It doubles as a fallback patch. It lives in the main repo's root, whichever
  workspace `push` runs from, and must be ignored or jj would snapshot it into
  `@`. `.claude/stashes/` always goes in `.git/info/exclude`, even when a
  committed `.gitignore` covers it too. jj reads ignore rules from the files on
  disk, so checking out a commit older than that `.gitignore` rule would
  snapshot every stash file into it, and moving off that commit would delete
  them from disk. The exclude file is local and holds whichever commit is
  checked out.
- **`refs/jj-stash/NAME/{root-N,head-N,bookmark/<name>,reattach/<change>/N}`,
  git refs.** These keep
  the commits alive. jj imports only `refs/heads`, `refs/tags` and
  `refs/remotes`, so these refs do not make anything visible, but git's gc
  treats them as roots and never prunes the objects. The namespace is not
  `refs/stash/`: `git stash` keeps its own data in the single ref
  `refs/stash`, and git cannot hold both `refs/stash` and `refs/stash/…`, so
  in a colocated repo one of the two tools would break.

A child outside the chain is **detached, not stranded**. The typical case is a
merge that collects several lanes. The child is rebased onto its other
parents, and a `reattach/<child change ID>/N` ref records which chain commits
were its parents. `pop` adds them back. A child with no parent outside the
chain has nowhere to go, so `push` refuses and names it.

`push` is all or nothing. It records the operation it started from, and any
failure before the final abandon restores that operation and removes the refs
and plaintext it wrote.

`jj abandon` then removes the chain from the view. It is gone from `jj log`,
VisualJJ and jjk.

## Why pop restores the same commits, not a replay

jj writes a `change-id` header into every git commit it creates:

```
tree bd3489b…
parent 3c61b3b…
author …
committer …
change-id qqrsypwrlqxqstzkuztmtzuwoopqussy
```

So the parked git objects *are* the jj commits. `pop` never re-applies
anything. It makes the original commits visible again, so change IDs, commit
IDs and timestamps all survive, and an export/replay step is unnecessary.

`pop`, in order:

1. **Record parents.** Before anything is revived, record the current version
   of every parent the chain's roots sat on. Reviving brings old versions back
   too, which would make `change_id()` ambiguous.
2. **Revive.** A bookmark on a hidden commit makes it and its ancestors visible
   again, and they stay visible after the bookmark is deleted. So each head
   gets a temporary bookmark, which is then deleted.
3. **Rebase if needed.** If a parent was rewritten while the chain was parked,
   `jj rebase -s ROOT -o CURRENT_PARENT…`. Descendants follow. Rebasing a
   hidden root directly, without step 2, revives only the root, not its
   descendants.
4. **Clean up.** Step 2 also revived the *old* version of any rewritten parent.
   Once the chain has moved off it, that copy has no children and duplicates a
   live change, so it is abandoned. Nothing else is touched.
5. **Restore bookmarks** by change ID, so they follow a rebase. Only local,
   non-conflicted bookmarks are recorded. A remote that is tracked but was
   never pushed is listed as `name@origin` with no target, and is skipped.
6. **Reattach** each detached child: its current parents, then the chain
   commits it lost, in that order.
7. **Delete the refs and the plaintext.**

`push` refuses a revset that would leave a child with no parent, one that
contains any workspace's working-copy commit, and one that contains immutable
commits.

## Dependencies between stashes

`pop` only knows each root's *direct* parent. Stash a dangling commit, then
the chain it dangles from, and the two now depend on each other in one
direction. Popping them in the wrong order is where it goes wrong:

- **Nothing rewritten in between:** reviving the dangling commit makes its
  ancestors visible, so its parent comes back as an ancestor while the other
  stash still claims it. That leaks into view. Edit the leaked commit, and
  popping the chain later revives the old version beside the edit: divergence.
- **An ancestor rewritten while both are parked:** the first pop revives the old
  ancestor and it diverges at once. The second pop happens to repair it, but
  the state in between is wrong.

So a stash **depends** on another when one of its roots sits on a commit that is
hidden and parked there, or when a child it detached (`reattach/`) is hidden
and parked there. Membership is jj's `roots::heads` for each stash, computed
with `git rev-list --ancestry-path`. That leaves out the ancestors of a merge's
outside parent, which a plain `rev-list heads ^parents` would wrongly include.
Everything is keyed by change ID, so it holds across rewrites.

- `pop NAME` refuses while NAME depends on another stash, names it, and
  changes nothing.
- `pop --with-deps NAME` pops the dependencies first, recursively, then NAME. A
  cycle is refused.
- `push` prints a note for every existing stash that now depends on the new
  one.
- `list` shows a `needs:` column.

Dependencies are never written into a stash's own file. They change whenever
another stash is parked or popped, so text fixed at park time goes stale the
first time anything else moves. They are shown where they are worked out
fresh:

- **`show NAME`** prints `> needs:` and `> needed by:` above the file,
  computed at that moment.
- **`.claude/stashes/INDEX.md`** is rewritten after every `push` and `pop`,
  which are the only things that change what is parked. It has one row per
  stash: a link to its file, commit count, when it was parked, what it sits on,
  and what it needs. It is ignored along with the rest of the directory, and
  `INDEX` is refused as a stash name. `jj-stash index` rewrites it on demand.

Two alternatives were considered and not built. Restoring onto the *nearest
visible ancestor* is easy to find but amounts to `jj abandon` of the missing
link: the revision's diff conflicts wherever it depends on what the skipped
commits introduced. Parking a *partial graph* (a middle commit with its
descendants left visible) is impossible without rewriting those descendants,
because a commit's parents are part of its identity. They would show as
conflicted while parked. Parking related pieces as one stash, a union in one
revset, avoids both.

## Dropping a stash

`drop NAME` forgets a stash without restoring it: it deletes the refs and the
plaintext and rewrites the index. The commits stay abandoned.

Deleting `NAME.md` by hand is not enough. The refs are the stash; `list`, `pop`
and `index` find stashes by them, so the stash stays, with blank columns.
Deleting the refs by hand is worse when another stash depends on this one. That
stash no longer shows the dependency, so its `pop` goes ahead, and reviving its
head makes every ancestor visible: the dropped commits come back with it. So
`drop` refuses while another stash's roots sit on commits in NAME, names them,
and changes nothing. Drop or pop those first.

The other kind of dependency does not block a drop. A stash that was detached
from a commit in NAME, typically a lane cut out of a merge that NAME holds,
only loses the chance to rejoin it: its `pop` skips a child that no longer
exists, says so, and brings back nothing of NAME. `drop` goes ahead and lists
those stashes in a note.

Without the refs, only jj's operation log keeps the commits from git gc. `drop`
prints `jj new <head>` for each head, which brings the chain back until
`jj util gc` expires it.

## Tested

Run against a copy of a real repo (jj 0.45.1, colocated, 131 mutable commits,
three workspaces):

| case | result |
|---|---|
| revset that would leave a child with no parent | refused, naming the child |
| a two-commit lane whose tip is one of 25 parents of a merge (real case: an issue lane under a "merge: issue lanes for review" commit) | lane hidden; merge kept with 24 parents; pop restores identical lane IDs, the merge's 25th parent and the `issue/134` bookmark |
| failure injected after the merge was detached, before abandon | op restored: merge back to 25 parents, no refs or plaintext left |
| push, then pop, parents unchanged | identical change IDs **and** commit IDs; bookmark restored; no refs or plaintext left |
| a parent rewritten while parked | root rebased onto the new version; stale copy abandoned; no divergent commits; thread count unchanged |
| `jj util gc --expire now` then `git gc --prune=now`, while parked | objects survive; pop works |
| push from a secondary workspace nested under `.claude/worktrees/`, pop from the main one | plaintext lands in the main root, is ignored, and the main `@` is not snapshotted |
| second push | does not re-append the exclude rule |
| `show` on a real dependent pair | `pr-88`: needs `docs-readme`, needed by nothing; `docs-readme`: needs nothing, needed by `pr-88`; unknown name fails cleanly |
| `index` over 28 real stashes | one row each; the dependent row carries its commit count, the commit it sits on and `docs-readme`; independent rows have an empty needs cell |
| `push` / `pop` / `pop --with-deps` | the index gains and loses rows to match; afterwards no row needs anything; a stash named `INDEX` is refused |
| checking out a commit older than the `.gitignore` rule, then back | stash files stay ignored through `.git/info/exclude`, nothing is snapshotted into `@`, every file is still on disk afterwards |
| dangling commit parked, then the 16-commit chain it sits on | push of the chain notes the dependency; `pop` of the dangling one is refused and changes nothing; the right order restores identical IDs |
| same, `pop --with-deps` on the dangling one | pops the chain, then it; identical IDs; no refs left |
| a lane that feeds a merge parked, then the merge's line | popping the lane first is refused (its reattach target is parked); `--with-deps` restores the line, then the merge gets the lane back as a parent |
| real stashes, parked by hand in the wrong order (a PR lane, then the readme lane it sits on) | found by `list`; `pop` refused; `--with-deps` restores both, PR back on the readme commit |
| an independent stash | pops without `--with-deps`; no false dependency across 27 real stashes |
| `drop` of an independent stash | refs, plaintext, index row and `list` line gone; commit hidden but still in the store; the printed `jj new` brings it back |
| `drop` of a stash another sits on (`docs-readme`, needed by `pr-88`) | refused, naming `pr-88`; nothing changed. Dropping `pr-88` first, then `docs-readme`, works |
| `drop` with an unknown name, no name, or an extra argument | fails; nothing changed |
| `drop` of the stash holding a review merge that 18 parked issue lanes were detached from | not refused; a note lists all 18; a lane then pops without `--with-deps`, says the merge was not reattached, and the merge stays hidden |

## Limits

- **bash 4 or later.** `pop` uses an associative array. macOS's `/bin/bash`
  is 3.2.
- **Local only.** `jj git push` does not push `refs/jj-stash/*`, so a stash exists
  in one repo. Back up `.claude/stashes/` if it matters.
- **Pushed bookmarks are not handled.** A remote bookmark (`name@origin`) keeps
  its commit visible, so a chain carrying one cannot be hidden this way.
  `abandon` also deletes the local bookmark, and a later `jj git push --deleted`
  would push that deletion. Only local bookmarks were tested.
- **Parent order of a reattached merge** is not preserved: the chain's
  commits are appended after the child's current parents.
- **Merges inside the chain.** Only the roots' parents are re-targeted. If a
  merge commit inside the chain has a parent outside it, and that parent is
  rewritten while parked, the old version of that parent comes back.
- **Conflicted bookmarks** (more than one target) are not recorded.
- **Dependency cycles** are refused, but no real cycle was found to test it.
  Chains deeper than one level (A needs B needs C) are handled by the same
  recursion but were not tested directly.

## Found by testing

- `jj bookmark list -r` also returns remote-tracking entries. An unpushed
  tracked remote has no target, and the first version passed that non-commit
  to `git update-ref`.
- `git for-each-ref 'bookmark/*'` matches one path component, so `issue/134`
  was parked but not restored. A glob-free prefix fixed it.
- An ignore check run relative to a secondary workspace under
  `.claude/worktrees/` matched that directory's own ignore rule. The plaintext
  then went unignored and jj snapshotted it.
- Under `set -e` and `pipefail`, a dependency check whose last test came out
  false returned non-zero and would have aborted the script from inside
  `$(...)`.
- The stash files were protected only by the committed `.gitignore`. A test
  copy of the repo built without its working tree had no `.gitignore` on disk,
  so jj snapshotted all 28 stash files into `@`, and moving `@` deleted them.
  The real repo was unaffected, but any checkout older than the rule would
  have done the same there. `.git/info/exclude` now always carries it.
- `list` took 38 seconds over 27 stashes: the ownership map was built inside
  a `$(...)` subshell, thrown away, and rebuilt per stash. It is now built
  once in the main shell, which the subshells inherit (2.3 seconds).

## If this became `jj stash`

The primitives are all in jj already. Hidden commits stay addressable by
commit ID, a bookmark revives them, and the view's heads decide visibility. A
native version would presumably keep parked heads in the view or op store
rather than in git refs, which would also make it work with non-git backends,
and could show them with a revset like `stashed()`.
