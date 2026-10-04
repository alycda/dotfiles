# Concepts

Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as ce-compound and ce-compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Versioning

### EffVer

The versioning scheme: a version is MACRO.MESO.MICRO, and which number changes says how much Effort it takes to adopt the Version.

Below 1.0 the scheme has only two numbers that move: a macro Effort bumps the middle one, and meso and micro both bump the last. The label still records which of the three it was.

### Effort

What it takes to adopt a VERSION on a machine already running the previous one, not what it took to build.
*Avoid:* size, impact

Decided in order. If everything that worked before still works after pulling, it is micro, however large the change. If getting back to working is a bounded step, like installing a tool or an extension or renaming a setting, it is meso. If it means changing how you work or redoing something, it is macro. Opt-in additions are micro: the cost of opting in is written in the Version's notes, not counted in the version. Opt-in that quietly becomes required, such as a setting that switches the old way off or a command that loses its fallback, raises the Effort.

### Version

A version together with its changelog section, which says what changed and, unless the Effort is micro, the steps to adopt it.

The version bump belongs to the Version commit, never to the changes that make it up. The section of a Version that has been published is not edited afterwards.

### Version commit

The merge that brings a Version's Lanes together and carries its version bump and changelog section.

## History

### Change

A unit of work in the history, known by a change ID that stays the same when the Change is rewritten; its commit ID changes with every rewrite.
*Avoid:* commit, when the stable identity is meant

### Working-copy change

The Change that the working directory always is: every jj command first records the directory into it, so there is no staging step and any file present is tracked.

Ignore rules only stop a file from becoming tracked. A file already tracked stays tracked; it can be untracked only after an ignore rule covers it; and rebasing Changes past a new ignore rule does not remove the file from them. Check the ignore rules before generating files.

### Lane

An independent line of Changes, one concern each, that converges with the other Lanes of a Version in an octopus merge.
*Avoid:* branch

Files that every Lane appends to, such as the changelog or ignore rules, conflict when the Lanes merge, because each claims the same end of file. Moving a single Change out of a Lane hands its descendants to its old parent; to give a merge another parent, move it together with its descendants.

### Bookmark

A named pointer to a Change, which stays where it is until moved explicitly.
*Avoid:* branch

### Micro-commit

A small local Change in a Lane: the personal changelog and the record of what depends on what.

Micro-commits are never published. They may be reshaped freely until the work they hold has been published.

### Published commit

A Change on the single linear chain that is pushed for others to see, holding converged work from the Micro-commits.

A Published commit is linked to the Micro-commits by having the same tree, not by ancestry: it is a copy of a converged, conflict-free tip, and its diff is exactly the work since the previous Published commit. The strict commit format applies here.

### Immutable change

A Change that jj refuses to rewrite, because it is part of the main line or tagged.

Being refused is a stop sign: something published is involved, and rewriting it is the owner's decision.

### Colocated repository

A repository where jj and git share one store, so git tools can read it.

Reading with git is safe. Writing with git (commit, checkout, reset, rebase, push) bypasses jj and is not done.

## Tasks

### Task

A unit of work recorded as a markdown file in its own directory named by its HUID: the brief before the work, and its record after.
*Avoid:* ticket, issue

A Task is OPEN or CLOSED. An agent working a Task writes its open questions and how it verified the work back into the same file, and closes it only when the verification passed.

### HUID

A Human-Unique IDentifier: the UTC time a Task was created, to the second, with an optional suffix.

HUIDs are unique because people create Tasks no faster than one per second; on a collision, wait a second and generate a new one. Unlike a counter, two Lanes can each add Tasks and merge without colliding. The suffix tells apart people or machines that might land on the same second.

## Toolsets

### Minimal toolset

The smallest set of tools that makes a fresh machine able to work in the repository, installed by mise from one file inside the repository.

It is kept small on purpose: a tool joins it only when the repository needs it, and heavier development or test tooling waits for the Full toolset. A tool nothing depends on adds no Effort; once something depends on it, adopting means installing it.

### Full toolset

The complete, declarative environment for a machine and its user, built with Nix and meant as a superset of the Minimal toolset.

### Devcontainer

A container built from one of the Toolsets, for working in the repository without changing the host.

Using a Devcontainer is opt-in, so adding one is micro; it raises the Effort only if work in the repository comes to require it.

## Flagged ambiguities

- "Branch" had been used for both a Lane and a Bookmark; these are distinct, and neither word is "branch".
- "Task" means a HUID Task in this repository. Personal to-dos kept in other tools are not Tasks.
