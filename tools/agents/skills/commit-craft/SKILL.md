---
name: commit-craft
description: >
  The commit message format for Alyssa's repositories. Use every time you
  write or change a commit message: before `jj describe`, `jj new -m`,
  `jj commit`, `jj squash -m`, `git commit` or `git commit --amend`, when
  asked to "commit this", and when reviewing or rewording existing messages.
  Applies in any harness (Claude Code, Crush, Codex). The shape is checked by
  check-commit-msg, the jj push alias, a git hook and CI; this skill covers
  what those checks cannot judge. The facts come from sem (entity-level-git)
  and the wording from the ste100 skill.
---

# Commit Craft

The commit path enforces the shape of a message. This skill covers the part
no check can judge: what the message says. It adds no language rules of its
own. Two other skills do the work it would otherwise repeat: sem, from the
entity-level-git skill, gives the facts (which entities changed), and ste100
gives the words. This skill gives the order.

## What is enforced, and where

| Where | What runs |
| --- | --- |
| `check-commit-msg FILE` (or stdin) | The shape rules below. Run it yourself before you set a message. |
| `jj describe` with an editor | The editor opens with the format as `JJ:` lines. |
| `jj push` (alias) | `check-commits --jj` on the stack that is not on trunk yet, then `jj git push` with the same arguments. |
| `git commit` in the dotfiles checkouts | The `commit-msg` hook in `tools/git/hooks`. |
| A pull request on the dotfiles repo | CI runs `check-commits` on the PR's commits. |

The scripts are in `tools/commit/` in the dotfiles repo, and on PATH through
mise or home-manager. jj runs no git hooks, so in a jj repo push with
`jj push`, not `jj git push`.

## Which convention wins

1. A convention the repository documents (CONTRIBUTING, CLAUDE.md, AGENTS.md,
   a commitlint config) wins. Push with `jj git push` there, because
   `jj push` checks this skill's format.
2. Otherwise, use this skill. Do not copy the style of the repository's
   history.

## Procedure

Do these steps in order for every commit.

1. Read the full change and the task that caused it. You must know why the
   change exists, not only what it is. If `sem` is installed, start with
   `sem diff --no-cosmetics` (see Facts). Then read `jj diff --git` (or
   `git diff --staged`) for the detail.
2. If the change does two unrelated things, split it first (see the jujutsu
   skill). Signs of two commits: a subject that needs "and", two groups of
   entities in `sem diff` with no relation, or formatting-only edits (sem
   marks them `[cosmetic]`) next to real ones.
3. Write the message to a file outside the working copy (your scratchpad, or
   `$TMPDIR`). jj snapshots every file in the working copy.
4. Apply the ste100 skill to the body (see Language).
5. Run `check-commit-msg /path/to/msg.txt`. Fix every problem it prints, and
   run it again until it prints nothing. ste100 can change line lengths, so
   run it after step 4.
6. Set the message from the file: `jj describe --stdin < /path/to/msg.txt`,
   or `git commit -F /path/to/msg.txt` with git only.
7. Push with `jj push`.

## Subject line

Format: `<area>(<scope>): <summary>`. The `(<scope>)` part is optional.

```text
ci(nix): secure the runner dirs compaudit flags
devcontainer(nix): apply home-manager on create
```

`check-commit-msg` enforces these rules:

- `area` is lowercase: letters, digits and `-`.
- One space after the colon. The summary starts with a lowercase letter,
  unless its first word is a name that is always written in capitals
  (`HUID`, `README`).
- 72 characters at most. Aim for 50 to 60.
- No period at the end.
- The first word of the summary is not past tense (`fixed`, `added`), third
  person (`fixes`, `adds`) or "this".

These rules are yours to apply:

- The summary says what the commit does (`secure the runner dirs ...`) or
  names what it adds (`global justfile with ...`).
- The area is the part of the repository or the tool the change belongs to:
  `hm` (home-manager), `ci` (`.github/`), `mise`, `nix`, `devcontainer`,
  `just`, `agent(skills)`, `docs`. Reuse an existing area. Make a new one
  only for something new at the top level of the repository.
- The scope narrows the area: `ci(nix)` is the Nix workflow. Leave it out
  when the area is narrow enough.

## Body

