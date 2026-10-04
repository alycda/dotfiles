# Instructions for Agents

Terms in **bold** are defined in [CONCEPTS.md](CONCEPTS.md). Read it before
working here; these instructions don't repeat the definitions.

## Commits: commit-craft, in jj

Every commit message follows the `commit-craft` skill
(`.claude/skills/commit-craft/SKILL.md`, linked from `.agents/skills/`). Read
it before writing or changing a message, in any harness, even when skills are
not loaded for you. It replaces compound-engineering's `ce-commit` here: the
body is required, and `check-commit-msg` must pass before a message is set.

This _may_ be a **colocated repository** worked with jj. If a .jj folder exists:

- Don't run `git add`, `git commit`, `git checkout` or any other git command
  that writes. Reading with git is fine.
- Set a message from a file: `jj describe --stdin < msg.txt`. Split by
  concern with `jj split -m "..." <paths>`, never interactively.
- Before asking for a push, run `check-commits --jj '<revset>'` on the
  changes you made. Pass the revset: the default reaches back to history
  older than this format. Never push; publishing is the owner's call.
- The owner moves around while you work (`jj edit`, `new`, `rebase`,
  `abandon`). Never assume `@` is where you left it: read `jj st`, `jj log`
  or `jj op log` before you write. A hook (`tools/agent/jj-state`) adds what
  moved to your prompt, and blocks a write once if you have not looked since.

## Tools: mise

`mise.toml` is the **minimal toolset**.

- If a tool is missing, run `mise install`; it installs only what `mise.toml`
  lists. Run commands where mise is active, or prefix them with `mise exec --`.
- Get tools from mise, not from brew, `npm -g`, curl scripts or `mise use -g`.
  The repo has to work from its own `mise.toml`.
- Ask before adding a tool, and add it with `mise use <tool>` so `mise.toml`
  stays the record. Heavier tooling waits for the **full toolset** (Nix).

## Shell: zsh

Commands sent through the Bash tool run in the login shell, which is zsh on
these machines. Write them for zsh, not bash. A script with a shebang runs in
the shell it names, so this is only about commands you type.

- An unquoted `$VAR` is one word. Don't keep a command in a string
  (`J="jj --no-pager"; $J log`). Write a function
  (`j() { jj --no-pager "$@"; }`) or an array
  (`j=(jj --no-pager); "${j[@]}" log`).
- `for x in $str` and `set -- $str` don't split either, and raise no error.
  Loop over an array or over `$(command)`.
- A glob that matches nothing is an error, and the command does not run. Quote
  every argument with `?`, `*` or `[` that the shell should not expand.
- Write `"${VAR}:path"`, not `$VAR:path`. A colon after the name starts a
  modifier.
- For anything that needs bash, use `bash <<'EOF' ... EOF`.

The reasons and examples are in the
[solution doc](docs/solutions/developer-experience/zsh-does-not-word-split-command-in-a-string.md).

## Tasks: HUID

Each **task** is `tasks/<HUID>/TASK.md`; the file format is in
[tasks/README.md](tasks/README.md).

- When given a **HUID**, read its `TASK.md` before anything else.
- Write back to the same file as you go:
  - `## Open questions`: what you need decided, and what you assumed
    meanwhile.
  - `## Verification`: how you checked the work, with the commands, and what
    you could not check.
- Set `STATUS: CLOSED` only when everything under `## Verification` passed.
  Otherwise leave it `OPEN` and say what is left under `## Open questions`.
- Create a task with `just task "Title"`, never by writing a HUID by hand: the
  recipe handles collisions. Don't rename task directories; the HUID is the ID.
- Repo work goes in `tasks/`, not in taskbook (`tb`) or other trackers.

## Versioning: EffVer

`VERSION` holds the current version, and `CHANGELOG.md` has a section for each
**release**. The header of `CHANGELOG.md` defines the format; follow it exactly.

- Don't bump `VERSION` unless asked. When a change affects adoption, say which
  **effort** you think it is and why.
- The bump and its changelog heading belong in the **version commit**.
- Each section says what changed. Unless it is micro, end it with a "To adopt:"
  line naming the steps.
- Don't edit the section of a version that has been pushed to an immutable head.
