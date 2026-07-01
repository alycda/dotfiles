# Step 3 — Drift Check (Optional, Post-Build)

Compares the planned `docs/c4/model.c4` against the built code's `docs/understand/knowledge-graph.json` (produced by [Understand-Anything](https://github.com/Lum1104/Understand-Anything)) and surfaces drift.

**Skip this step entirely if** `understand-anything` has not been run on the project. The skill should error out with the install link rather than fake a drift check.

## When to Run

- After substantial code has been written from the design (typically end of a sprint or major feature)
- Before merging large refactors that might restructure containers or components
- Periodically during long-running projects (the C4 model is rarely stale on day 1, often stale by month 6)

## Prerequisites

```bash
# Verify the knowledge graph exists
test -f docs/understand/knowledge-graph.json || { echo "Run 'understand-anything' first: https://github.com/Lum1104/Understand-Anything"; exit 2; }

# Verify the C4 model exists
test -f docs/c4/model.c4 || { echo "No C4 model at docs/c4/model.c4 — nothing to compare against."; exit 2; }
```

## Procedure

### 3.1 — Extract Planned Elements from `model.c4`

Parse `docs/c4/model.c4` and produce a structured set:

- `planned_containers`: list of container IDs and display names
- `planned_components`: list of (container_id, component_id) pairs and display names
- `planned_edges`: list of (from_id, to_id, label) tuples
- `planned_external_systems`: list of external system IDs

(Likec4 doesn't currently export this as a CLI dump; either parse the DSL directly via regex or shell out to `npx @likec4/cli generate json` if your Likec4 version supports it.)

### 3.2 — Extract Built Structures from `knowledge-graph.json`

Read `docs/understand/knowledge-graph.json`. Map its concepts to C4 levels:

- **Container** ≈ Understand-Anything's "architectural layer" or top-level directory (e.g., `web/`, `api/`, `worker/`)
- **Component** ≈ Understand-Anything's "module" / "class" cluster within a layer
- **External system** ≈ Understand-Anything's "external dependency" nodes (npm packages, API clients, etc.) when they correspond to known external services

Produce:

- `built_containers`: top-level architectural layers/directories
- `built_components`: clustered modules within each layer
- `built_dependencies`: edges between layers and to external services

### 3.3 — Diff

Compute four sets:

| Set | Definition | Interpretation |
|---|---|---|
| **Planned not built** | `planned_containers - built_containers` (+ same for components) | Architecture defined but not implemented yet. Could be in progress (fine) or abandoned (model is stale). |
| **Built not planned** | `built_containers - planned_containers` | Code structures that weren't in the original design. Drift — either update the model (architecture evolved correctly) or refactor the code (architecture is degrading). |
| **Dependency added** | `built_dependencies - planned_edges` | New dependencies introduced during implementation. May indicate emergent integration or unwanted coupling. |
| **Dependency missing** | `planned_edges - built_dependencies` | Designed dependencies not yet wired. Often fine (work in progress), sometimes signals a feature wasn't implemented. |

### 3.4 — Report

Produce `docs/c4/drift-report.md` with:

- A summary table of counts in each set
- A per-item list under each set, sorted alphabetically
- For each "Built not planned" item, a suggested DSL snippet to add to `model.c4` so the user can copy-paste if they accept the drift
- For each "Planned not built" item, a "still planned?" question for the user

Surface the report path to the user:

> *"Drift report at `docs/c4/drift-report.md`. Review the four sections; for each item under 'Built not planned' or 'Dependency added', decide: (a) update `model.c4` to reflect the new reality, or (b) refactor the code back toward the planned architecture. Then rerun `/c4-design render` to see the updated dashboard."*

## Output

`docs/c4/drift-report.md` — markdown report with the four diff sets.

## Verification

- The report file exists
- All four diff sets are populated (even if empty)
- Counts in the summary table match the per-item list lengths
- The user has reviewed the report and chosen a path forward for each drift item

## Pitfalls

- **Treating drift as automatically bad.** Some drift is healthy — emergent architecture often improves on the planned one. The drift report is a prompt for the user to *decide*, not a rebuke.
- **Knowledge graph and C4 model use different vocabularies.** Understand-Anything talks about "layers" and "modules"; C4 talks about "containers" and "components". The mapping is heuristic, not exact. Surface ambiguous matches as questions to the user rather than auto-mapping.
- **Path-based mapping breaks on monorepos.** A `packages/web/`, `packages/api/`, `packages/shared/` layout may map cleanly to containers, but a flat src/ tree probably won't. If the heuristic fails, fall back to asking the user to annotate which top-level directories map to which containers.
- **External-system matching by name is fragile.** Stripe might appear in `knowledge-graph.json` as `stripe`, `stripe-js`, `@stripe/stripe-node`, etc. Use substring matching but surface ambiguous matches.
- **Rebuilding the dashboard isn't part of Step 3.** Step 3 only reports drift. Updating the model is a Step 2 operation; the user explicitly rerunds `/c4-design render` or `/c4-design iterate` after deciding on each drift item.
