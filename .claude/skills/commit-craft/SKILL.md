---
name: commit-craft
description: >
  The commit message format for Alyssa's repositories. Use every time you
  write or change a commit message: before `jj describe`, `jj new -m`,
  `jj commit`, `jj squash -m`, `git commit` or `git commit --amend`, when
  asked to "commit this", and when reviewing or rewording existing messages.
  Applies in any harness (Claude Code, Crush, Codex). Has a checker script
  that every message must pass before it is set. The jujutsu skill covers
  the VCS commands; this skill covers what the message says.
---

# Commit Craft

This skill defines one commit message format. Follow it exactly. The goal is
that every commit reads the same no matter which agent or model wrote it.

## Which convention wins

1. A convention the repository documents (CONTRIBUTING, CLAUDE.md, AGENTS.md,
   a commitlint config) wins.
2. If there is none, but `git log --format=%s -30` shows a different consistent
   style, follow that history.
3. Otherwise, and always in the dotfiles repository, use this skill.

## Procedure

Do these steps in order for every commit.

1. Read the full change: `jj diff --git` (or `git diff --staged`). Read the
   task or conversation that caused it. You need to know *why*, not only
   *what*.
2. If the change does two unrelated things, split it first (see the jujutsu
   skill). A subject that needs "and" is a sign of two commits.
3. Pick the area and scope (below).
4. Write the message to a file outside the repository (your scratchpad, or
   `$TMPDIR`). Never write it inside the working copy: jj snapshots it.
5. Run the checker on the file and fix every problem it prints. Repeat until
   it prints nothing:

   ```bash
   <skill-dir>/scripts/check-message /path/to/msg.txt
   ```

   `<skill-dir>` is the directory that holds this SKILL.md. In the dotfiles
   repository it is `.claude/skills/commit-craft`.
6. Set the message from the file:

   ```bash
   jj describe --stdin < /path/to/msg.txt        # jj
   git commit -F /path/to/msg.txt                 # git only
   ```

7. Check what was stored:
   `jj log -r @ --no-graph -T description | <skill-dir>/scripts/check-message`.

## Subject line

Format: `<area>(<scope>): <summary>`. The `(<scope>)` part is optional.

```text
hm(zsh): compinit -i, instead of re-owning dirs in CI
ci(nix): secure the runner dirs compaudit flags
just: global justfile with the HUID task recipes
devcontainer(nix): apply home-manager on create
```

Hard rules (the checker enforces them):

- `area` is lowercase: letters, digits and `-`.
- One space after the colon. The summary starts with a lowercase letter,
  unless its first word is a name that is always written in capitals
  (`HUID`, `README`).
- 72 characters at most. Aim for 50 to 60.
- No period at the end.
- The summary says what the commit does or adds. Use an imperative verb
  (`secure the runner dirs ...`) or a noun phrase for the thing added
  (`global justfile with ...`). Do not use past tense (`fixed`, `added`), the
  third person (`fixes`, `adds`), or "this commit".

Choosing the area and scope:

- Reuse an area that already exists. List them with:

  ```bash
  git log --no-merges --format=%s |
    sed -nE 's/^([a-z0-9-]+(\([^)]*\))?):.*/\1/p' | sort | uniq -c | sort -rn
  ```

- The area is the part of the repository or the tool the change belongs to.
  Examples from the dotfiles: `hm` (home-manager), `ci` (`.github/`), `mise`,
  `nix`, `devcontainer`, `just`, `agent(skills)`, `docs`.
- The scope narrows the area: `ci(nix)` is the Nix workflow, `hm(zsh)` is
  home-manager's zsh. Leave it out when the area is already narrow enough.
- Make a new area only for something new at the top level of the repository.

## Body

A body is required. Wrap it at 72 characters. Indented lines (pasted output,
code) and lines that contain a URL can be longer.

Write the paragraphs in this order. Skip a paragraph only when it has nothing
to say.

1. **Why.** The problem or the need. Give the evidence: the error text, the CI
   run, the task or issue. Say what was wrong before this commit, not what
   you did about it.
2. **What and how.** What the commit changes, in terms of behavior. Say why
   it is done this way when there was another choice, and name the choice you
   did not take. Name files and settings when that helps a reader find them.
   Do not walk through the diff line by line.
3. **Verification.** Start with "Tested in ..." or "Verified in ..." and name
   the environment. Say what you ran and what you saw. Then list the checks
   that pass (`shellcheck`, `nix flake check`, the bats suites). Also say what
   you did *not* run, and why. Never claim a check you did not run.
4. **What is left.** Follow-up work, known limits, a task that tracks them, or
   an instruction for the person who merges ("a fix for vmp, to squash or
   rebase as you choose").

Language:

- Plain words and short sentences. One idea per sentence.
- Past tense for what was wrong before. Present tense for what the code does
  now.
- Refer to other commits by their jj change ID (the short prefix `jj log`
  shows, for example `vmp`), because it survives rewrites. Use the git hash
  only in a repository without jj.
- Use backticks for commands, file names and identifiers. Use a hyphen list
  for parallel items. Do not use headings, bold or emoji.
- Do not write filler: "This commit", "comprehensive", "robust",
  "seamlessly", "Additionally", "In order to". Do not praise the change.

## Trailers

Trailers go in the last paragraph, one `Key: value` per line, after a blank
line.

- Keep the attribution trailers your harness tells you to add (for example
  `Co-Authored-By:` and `Claude-Session:`). Do not invent others.
- Put attribution only in trailers. Never put a "Generated with ..." line or
  an emoji banner in the body.
- `Closes #N` or `Refs #N` goes in the body's last paragraph, not in the
  trailers, unless the repository uses a different convention.

## Example

A real commit from the dotfiles, wrapped at 72:

```text
ci(nix): secure the runner dirs compaudit flags

nix.yml's home job failed in run 36364995815: in the interactive zsh,
compinit found completion dirs it considers insecure (owned by, or
writable by, someone other than root and the user). With no terminal to
answer its "continue?" prompt it aborted, so the compinit check failed.
The devcontainer image has no such dirs, which is why the local run
passed.

A step before the check now lists what compaudit flags and hands it to
root (chown root:root, chmod go-w), printing the list so the log shows
which of the runner's dirs they were.

Reproduced in the devcontainer base image by giving another user
/usr/local/share/zsh: compinit aborted and the check failed as in CI;
after the step, all ten checks pass.

Co-Authored-By: <the agent your harness names>
```

More examples, with what each one does well: `references/examples.md`.

## Rewording existing commits

To fix a message on another commit, use
`jj describe -r <change-id> --stdin < msg.txt`. Run the checker on it first.
Do not reword commits that are already on a remote branch someone else uses
unless you are asked to.
