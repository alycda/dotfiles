---
name: cheat-memory
description: >
  Look up and record exact shell command syntax with the `cheat` tool. Use BEFORE running any
  command whose flags you are not certain of — jj, git, nix, gh, crush, docker, agenix, just —
  by running `cheat -l | grep <topic>` instead of guessing. Use AFTER a command is verified
  working to write a short sheet into the inbox, so the next session and Alyssa do not have to
  rediscover it. Trigger on "how do I run", "what's the flag for", "I always forget", "write
  that down", "remember this", "add a cheatsheet", and on any command that had to be corrected
  before it worked. Sheets are shared: Alyssa reads the same store from her terminal.
allowed-tools: Bash(cheat *), Bash(mkdir -p *), Read, Write
---

# cheat-memory

`cheat` is shared command memory. Alyssa reads the same sheets from her terminal that you
read here, which is the whole reason this store exists rather than another docs folder.

Two moves. **Look up before guessing. Write down after verifying.**

## Look up

Before running a command whose exact syntax you are unsure of:

```bash
cheat -l | grep -i <topic>   # is there a sheet? lists name, tags, path
cheat <sheet>                # read it, e.g. cheat jj/rebase
cheat -s <phrase>            # search sheet CONTENTS when the name isn't obvious
```

Prefer the sheet over your own recall. These sheets were verified on this machine and
carry pinned versions; your training data was not and does not. When a sheet and your
memory disagree, the sheet wins — unless running the command proves the sheet wrong, which
is itself a thing to write down.

No sheet exists? Carry on as normal, then consider writing one.

## Write down

Write a sheet only when **all three** hold:

1. You ran it and saw it work — or saw the failure the sheet will warn about.
2. Getting it right took more than one attempt, or contradicted the obvious guess.
3. It will come up again. Not a one-off for this repo's current state.

Sheets go in `~/.cheat/inbox/<tool>/<task>` — the only writable cheatpath. It is a
quarantine, not the library: Alyssa promotes sheets into `community/` or `personal/` after
review. Do not write into those two; they are read-only nix store paths and the write
fails.

```bash
mkdir -p ~/.cheat/inbox/<tool>
# then write the file at ~/.cheat/inbox/<tool>/<task>
```

## Sheet format

Plain text, one screen or less. Comment lines explain; bare lines are commands to copy.

```
# One line: what this is for and when it applies.
# Verified: <the command that proved it> (<tool> <version>)

# To <do the thing>:
<command>

# To <do the variant>:
<command>
```

Rules:

- Every sheet carries a `# Verified:` line naming what proved it. No verification, no sheet.
- Commands, not prose. A paragraph of reasoning belongs in a skill, not a cheatsheet.
- Name sheets `<tool>/<task>` — `jj/rebase`, `nix/gc`, `crush/skills`. Match the names
  already in `cheat -l`.
- One topic per sheet. Never append to a sheet you did not verify yourself.
- `cheat -s <keyword>` first. Correct an existing sheet rather than duplicating it.

## Not for cheatsheets

- Reasoning, hazards, and mental models — those go in a skill. `jj` command syntax is a
  cheatsheet; "jj auto-snapshots everything, so check .gitignore before generating files"
  is the jujutsu skill's job.
- Anything you did not actually run.
- Secrets, API keys, tokens. Reference `$VAR`, never a literal.
- Absolute paths specific to one machine.

## Reviewing the queue

```bash
cheat -l -t unverified   # everything sitting in the inbox
```

Where a live dotfiles checkout exists the inbox is a symlink into it, so anything you write
shows up in `jj status` and gets reviewed like any other change. Say so when you write one —
it is a file in her repo, not a private note.
