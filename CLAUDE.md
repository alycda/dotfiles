# Instructions for Agents

Terms in **bold** are defined in [CONCEPTS.md](CONCEPTS.md). Read it before
working here; these instructions don't repeat the definitions.

## Commits: ce-commit, in jj

Write commit messages by the compound-engineering `ce-commit` skill: one
logical change per commit, and a subject that names the outcome, not the files.
Match the recent log's `area(scope): summary` style.

This _may_ be a **colocated repository** worked with jj, so do not follow ce-commit's
git steps if a .jj folder exists:

- Don't run `git add`, `git commit`, `git checkout` or any other git command
  that writes. Reading with git is fine.
- Don't create a branch first. Describe the **working-copy change** with
  `jj describe -m "..."`, or `jj commit -m "..."` to start the next one.
- Split by concern with `jj split -m "..." <paths>`, never interactively.
- Never push. Publishing is the owner's call.

## Tools: mise

`mise.toml` is the **minimal toolset**.

- If a tool is missing, run `mise install`; it installs only what `mise.toml`
  lists. Run commands where mise is active, or prefix them with `mise exec --`.
- Get tools from mise, not from brew, `npm -g`, curl scripts or `mise use -g`.
  The repo has to work from its own `mise.toml`.
- Ask before adding a tool, and add it with `mise use <tool>` so `mise.toml`
  stays the record. Heavier tooling waits for the **full toolset** (Nix).

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
