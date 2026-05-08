# Step 4 — Semantic Index

Builds `docs/research/index/` from `inspiration/`.

## The Original Prompt (subject to user modifications)

> Construct a semantic index of our research materials. The inspiration/ directory contains all known prior art for our project; however, the token volume is very large. Construct docs/research/index/ as a semantic index: topics, citations, cross-references, bookmarks, tags, clusters, themes — anything which will aid a future coding agent in quickly locating the most dense and useful aspects of our prior art materials. Be sure to use sub-agents for each project — think MapReduce.

## Procedure

### 4.1 — Map: Per-Source Sub-Agents

Spawn one sub-agent per top-level item in `inspiration/` (each repo, each paper, each article). Each sub-agent reads its assigned material and produces a structured summary at `docs/research/index/_per_source/<source-id>.md` containing:

- 3-sentence elevator summary
- Tags (free-form, lowercase, hyphenated, ≤10)
- Topics covered (numbered list)
- Key citations (with page/line refs where available)
- Cross-references to other sources (by source-id) when explicit
- "Density" score 1–5 (5 = read this first; 1 = barely relevant)
- "What we'd take from this for our project" — 1–3 bullets

### 4.2 — Reduce: Cross-Source Aggregation

Once all per-source summaries exist, run aggregation (single sub-agent or inline) to produce:

| File | Contents |
|---|---|
| `docs/research/index/by-topic.md` | Topics → list of sources covering them, sorted by density |
| `docs/research/index/by-tag.md` | Tags → list of sources |
| `docs/research/index/clusters.md` | Thematic clusters (e.g., "ABI diffing tools", "WASM browser test runners", "CRDT theory papers") |
| `docs/research/index/top-N.md` | Top 10–20 must-read sources by density (deduplicated, ranked) |
| `docs/research/index/cross-references.md` | Graph-shaped: source A cites source B with `<context>` |
| `docs/research/index/open-questions.md` | Things prior art doesn't answer; gaps where the project will have to invent |
| `docs/research/index/README.md` | Entry point for downstream agents; explains the index structure |

### 4.3 — Surface Open Questions

Aggregate "things the prior art doesn't answer" across all sources. Write `docs/research/index/open-questions.md`.

## Inputs

- `inspiration/` (everything)
- `docs/research/<researcher-id>.md` (for high-level Top N hints from researchers)
- `docs/research/downloads.yaml` (for source-id → path mapping)

## Output

```
docs/research/index/
├── README.md                 # entry point
├── by-topic.md
├── by-tag.md
├── clusters.md
├── top-N.md
├── cross-references.md
├── open-questions.md
└── _per_source/
    ├── <source-id>.md
    └── ...
```

## Verification

- One `_per_source/<id>.md` per top-level item in `inspiration/`
- `top-N.md` lists at least 10 sources with density scores
- `clusters.md` covers all sources (no "uncategorized" stragglers)
- `README.md` orients a downstream agent that has zero prior context

## Pitfalls

- **Skipping the Reduce phase.** Per-source summaries alone are not an index — they're a flat directory. Cross-source aggregation is where the value comes from.
- **Token explosion in Reduce.** Don't read all per-source files into a single context. Pyramid Summary: read elevator summaries + tags + density scores; expand specific sources only when needed.
- **Density score inflation.** If every source scores 4–5, the score is useless. Force a distribution (e.g., max 20% can be 5).
- **Hallucinated cross-references.** Agents will invent citations between papers that don't actually cite each other. Verify against actual content.
- **Stale index after re-runs.** If new researchers stream in (and prompts 2–3 download new materials), the index needs to be regenerated. Use the `--rebuild` flag. Don't try to incrementally patch.
- **MapReduce parallelism.** Map phase is embarrassingly parallel; spawn one sub-agent per source. Reduce phase is serial by necessity. Don't try to parallelize Reduce.
