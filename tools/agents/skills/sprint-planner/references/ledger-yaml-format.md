# `docs/sprints/ledger.yaml` — Format Reference

When `scripts/ledger.py`'s `parents[4]` resolver points at the wrong tree (skill installed globally, project not at the expected depth — see SKILL.md §3), edit the ledger file by hand instead. The format is deliberately a narrow subset of YAML so it stays human-writable.

## Skeleton

```yaml
sprints:
  - id: SPRINT-0001
    title: "Phase 1 — drift-inverse cron on GH Actions (<INTERNAL-TICKET>)"
    status: planned
    created: 2026-05-11T15:30:00+00:00
    updated: 2026-05-11T15:30:00+00:00
    branch: "alycda/<internal-ticket>-phase-1"
    worktree: "~/Work/DEVX/<INTERNAL-TICKET>-phase-1/"
```

## Field semantics

| Field | Required | Notes |
|---|---|---|
| `id` | yes | `SPRINT-NNNN` (4-digit zero-padded). Next id = max(existing) + 1. |
| `title` | yes | ≤ 60 chars, quoted if it contains a colon. |
| `status` | yes | `planned` \| `in-progress` \| `done` \| `abandoned`. |
| `created` | yes | ISO 8601 UTC timestamp. |
| `updated` | yes | ISO 8601 UTC timestamp. Bumped on every field change. |
| `executor` | no | `opus` \| `gpt-5.5` \| `gemini`. Set by `sprint-execute`. Omit when not set. |
| `branch` | no | Linear-formatted branch (e.g. `alycda/devx-NNN-...`). Empty string OK if not yet known. |
| `worktree` | no | Absolute or relative path to the sibling worktree. Tilde-prefixed paths supported. |

## Quoting rules (matching `_yaml_escape` in `ledger.py`)

- Empty strings → `""`
- Strings containing `:`, `#`, `"`, `'`, newline → quoted with `\\` and `\"` escapes
- Strings with leading/trailing whitespace → quoted
- Everything else → bare (no quotes)

## Order-of-fields convention

The script writes fields in this order: `id, title, status, executor, branch, worktree, created, updated`. Hand-edits should preserve order so diffs stay readable.

## Idempotent updates

When patching by hand, treat the entry as upsert-by-id: keep all existing fields, modify only what's changing, bump `updated`. Don't reorder or drop fields the script may write later.
