# Instructions for Agents

## Tools: mise

[mise](https://mise.jdx.dev/) provides the tools, as listed in `mise.toml`.

- If a tool is missing, run `mise install`; it installs only what `mise.toml`
  lists. Run commands where mise is active, or prefix them with `mise exec --`.
- Get tools from mise, not from brew, `npm -g`, curl scripts or `mise use -g`.
  The repo has to work from its own `mise.toml`.
- `mise.toml` is kept minimal on purpose: ask before adding a tool, and add it
  with `mise use <tool>` so `mise.toml` stays the record.
- A tool that nothing requires is a micro change. Once a script or recipe
  depends on it, adopting means running `mise install`, which makes it meso.

## Tasks: HUID

Work is tracked in `tasks/<HUID>/TASK.md`; the format is in
[tasks/README.md](tasks/README.md). A task is the brief for the work and its
record afterwards.

- When given a HUID, read its `TASK.md` before anything else.
- Write back to the same file as you go, so the task keeps the provenance:
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

This repo is versioned with [EffVer](https://jacobtomlinson.dev/effver/).
`VERSION` holds the current version, and `CHANGELOG.md` has a section for each
one. The header of `CHANGELOG.md` defines the format; follow it exactly.

### Choosing the effort

The effort is what it takes to adopt the release on a machine already running
the previous version, not the effort it took to build. Decide it in order:

1. After pulling, does everything that worked before still work? Then it is
   **micro**, however large the change or the new optional features are.
2. If not, is getting back to working a bounded step, like installing a tool or
   an extension, or renaming a config key? Then it is **meso**.
3. Does it mean changing how you work, or redoing something? Then it is
   **macro**.

Opt-in additions are micro: what it costs to opt in goes in the changelog, not
the version. Watch for opt-in quietly becoming required (a setting that turns
something off, a recipe that loses its fallback); that makes it meso or macro.

In `0.x` the format is `0.MACRO.MICRO`: macro bumps the middle number, meso and
micro both bump the last. The label in the heading still records which.

### Rules

- Don't bump `VERSION` unless asked. When a change affects adoption, say which
  effort you think it is and why.
- The bump and its changelog heading belong in the release commit, not in the
  commits that make up the release.
- Each section says what changed. Unless it is micro, end it with a "To adopt:"
  line naming the steps.
- Don't edit the section of a version that has been released.
