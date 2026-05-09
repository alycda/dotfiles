# Decomposition Heuristic — Linear Ticket → Sprint Manifest

Maps a fetched Linear ticket (with or without subissues) into a manifest of sprint-sized work units. The heuristic is **conservative by default** — when in doubt, ask the user rather than guess.

## Core rule

**A subissue is sprint-sized when its estimate is ≥ 3 story points.** Smaller subissues batch together; larger ones stand alone.

This rule is calibrated against the user's typical pattern: per-SDK FFI work where 3+ point tickets carry their own contract, holdouts, and validation matrix; 1-2 point tickets are shaped more like "apply X across Y SDKs" follow-ups that bundle naturally.

## Decomposition table

| Subissue shape | Sprint placement | Notes |
|---|---|---|
| Estimate ≥ 3, single SDK | Standalone sprint | One sprint per ticket |
| Estimate ≥ 3, cross-SDK / no SDK label | Standalone sprint, mark `cross-sdk: true` in manifest | Sprint may span multiple SDK target dirs |
| Estimate 1-2, single SDK | Batch with other small subissues into a multi-ticket sprint, grouped by theme | See "Batching small subissues" below |
| No estimate | Flag to user; default = standalone pending confirmation | Don't guess. Better to pause than mis-size. |
| Has `blocks`/`blockedBy` to other subissues | Sprint dependencies derived from Linear graph | Honored as kanban `blocked_by` edges in manifest |
| Sub-subissues (Linear nested children) | Recurse: a sub-subissue becomes its own row in the parent subissue's "sprint contents" | Limit recursion depth at 2; flag deeper to user |
| Parent ticket only (no subissues) | Single-sprint manifest | Degenerate case — one sprint, contents = the parent itself |
| Parent ticket marked "epic" or label includes `epic` | Each direct child is at least its own sprint candidate | Don't batch across epic children even if estimates are small |

## Batching small subissues

When grouping 1-2 point subissues into a multi-ticket sprint, use this priority order:

1. **Cross-SDK uniformity** — if N subissues are all "do X for SDK Y", batch by X (one sprint covers `do X for SDKs A,B,C,D,E,F`). The user explicitly favors this: 1-2 point tickets across multiple SDKs handled in a single sprint rather than stacked.
2. **Shared theme / component** — subissues with similar labels (e.g., all `area:transport`, all `area:auth`) batch together.
3. **Acceptance criteria overlap** — subissues whose descriptions reference the same test scaffolding, the same API surface, or the same migration step.
4. **Fall-through batching** — if no above grouping applies, batch by parent ticket (all small subissues of the same parent become one "small-tickets" sprint).

A batched sprint's title should describe the unifying property, not list every ticket: "Apply FFI callback contract across SDK shims" beats "SDKS-3482, SDKS-3483, SDKS-3484, SDKS-3485, SDKS-3486, SDKS-3487".

## Estimate handling

Subissues without estimates are the most common ambiguity. Three resolution paths:

1. **Ask the user inline** — present the unestimated subissues, ask the user to estimate or mark "skip from manifest"
2. **Auto-skip** — exclude unestimated subissues from the manifest, surface them as "deferred for sizing"
3. **Default-to-standalone** — treat as estimate=3 (the threshold), promote to standalone sprint with a flag

Default behavior: option 1. If user passes `--auto-skip-unestimated`, fall through to option 2.

## SDK target detection

Many subissues encode SDK targets in their title or labels. Recognize the common patterns:

| Pattern | Target |
|---|---|
| Title contains "Flutter" or "flutter-sdk" | `flutter` |
| Title contains "Kotlin", "JVM", "Android" | `jvm` |
| Title contains "Swift", "iOS", "macOS" | `swift` |
| Title contains "JS", "Node", "wasm", "WebAssembly" | `js` |
| Title contains "Go", "golang" | `go` |
| Title contains "Python", "pyditto" | `python` |
| Title contains "Rust core", "ditto-core", "libdittoffi" | `rust-core` |
| Title contains "C++", "cpp" | `cpp` |
| Title contains "C ", "C-" (word-boundary), "kitchen sink" | `c` |
| Label `area:flutter` | `flutter` |
| Label `area:jvm` | `jvm` |
| (etc.) | (etc.) |

If no SDK target is detectable, set `sdk_targets: []` and let the user fix it during manifest review.

## Dependency graph extraction

Linear's relationship types worth honoring:

| Linear relation | Manifest field | Behavior |
|---|---|---|
| `blocks` / `blockedBy` | `blocked_by` array on each sprint | Becomes a `kanban_link` edge from upstream's retro to downstream's plan |
| `relatesTo` | `related_to` array, informational only | Surfaced in plan task body but not enforced as ordering |
| `duplicateOf` | Skip the duplicate from manifest | Mark as deduped in audit log |
| Parent / child (the decomposition itself) | Implicit | Already handled by traversal |

If a subissue is blocked by another **outside** the parent's subtree, surface that as an external dependency in the manifest and warn the user — sprinter cannot honor cross-tree dependencies via kanban links because the upstream sprint isn't in this manifest's task graph.

## When to refuse decomposition

Sprinter should refuse and surface to user (rather than try to guess) when:

- Parent ticket has zero subissues AND no description / acceptance criteria — too vague to plan
- All subissues are unestimated AND `--auto-skip-unestimated` was not passed
- Parent ticket is in a state like `cancelled` / `duplicate` — likely not real work
- The dependency graph contains a cycle — Linear allows it, kanban links don't
- Parent ticket spans more than 2 nested levels of subissues — Linear allows nesting, but sprinter caps at depth 2 to keep manifests reviewable

In each case, present the issue, suggest the corrective action, and let the user decide whether to proceed with a reduced scope.

## Output: the manifest

The output of decomposition is a `sprint-manifest.yaml` (see `templates/sprint-manifest.example.yaml`). The user reviews it before any kanban tasks get created. Manifest structure is intentionally human-editable — users can rebalance batches, override SDK targets, add `blocked_by` edges, or remove sprints before approval.
