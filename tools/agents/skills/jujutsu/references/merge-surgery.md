# Merge and fan surgery

Operations on history shaped as a **fan** — many topic branches converging on one
merge commit — rather than a line. Every claim here was verified against jj v0.44
on scratch repos before being written down.

Load this when:
- A commit has to be added to one branch of an existing merge
- Branches need collapsing into a chain, or a chain fanning back out
- A merge commit has parents that are no longer meaningful
- Sibling commits conflict at merge time and the reason isn't obvious

---

## Adding a commit to one branch of a merge

Use `jj new --insert-after <branch-tip>`. It rewrites **exactly one parent edge** of
the downstream merge and leaves the others byte-identical.

```
jj new --insert-after <branch-tip> -m "message"
```

Verified on a 3-parent merge — only the touched branch's commit id changed:

```
before                          after
rkzukonp  branch-a          ->  rvqqwwov  branch-a: extra step   (new)
onsnqwlz  branch-b 9dbe9e8d ->  onsnqwlz  branch-b 9dbe9e8d      (same id)
mqsvtwoo  branch-c 78ca87df ->  mqsvtwoo  branch-c 78ca87df      (same id)
```

Add `--no-edit` to keep `@` where it is. If the commit already exists as a dangling
child, splice it in after the fact with the same flag on `rebase`:

```
jj rebase -r <new-change> --insert-after <branch-tip>
```

jj reports `Skipped rebase of 1 commits that were already in place. Rebased 1
descendant commits.` — the skip is the new commit, the rebase is the merge's edge.

### Trap: `--insert-before <the-merge>` collapses the fan

It reads like the right phrasing and is not. The **new** commit absorbs all N parents
and becomes the octopus; the original merge degrades to an ordinary single-parent
child. The merge point moves and the fan is gone:

```
$ jj new --no-edit --insert-before done -m "..."
--- parents of done now ---
mmwzkvrw  ...        # 3 parents became 1
```

Always name the *branch tip* with `--insert-after`, never the merge with
`--insert-before`.

---

## `-r` versus `-s` when adding a parent

To give an existing commit a second parent — turning it into a merge — pass two
`-d` flags. **Which selector you use decides whether the chain survives.**

```
jj rebase -s <commit> -d <parent1> -d <parent2>     # correct
jj rebase -r <commit> -d <parent1> -d <parent2>     # shreds the chain
```

`-r` moves that commit alone and **reparents its descendants onto its old parent**.
In a chain `A → B → C`, `jj rebase -r B -d A -d S` leaves `C` hanging off `A`, and
`B` becomes a side branch. Applied in a loop down a long chain this detaches every
link, and because the content of each commit is then computed against the wrong
ancestor, files silently change. The symptom is a checksum that moves and a wave of
conflicts far from the edit.

`-s` moves the commit **and its descendants**, so `C` stays attached to `B`:

```
$ jj rebase -s B -d A -d S
Rebased 2 commits to destination.
B parents: A side
C parent:  B
```

Recovery if `-r` was used by mistake: `jj op log`, find the operation immediately
before the first bad rebase, and `jj op restore <id>`. This is exactly what the
operation log is for — do not try to re-rebase your way out.

---

## jj does not simplify redundant merge parents

Collapsing fan branches into a chain does **not** clean up the merge that used to
join them. After chaining `a → b → c`, a merge that had all three as parents still
has all three — including `a` and `b`, now ancestors of `c`:

```
done parents:  br-c  br-b  br-e  br-d  br-a     # b and a are redundant
```

Nothing errors. The dead edges just sit there, and every future `parents()` query
and every graph render carries them.

Drop them with `heads()`, which keeps only parents that are not ancestors of another
parent:

```
jj rebase -r <merge> -d 'heads(parents(<merge>))'
```

`-r` is correct here precisely because a merge commit's descendants should stay put.
Verify afterwards that content is unaffected — every branch's files should still be
reachable from the merge.

---

## Append-only files cannot be built by sibling merges

A file that is only ever appended to — `.gitignore`, a changelog, `SUMMARY.md` — has
exactly one insertion point: the end. Siblings that each append there are all
claiming the same offset, and the merge cannot choose:

```
tlzurkum  merge: language track ignores   CONFLICT
 ├── rlpsyzzq  Swift        ok
 ├── kqtvvrwr  Kotlin/JNA   ok
 └── pnuonkvl  Dart         ok
```

The siblings are individually clean. Only the merge fails, and jj records all three
alternatives as sides of one conflict.

**The damage compounds**, because jj commits conflicts rather than halting. A second
octopus built on the conflicted result inherits the first conflict and adds its own.
Measured on one chain: 1605 bytes at the fork, 2439 after the first merge, **11450
after the second** — nearly 3× the correct file, all of it markers. Git would have
stopped at the first merge; jj lets the mistake propagate silently. That is the price
of conflicts-as-values.

A **linear chain has no such problem** — each commit appends after the previous one,
so every hunk lands at a distinct offset and 3-way merge resolves cleanly.

### The anchor workaround, and what it really costs

Siblings *can* merge cleanly if the base commit pre-declares a distinct anchor line
per section, so each sibling edits a different region:

```
# --- Language tracks ---
# Swift            <- sibling 1 inserts here
# Kotlin           <- sibling 2 inserts here
# Dart             <- sibling 3 inserts here
```

Verified clean, and **no padding is required** — a unique anchor line is enough
context on its own; headers on consecutive lines still merge.

But note what this buys. The base commit now fixes the final section order, so the
linearization has merely moved *earlier*. The octopus gives independent **authoring**
within a layout that was already decided; it does not give order-independence. If
genuine independence is the goal, give each branch its **own file** — nested
per-directory `.gitignore` files, for instance. That is why a fan whose branches
touch disjoint paths merges cleanly with any number of parents.

---

## Octopus merges are invisible in combined diffs

An octopus merge of branches that touch disjoint paths produces a combined diff with
**zero hunks**. `--stat` lists the files; the patch body is empty:

```
--cc patch hunks:  0
--cc stat entries: 3
```

This is git-level behaviour, not a GitHub quirk — `--cc` only shows content differing
from *all* parents, and disjoint changes differ from only one. Consequences:

- GitHub's diff view for such a merge shows nothing reviewable.
- `git log -p` skips merges unless given `-m`, `-c`, or `--first-parent`.
- Per-parent diffs are still available with `jj show --git <parent>` or `git show -m`.

So a fan is a fine way to *build* history and a poor way to *present* it. If readers
are meant to follow the steps — a workshop repo, a tutorial — the linear chain is
what actually communicates, and the fan is authoring convenience only.