A body is required. Wrap it at 72 characters. Indented lines and lines with a
URL can be longer. Write these paragraphs in this order. Leave one out only
when it has nothing to say.

1. **Why.** The problem or the need, with the evidence: the error text, the
   CI run, the task or issue. Say what was wrong before this commit.
2. **What and how.** What the change does to behavior. When there was
   another option, name it and say why it was not used. Do not walk through
   the diff line by line.
3. **Verification.** Name the environment. Say what you ran and what you
   saw, then which checks pass. Say what you did not run, and why. Never
   claim a check you did not run.
4. **What is left.** Follow-up work, known limits, and the task or issue that
   tracks them.

## Facts

Where `sem` is installed (the entity-level-git skill says where), it lists
the entities a change touches by name: functions, classes, Nix bindings such
as `home.packages`. Use it for the facts in the body.

- `sem diff --no-cosmetics` in a colocated jj repo shows `@` against `@-`.
  For another commit, run `sem diff <commit>^ <commit>` with its git commit
  ID (`jj log -r <rev> --no-graph -T commit_id`).
- The "what and how" paragraph covers the entities that list shows. If the
  commit also has formatting-only edits, say so in one sentence.
- Name each entity as sem names it, in backticks. ste100 treats a technical
  name as one word with one spelling, so do not paraphrase it.
- For the verification paragraph, `sem impact <entity> --tests` lists the
  tests that depend on a changed entity. Run them and name them. A
  dependent that no test covers goes in "what is left".
- sem's language coverage is uneven. When it returns `chunk` entities or an
  empty dependency graph (Dart, for one), use `jj diff` and do not cite
  `sem impact`. The entity-level-git skill lists the known gaps.
- Without sem (most sandboxes and devcontainers), use `jj diff`, and say in
  your reply that sem was not available. Do not install it to write a
  commit message.

## Language

The body is a "commit body" surface in the ste100 skill: use its
STE-flavored mode. Do not apply ste100 to the subject line. Read
`~/.agents/skills/ste100/SKILL.md` before you write the body. If it is not
installed, say so in your reply. Do not reconstruct its rules from memory.

These rules are about the commit, not the language, so they apply either
way:

- Write as the author. The commit is Alyssa's, also when an AI trailer is on
  it. Do not address her or the reviewer ("as you choose", "you can squash
  this"). Put notes for the reviewer in the PR body.
- Refer to another commit by its subject line, in quotes. A subject stays
  correct after a rebase, a squash and a push to GitHub, and
  `git log --grep` finds it. Do not use a jj change ID: GitHub cannot
  resolve it. Use a git hash only for a commit on the default branch, which
  is not rewritten. For merged work, use the PR number (`#N`), which GitHub
  links.
- Use backticks for commands, file names and identifiers. Use a hyphen list
  for parallel items. Do not use headings, bold or emoji.

## Trailers

Trailers go in the last paragraph, one `Key: value` per line, after a blank
line.

- Keep the attribution trailers your harness tells you to add (for example
  `Co-Authored-By:`). Do not invent others.
- Put attribution only in trailers. Never put a "Generated with ..." line in
  the body.

## Example

This example shows the shape. ste100 decides the wording.

```text
ci(nix): secure the runner dirs compaudit flags

The home job in nix.yml failed in run 36364995815. In the interactive
zsh, compinit found completion dirs that it thinks are not secure: dirs
that a user other than root or the owner owns or can write to. No
terminal was available to answer its "continue?" prompt, so compinit
stopped and the compinit check failed. The devcontainer image has no
such dirs, so the local run passed.

A new step runs before the check. It lists the dirs that compaudit
flags, and makes root their owner (chown root:root, chmod go-w). The
step prints the list, so the log shows which runner dirs they were.

Reproduced in the devcontainer base image: another user got
/usr/local/share/zsh, compinit stopped, and the check failed as in CI.
After the step, all ten checks pass.

Co-Authored-By: <the agent your harness names>
```

These subjects fail `check-commit-msg`:

```text
Updated agent skills.
```

```text
docs(agents): Instructions for Claude
```

## Rewording existing commits

To change the message of another commit, run
`jj describe -r <change-id> --stdin < msg.txt`. Run `check-commit-msg` on the
file first. Do not reword commits on a remote branch that other people use,
unless you are asked to.
