# Examples

Real commits from the dotfiles repository, rewrapped at 72 characters and
with their trailers removed. Each one has a note on what to copy from it.

## A fix to another change, named by its subject

```text
ci(tasks): test the global HUID task recipes

"just: global justfile with the HUID task recipes" moved `task` and
`task-edit` out of the repo justfile into the global one (tools/just)
and their logic into tasks/scripts, but huid-tasks.bats still copied
the repo justfile and ran `just task`: 7 of its 8 tests failed with no
such recipe.

The suite now runs tools/just/justfile the way `just -g` does (from the
test's temp dir), with tasks/scripts on PATH as mise links them and
HOME in a temp dir so no local.just joins in. Two tests cover what that
commit added: without a tasks/ dir a task goes to .tasks/, and
TASKS_DIR overrides both.

All bats suites (26) pass; shellcheck and editorconfig-checker too.
```

Copy: the first paragraph names the commit that caused the problem by its
subject line, which survives a rebase, a squash and the move to GitHub, and
it gives the exact failure ("7 of its 8 tests failed").

The original named that commit by its jj change ID and ended with "a
dangling fix for vmolorpo, to squash or rebase as you choose". Both are
removed here. GitHub cannot resolve a change ID, and the commit is the
author's, so it does not give the author instructions.

## A noun-phrase subject, and an honest list of what was not run

```text
jj-stash: vendor and install through mise

tools/jj-stash holds jj-stash, its README and its three test scripts,
unchanged from alycda/jj at 1f1aafa. tools/jj-stash/UPSTREAM records
the commit. mise links the command into ~/.local/bin.

It needs bash 4+, and mise's registry has no bash. On a Mac with no
Nix, `env bash` is /bin/bash 3.2 and the script fails; with nix-darwin
it resolves to the system bash 5.x, and the devcontainers have
Debian's.

Tested in a lab copy of this repo through the mise-installed link:
push hides a three-commit chain, and list, index and the exclude rule
work. pop restores identical change and commit IDs and leaves no refs;
drop forgets a stash and prints the recovery `jj new`. The vendored
tests are pinned to a lab copy of ~/WIP/jj-dotfiles and were not run.
```

Copy: the verification paragraph says what was observed, command by
command, and ends with what was *not* run and why. The second paragraph is
a known limit, stated as a fact with the platforms it affects.

## Behavior first, then verification that matches it

```text
devcontainer(nix): apply home-manager on create

The Nix devcontainer switches to the home-manager profile in
postCreateCommand ($USER set, since lifecycle commands leave it
unset). The Nix feature now only enables flakes; its jj/just package
list is gone, since the profile provides every tool. postAttachCommand
calls just by its profile path, because lifecycle commands get a plain
/bin/sh PATH.

Tested with a fresh build through the devcontainer CLI: postCreate
activates the profile. postAttach reaches the recipe, which stops at
"no VS Code CLI" as expected without an attached VS Code. An
interactive zsh has all eleven tools, EDITOR=hx, `..`, revsets.fix=@,
cheat jj/fix and the shared git config: the same checks as the mise
container.
```

Copy: every "because" in the first paragraph explains a choice a reader
would otherwise question. Each claim in the first paragraph has a matching
check in the second.

## What not to write

```text
Updated agent skills.
```

The area is missing, the summary is capitalised, it is in the past tense,
it ends with a period, and there is no body. A reader learns nothing that
`jj diff --stat` would not show.

```text
docs(agents): Instructions for Claude
```

The summary is capitalised and there is no body. Which instructions, and
why now?
