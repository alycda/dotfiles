---
title: "zsh does not word-split: a command kept in a string runs as one word"
date: 2026-10-03
category: developer-experience
module: claude-code-bash-tool
problem_type: developer_experience
component: tooling
severity: medium
applies_when:
  - "An agent or a person types a command into Claude Code's Bash tool, or at the zsh prompt, on these machines"
  - A command and its flags are stored in a variable so that later lines can reuse them
  - "A string of flags, paths or revisions is passed unquoted, expecting one argument per word"
  - "A string is split with for or set --"
symptoms:
  - "zsh: command not found: jj --ignore-working-copy"
  - "zsh: no such file or directory: env -i /usr/bin/true"
  - "ls: invalid option --  (the option it names is a space)"
  - "A for loop over an unquoted string runs once, and set -- gives one argument"
  - "A count taken with 2>&1 | wc -l is 1, because the only line is the error"
resolution_type: workflow_improvement
related_components:
  - development_workflow
tags:
  - zsh
  - word-splitting
  - sh-word-split
  - bash-compatibility
  - claude-code
  - agent-commands
  - shell-quoting
---

# zsh does not word-split: a command kept in a string runs as one word

## Context

Claude Code's Bash tool runs each command in zsh, the login shell on these
machines. Agents write bash out of habit. The habit that fails most often is to
keep a command and its flags in a string, then run the string:

```sh
J="jj --ignore-working-copy"; $J log -r 'all()'
# zsh: command not found: jj --ignore-working-copy
```

bash splits an unquoted `$J` into words. zsh does not, because its
`SH_WORD_SPLIT` option is off by default. zsh looks for one program whose name
is the whole string, spaces included.

This doc exists because the failure keeps coming back:

- 2026-09-19: an agent rule, `tools/agents/rules/zsh-shell.md`, was written on
  the `agents/zsh-rule` branch of alycda/dotfiles. The branch was never merged.
- 2026-09-27: a solutions doc in the old checkout,
  `docs/solutions/developer-experience/claude-code-bash-tool-runs-zsh-bash-isms.md`,
  covered this and three other zsh defaults. That change was never published.
- 2026-10-03: the failure happened again, in a session started in `~` that
  compared the dotfiles checkouts. This account has no `~/.claude/CLAUDE.md`,
  and no project instructions apply in `~`, so the session loaded neither text.
- The error text for a command taken as one word is in 8 of the 69 Claude Code
  transcripts on this account (session history).

The fix was known each time. It was not in a place that an agent reads before
it types a command.

## Guidance

Assume zsh. A variable holds one word, however many spaces are in it.

### 1. A command prefix goes in a function

```sh
# bad
J="jj --ignore-working-copy"; $J log
# good
j() { jj --ignore-working-copy "$@"; }; j log
```

A function works the same in zsh, bash and sh, and `"$@"` keeps each argument
whole.

### 2. Arguments that are data go in an array

```sh
# bad
F="-l -a"; ls $F .
# ls: invalid option --
# good
f=(-l -a); ls "${f[@]}" .
```

`"${f[@]}"` works in zsh and in bash. A command prefix can also be an array:
`j=(jj --ignore-working-copy); "${j[@]}" log`.

### 3. To split a string, say so

```sh
revs="aaa bbb"
# bad: no error, wrong result
for r in $revs; do echo "$r"; done      # one iteration, r="aaa bbb"
set -- $revs                            # $1="aaa bbb", $2 is empty
# good
read -r first second <<<"$revs"
for r in $(jj log --no-graph -T 'commit_id ++ "\n"'); do echo "$r"; done
```

An unquoted `$(command)` is still split in zsh. Only parameters are not. The
best fix is not to build the string: loop over the command's output, or build
an array from the start.

### 4. For anything that needs bash, run bash

```sh
bash <<'EOF'
set -euo pipefail
J="jj --ignore-working-copy"
$J log -r @
EOF
```

The quoted heredoc also removes one level of quoting.

### 5. What not to do

- Do not run the same command again. The result does not change.
- Do not use `${=J}` or `setopt shwordsplit`. They work, but only in zsh, and
  the command then fails when it is copied into a bash script.
