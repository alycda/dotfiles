# Step 1 — Research Brief

Produces `RESEARCH-BRIEF.md` at the project root.

## The Original Prompt (subject to user modifications)

> Look at our [IDEA.md, SEED.md, README.md]. Write a research brief which will instruct a deep research agent to identify all useful prior art, especially arxiv.org papers, git repos, product documentation and other authoritative sources.

## Procedure

1. Read `SEED.md` (or `IDEA.md` / `README.md` — whichever exists).
2. Read the exemplar at `references/exemplar-research-brief.md` for structure (Gene Transfusion).
3. Draft a brief with the following sections:
   - **Project Summary (read first)** — minimal context the researcher needs, with concrete technical anchors. Extract from SEED; do not paste the whole seed.
   - **Research Tasks** — numbered, scoped topics (typically 5–10), each with sub-bullets pointing at specific tools, repos, papers, people to investigate. For each task: what to find, what to skip, named adjacent prior art the researcher should NOT re-discover.
   - **Required Deliverables** — exactly what the researcher must return. Typically: Top N must-reads (with annotations), per-topic findings (each with "what it gives us" + "gap" lines), tool shortlist (with maintenance health), reference architectures (with file paths to mimic), open research questions, source ledger (flat URL list).
   - **Constraints on the search** — authoritative > popular, recency rules, "don't pad", licensing landmines.
   - **Scope guardrails (don't bother)** — explicit "don't research X" list to prevent budget waste.

### External-Safe by Default

The brief should be runnable through any deep-research provider (Anthropic, Codex, Gemini, etc.) without leaking project specifics. **Strip or generalize** before output:

- Internal ticket IDs (Linear, Jira) → replace with generic descriptions ("an SDK integration ticket", not "PROJ-1234")
- Customer names → replace with generic personas ("a Flutter customer", not literal company names)
- Internal incident IDs → replace with technical phenomenon descriptions ("a TransactionTooLarge disconnect loop", not "i-604")
- Unreleased product names → use the public name or the technical category
- Proprietary architecture specifics that aren't already public → describe by behavior, not internal naming

If the user explicitly wants internal anchors preserved (because the prior art search genuinely depends on them), record this as `internal_only: true` in the brief's frontmatter. Step 1.5 will refuse to dispatch to non-Anthropic providers when this flag is set.

The default output should pass an "external-safe" check: would I be comfortable if this brief showed up on a public repo? If no, sanitize.

## Inputs

- `SEED.md` (or equivalent at project root)
- `references/exemplar-research-brief.md` (structural exemplar)

## Output

`RESEARCH-BRIEF.md` at project root. Will be consumed by parallel sub-agents in Step 1.5.

## Verification

A good brief:

- Names primary sources to investigate (specific repos, papers, projects), not just topics
- Tells the researcher what's adjacent vs. what to skip
- Specifies deliverable structure tightly enough that multiple researchers produce comparable outputs
- Has a "Scope guardrails (don't bother)" list calling out things that look adjacent but waste research budget

## Pitfalls

- **Too much project context.** The researcher needs minimal context. Don't paste the whole SEED — extract the technical anchors.
- **Topic-only tasks.** "Research CRDTs" is bad. "Find arxiv papers on CRDT correctness testing by Shapiro, Preguiça, Burckhardt, Kleppmann" is good.
- **Ambiguous deliverables.** If the deliverable shape is unclear, three researchers will produce three incompatible documents and Step 2 (download manifest) becomes harder.
- **Missing the source ledger requirement.** Step 2 depends on a flat URL list at the end of each researcher's output. If the brief doesn't require one, Step 2 has to scrape URLs out of prose.
