# Version stacks: micro chains with squashed siblings

Alyssa's workflow for versioned work, as of 2026-10-04. **Experimental**: she is
not sure it will last, so follow it when she is working this way, and don't build
tooling that assumes it without asking. Verified on jj 0.45.1 while rebuilding
0.1.1 to 0.1.5 of the dotfiles repo.

## The shape

Each version exists twice, side by side, on the previous version's squashed
commit:

```text
Q5  version(0.1.5) ─┬─ 0.1.5 micro chain → tip5
Q4  version(0.1.4) ─┼─ 0.1.4 micro chain → tip4
Q3  version(0.1.3) ─┼─ 0.1.3 micro chain → tip3
S2  effver | version(0.1.2) (#204)        ← GitHub's squash of the merged PR
```

- **Micro chain**: the small commits of one version, in lanes that may fan out
  and octopus-merge. Detail scale.
- **Squashed sibling**: one commit with exactly the chain tip's tree, described
  `version(0.1.N): ...`. Version scale.
- Each PR is `v0.1.N` into `effver` (or stacked onto the previous `v0.1.x`), and
  GitHub squash-merges it. After a merge, that version's micro commits go away
  and the next chain sits directly on GitHub's squash.

Keeping both forms local, on the same base, keeps them next to each other in
VisualJJ and lets Alyssa compare versions at either scale.

## Make a version's squashed sibling

```text
jj new --no-edit <base> -m "version(0.1.N): summary"   # base: previous squashed (or effver)
jj restore --from <chain-tip> --into <new>
jj diff --from <chain-tip> --to <new> --stat            # empty = identical
```

If the chain changes later, re-run the `restore` and the `diff`. A squashed
sibling that no longer matches its chain is the main way this drifts.

## Start the next version

Root version N+1's chain on version N's **squashed** commit, not on its chain
tip. Every chain is then one level deep, and when GitHub squash-merges N, its
commit has the same tree as the local squashed one (unless suggestions were
applied on GitHub), so moving N+1 onto it is conflict-free.

## After a PR is squash-merged

1. Fetch only what is needed: `jj git fetch --remote origin -b effver -b v0.1.N+1`.
2. Find version N+1's own commits: those in the pushed branch and not in the
   version below it. A version often branched **before** the previous version's
   review commit, so check the roots and their parents:

   ```text
   S='(::v0.1.N+1@origin ~ ::<pushed tip of the version below>)'
   jj log -r "roots($S)" -T 'change_id.short(4) ++ " <- " ++ parents.map(|p| p.change_id().short(4)).join(",") ++ "\n"'
   ```

   **Shortcut when GitHub changed nothing.** If the squash's tree equals the
   pushed tip of version N (`jj diff --from <tip> --to effver --stat` is
   empty), the local commits above that tip are not conflicted and need no
   copying. Rebase them, keeping change IDs, bookmarks and side lanes:

   ```text
   jj rebase -s 'children(<pushed tip of N>)' -o effver
   ```

   A merge in the moved set would get `effver` as its only parent, so give
   it the others again: `jj rebase -s <merge> -o effver -o <other parent>`.
   Then point `effort/v0.1.N` at the squash (`jj bookmark set effort/v0.1.N
   -r effver --allow-backwards`), move what hangs off the stale local
   squashed siblings of N the same way, and abandon those siblings once
   `children(<sibling>)` is empty. Steps 3 and 4 are for review commits
   that came through the squash. Done this way for 0.1.5 on 2026-10-06:
   67 commits moved, no new conflicts.

3. Put them on the new base. `jj duplicate` from the **pushed** commits is the
   reliable path; local copies may already be conflicted:

   ```text
   jj duplicate "$S" -o effver
   ```

   Parents outside the set become `effver`; parents inside it are kept, so lanes
   and merges survive. The duplicates get new change IDs.
4. Check: no conflicts (`jj log -r 'effver:: & conflicts()'`), and the new tip
   differs from `v0.1.N+1@origin` only by review changes that came through the
   squash. Compare the two diffs, ignoring `index` lines (hunk offsets may move):

   ```text
   jj diff --from <where N+1 branched> --to effver --git | grep -v '^index '   > up.diff
   jj diff --from v0.1.N+1@origin --to <new tip> --git | grep -v '^index '      > drift.diff
   diff up.diff drift.diff                                                       # only @@ offsets
   ```

5. Make the squashed sibling (above), and repeat for the versions stacked on it.

## Drop a merged version's micro chain

Only after nothing descends from it:

```text
jj log -r '(<base>::<chain-tip> ~ <base>):: ~ (<base>::<chain-tip>)'   # empty = no dependants
jj abandon '<base>::<chain-tip> ~ <base>'
```

Abandon the whole set, not a `root::tip` range: in a fanned chain, `root::tip`
covers only the paths through one root and orphans the other lanes. Plain
`abandon` deletes bookmarks on those commits (`--retain-bookmarks` keeps them).

## Push, one branch at a time

Only when Alyssa says so. Pick what the bookmark points at, the squashed sibling
or the chain tip:

```text
jj bookmark set v0.1.N -r <squashed-or-tip> --allow-backwards   # sideways move needs -B
jj git push --remote origin -b v0.1.N
```

Stacked PRs (`v0.1.N+1` into `v0.1.N`) then show their diff against the new
branch below them.

## Pitfalls seen

- **Abandoning merged micro commits while later chains still descend from them**
  conflicts the whole graph: abandon removes a commit's changes from its
  descendants. Don't repair that; rebuild each version from its pushed tree
  (`duplicate` from `vN@origin`).
- **`jj resolve --tool :theirs` takes the whole file from that side**, not just
  the conflicted hunks. On a file both sides edited, it silently drops the other
  side's non-conflicting changes. Rebuild the file instead: `jj new <change>`,
  write the parent's file plus the change's own edits, `jj squash -u`.
- **A real conflict between a version's edit and an upstream review edit**
  (same line) needs a decision. Prefer the later author intent, keep upstream
  wording where they agree, and say what was chosen.
- **Short change-ID prefixes collide** once duplicates exist (two changes
  starting `qyn`). Use four or more characters, and confirm with `jj log -r`.
