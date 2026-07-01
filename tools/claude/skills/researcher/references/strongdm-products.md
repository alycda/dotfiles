# StrongDM Software Factory — Products

> Cached from https://factory.strongdm.ai/products
> Refresh manually with `--refresh` flag.

Useful components from StrongDM's Software Factory. **This skill is tool-agnostic** — these are listed for awareness, not as required dependencies.

## CXDB

Self-hosted context store for AI agents. Turn DAG, blob deduplication, dynamic types, and visual debugging.

**Relevance to this skill:** None at v0.1. The skill uses the local filesystem (`_docs/research/`, `_inspiration/`) as its context store. CXDB would be a v2+ substitution if the project outgrows filesystem-based research artifacts.

## StrongDM ID

Identity for humans, workloads, and AI agents with federated authentication and path-scoped sharing.

**Relevance to this skill:** None at v0.1. The skill assumes the user's local Hermes installation has whatever credentials it needs (web search API keys, etc.) configured already.

## Attractor

A non-interactive coding agent structured as a graph of phases. Runs end-to-end when the work is fully specified.

**Relevance to this skill:** Attractor (or its implementations — Fabro, Kilroy) is the **downstream consumer** of this skill's output. After Step 4 produces `_docs/research/index/`, the project has enough specification + prior art to be handed to a non-interactive coding agent.

This skill is **not** an Attractor implementation. It produces the artifacts an Attractor-like agent would consume.

### Attractor implementations to know about

- **Fabro** ([fabro.sh](https://fabro.sh/)) — open-source workflow orchestration with graph-based pipelines, verification gates, and Git checkpointing
- **Kilroy** ([github.com/danshapiro/kilroy](https://github.com/danshapiro/kilroy)) — local-first CLI for running Attractor pipelines in a git repo
