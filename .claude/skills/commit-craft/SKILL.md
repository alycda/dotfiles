---
name: commit-craft
description: >
  The commit message format for Alyssa's repositories. Use every time you
  write or change a commit message: before `jj describe`, `jj new -m`,
  `jj commit`, `jj squash -m`, `git commit` or `git commit --amend`, when
  asked to "commit this", and when reviewing or rewording existing messages.
  Applies in any harness (Claude Code, Crush, Codex). check-commit-msg checks
  the shape; this skill covers what no check can judge. The facts come from
  sem (the entity-level-git skill).
---

# Commit Craft

`check-commit-msg` checks the shape of a message. This skill covers the part
no check can judge: what the message says. sem, from the entity-level-git
skill, gives the facts (which entities changed); this skill gives the order.

**Done when** each logical change is a commit whose message passes
`check-commit-msg`, and `jj st` (or `git status`) shows none of the task's
changes left. **Stop when** there is nothing to commit: say so, and do not
make an empty commit.

## The checks

| Command | What it checks |
| --- | --- |
| `check-commit-msg FILE` (or stdin) | One message, against the shape rules below. Run it before you set a message. |
| `check-commits --jj [REVSET]` | Every commit in a revset, merges skipped. Run it before asking for a push. |
| `check-commits RANGE` | The same, over a git range such as `origin/main..HEAD`. |

They are in `tools/commit/`, on PATH where mise is active. Nothing runs them
for you: jj runs no git hooks.

## Which convention wins

1. A convention the repository documents (CONTRIBUTING, CLAUDE.md, AGENTS.md,
   a commitlint config) wins.
2. Otherwise, use this skill. Do not copy the style of the repository's
   history: it predates this format.

## Procedure

Do these steps in order for every commit.

1. Read the full change and the task that caused it. You must know why the
   change exists, not only what it is. If `sem` is installed, start with
   `sem diff --no-cosmetics` (see Facts). Then read `jj diff --git` (or
   `git diff --staged`) for the detail.
2. If the change does two unrelated things, split it first (see the jujutsu
   skill). Signs of two commits: a subject that needs "and", two groups of
   entities in `sem diff` with no relation, or formatting-only edits (sem
   marks them cosmetic) next to real ones.
3. Write the message to a file outside the working copy (your scratchpad, or
   `$TMPDIR`). jj snapshots every file in the working copy.
4. Run `check-commit-msg /path/to/msg.txt`. Fix every problem it prints, and
   run it again until it prints nothing.
5. Set the message from the file: `jj describe --stdin < /path/to/msg.txt`.
   With git only, stage the commit's files by name and name them again on
   the commit:

   ```bash
   git add path/one path/two
   git commit -F /path/to/msg.txt -- path/one path/two
   ```

   Never `git add -A` or `git add .`. A `git commit` without paths takes
   everything already staged, including changes that are not part of this
   commit. jj has no staging area, so this step is git only.
6. Push only when Alyssa asks.

## Subject line

Format: `<area>(<scope>): <summary>`. The `(<scope>)` part is optional.

```text
mise(tools): weave, the entity-level merge driver
agents(skill): jujutsu resolves conflicts with weave
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

- The summary names the outcome: what is now possible or fixed. It does not
  list files. `mise(tools): update mise.toml` says nothing a diff does not;
  `mise(tools): weave, the entity-level merge driver` says what changed for
  the reader. A noun phrase is correct when the commit adds one thing.
- When the commit implements one unit of a compound-engineering plan and the
  unit ID is already known, end the subject with it in parentheses:
  `tools(commit): check the body width (U3)`. Do not look for a plan to find
  one. Leave it out when the commit spans units.
- The area is the part of the repository or the tool the change belongs to.
  Reuse one from the log: `mise`, `agents`, `docs`, `tools`, `ide`,
  `ignore`, `cheat`, `task`. Make a new one only for something new at the top
  level of the repository.
- The scope narrows the area: `agents(skill)`, `mise(tools)`. Leave it out
  when the area is narrow enough.

## Body

A body is required. Wrap it at 72 characters. Indented lines and lines with a
URL can be longer. Write these paragraphs in this order. Leave one out only
when it has nothing to say.

1. **Why.** The problem or the need, with the evidence: the error text, the
   task or issue. Say what was wrong before this commit.
2. **What and how.** What the change does to behavior. When there was
   another option, name it and say why it was not used. Do not walk through
   the diff line by line.
3. **Verification.** Name the environment. Say what you ran and what you
   saw, then which checks pass. Say what you did not run, and why. Never
   claim a check you did not run.
4. **What is left.** Follow-up work, known limits, and the task that tracks
   them.

## Facts

Where `sem` is installed (it comes from mise here), it lists the entities a
change touches by name: functions, sections, keys. Use it for the facts in
the body.

- `sem diff --no-cosmetics` in a colocated jj repo shows `@` against `@-`.
  For another commit, run `sem diff --commit <id>` with its git commit ID
  (`jj log -r <rev> --no-graph -T commit_id`).
- The "what and how" paragraph covers the entities that list shows. If the
  commit also has formatting-only edits, say so in one sentence.
- Name each entity as sem names it, in backticks. Do not paraphrase it.
- For the verification paragraph, `sem impact <entity> --tests` lists the
  tests that depend on a changed entity. Run them and name them. A
  dependent that no test covers goes in "what is left".
- sem's language coverage is uneven. When it returns `chunk` entities or an
  empty dependency graph, use `jj diff` and do not cite `sem impact`. The
  entity-level-git skill lists the known gaps.
- Without sem, use `jj diff`, and say in your reply that sem was not
  available. Do not install it to write a commit message.

## Language

Write plain English: short sentences, one idea each, common words, the
active voice. Say what the change does, not how you feel about it.

- Write as the author. The commit is Alyssa's, also when an AI trailer is on
  it. Do not address her or the reviewer ("as you choose", "you can squash
  this"). Put notes for the reviewer in the PR body.
- Refer to another commit by its subject line, in quotes. A subject stays
  correct after a rebase, a squash and a push to GitHub, and
  `git log --grep` finds it. Do not use a jj change ID: GitHub cannot
  resolve it. Use a git hash only for a commit on the default branch, which
  is not rewritten. For merged work, use the PR number (`#N`).
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

## With compound-engineering's ce-commit

The compound-engineering plugin's `ce-commit` skill also triggers on "commit
this". Where this skill applies, it replaces ce-commit: its format, the
required body and `check-commit-msg` apply, and in a jj repository the
jujutsu skill's commands replace ce-commit's git steps (no `git checkout -b`,
no staging).

## Rewording existing commits

To change the message of another commit, run
`jj describe -r <change-id> --stdin < msg.txt`. Run `check-commit-msg` on the
file first. Do not reword commits on a remote branch that other people use,
unless you are asked to.
