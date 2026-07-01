# Changelog

All notable changes to the `c4-design` skill.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] — 2026-05-21

### Added

- Initial skill scaffold. Closes the gap between planning artifacts (`STRATEGY.md`, `SEED.md`, ce-plan output, `RESEARCH-BRIEF.md`) and a Likec4 architectural dashboard — *before* code is written.
- Four-step procedure: Interview → Draft DSL → Render and Iterate → optional Drift Check.
- `references/prompt-0-interview.md` — interview script for the four things plan docs leave implicit (external actors, system boundary, containers, key components).
- `references/prompt-1-draft-dsl.md` — translation procedure from planning docs + interview output to Likec4 DSL.
- `references/prompt-2-iterate.md` — render + review + iterate loop.
- `references/prompt-3-drift-check.md` — diff `model.c4` against `understand-anything`'s `knowledge-graph.json` once code exists.
- `references/likec4-syntax-primer.md` — quick reference for Likec4 DSL with pointer to canonical docs.
- `templates/model.c4.template` — Likec4 skeleton with `specification`, `model`, and `views` blocks pre-stubbed.
- `scripts/build-dashboard.sh` — wraps `npx @likec4/cli build` with default project layout.

### Notes

- Positioned downstream of `ce-strategy` / `ce-plan` and upstream of code + `understand-anything`. Different artifact, different lifetime.
- The DSL is the source of truth; never hand-edit the built dashboard.
- Likec4 chosen over Structurizr because: (a) MIT OSS, (b) generates an interactive dashboard out of the box (closer to Understand-Anything's UX than Structurizr's flat SVGs), (c) Mermaid/PlantUML escape hatches for embedding in docs.
- Step 3 (drift check) is optional and only runs if `understand-anything` has been used on the (now-existing) code. Without it, the skill stops cleanly at Step 2.