- Do not use `eval "$J log"`. It splits, but it also evaluates the string
  again, so every quote and `$` in the arguments changes meaning.

### 6. Put the rule where the agent reads it

A solutions doc is read only when someone searches for it, and no one searches
before typing `X="cmd --flag"`. Two earlier texts did not stop the failure for
that reason. The rule has to be in instructions that every session loads: the
user-level agent instructions and each repository's `CLAUDE.md`. This
repository's `CLAUDE.md` has it, under "Shell: zsh". The user-level
instructions do not have it yet, so expect the failure to come back in
sessions that start outside this repository.

## Why This Matters

- **The loud form costs a round trip.** The command stops with `command not
  found` or `no such file or directory`, and the agent has to see what
  happened and send the command again.
- **The loud form becomes silent in a pipeline.** In the 2026-10-03 session the
  same command line ended with `$J log … 2>&1 | wc -l`. The only line was the
  error, so the command printed `1` for the number of unpushed changes. The
  true number was 40. Only the first half of the command showed an error.
- **The list forms are silent from the start.** `for x in $list` and
  `set -- $list` raise no error. The earlier doc records a `for p in $parents`
  loop that ran once with two commit IDs joined; the result went into a
  rebase.
- **An empty variable hides the problem.** An unquoted empty `$VAR` disappears
  in zsh as it does in bash, so an optional-flags variable works while it is
  empty and fails on the first day it holds two flags.

## When to Apply

- Before a line of the form `NAME="command --flag"` in a command for the Bash
  tool. Write a function.
- Before an unquoted `$VAR` that holds more than one word: flags, paths,
  revisions.
- When an error names a "command" with a space in it. That is this problem,
  not a missing tool. `no such file or directory: <command with a space>` is
  the same failure, for a string that contains a slash.
- When a count or a list from a one-off command is 0 or 1 and a larger number
  was expected. Look at the output without `2>&1 | wc -l`.
- Not for scripts with a shebang. `tasks/scripts/*` and `tools/effver/*` start
  with `#!/usr/bin/env bash`, and `tools/setup/*` with `#!/usr/bin/env sh`.
  They run in the shell they name, where `$VAR` splits.

## Examples

All of these were run on zsh 5.9.2 and jj 0.45.1.

### The command from the 2026-10-03 session

```sh
# before
cd ~/WIP/jj-dotfiles; J="jj --ignore-working-copy"
$J log -r 'all()'
# zsh: command not found: jj --ignore-working-copy
$J log --no-graph -r "$UNPUSHED" 2>&1 | wc -l
#        1          <- the error line, counted as one change

# after
cd ~/WIP/jj-dotfiles; J() { jj --ignore-working-copy "$@"; }
J log -r 'all()'
J log --no-graph -r "$UNPUSHED" -T '"x\n"' | wc -l
#       40
```

### A string that contains a slash gives a different error

```sh
X="/usr/bin/env true"; $X
# zsh: no such file or directory: /usr/bin/env true
x() { /usr/bin/env true "$@"; }; x
```

### The same line in each shell

```sh
zsh  -c 'list="a b c"; set -- $list; echo "n=$#"'    # n=1
bash -c 'list="a b c"; set -- $list; echo "n=$#"'    # n=3
zsh  -c 'set -- $(echo a b c); echo "n=$#"'          # n=3
```

## Related

- alycda/dotfiles, branch `agents/zsh-rule`: `tools/agents/rules/zsh-shell.md`,
  the always-loaded rule that section 6 asks for. It also covers globs that
  match nothing.
- The old checkout's
  `docs/solutions/developer-experience/claude-code-bash-tool-runs-zsh-bash-isms.md`
  covers three more zsh defaults. Two of them appeared in the same 2026-10-03
  session:
  - A glob that matches nothing is an error, and the command does not run:
    `ls -d ~/.dotfiles*` gave `(eval):1: no matches found`.
  - A colon after a variable name starts a modifier: `git show $C:tools/x`
    asked for `<commit>ools/x`, because `:t` is zsh's "tail" modifier. Write
    `"${C}:tools/x"`.
