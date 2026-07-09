# daily-ticket-status-drafts

Weekday task: draft meaningful Linear status comments for Alyssa's active
tickets, for individual approve/deny before anything posts. This is the first
Cowork scheduled task migrated to a runtime-agnostic harness, run as an A/B
against the still-enabled Claude Cowork incumbent until 2026-09-01.

Plan: `agentic-migration/docs/plans/2026-07-09-001-feat-ticket-drafts-ab-harness-plan.md`
(private corpus). Origin requirements and ideation live alongside it.

## How it works

- `ticket-drafts-run` invokes `codex exec` (read-only sandbox, schema-validated
  output) to draft comments from Linear + Google Calendar via codex's own
  connectors. The agent's only output channel is its final message; the wrapper
  writes all outbox records. Runs are **default-red**: green requires drafts or
  an evidence-carrying skip record.
- Drafts land as one JSON record per file in
  `~/.agents/outbox/daily-ticket-status-drafts/` (`<date>-<ticket>-<runid>.json`),
  state machine: `pending → approved → posted`, with `denied`, `spiked`
  (expired), `superseded` (re-drafted same day), and `post_failed` (retryable).
- `ticket-drafts-review` is the **only** posting path. It holds the Linear API
  key (agenix, mode 0400), shows each pending draft for approve / edit / deny,
  warns on cross-arm duplicates before posting, posts idempotently (frozen
  approved text + attempt marker + read-before-retry), and appends every
  decision to `decisions.jsonl`.

## Outbound-comment-gate alignment

This harness is the codex-side implementation of the outbound comment gate
(`tools/claude/rules/outbound-comment-gate.md`): nothing posts without an
explicit per-draft human approval, enforced by credential separation — the
drafting agent never holds the posting credential, and `hooks/` adds a
mechanical PreToolUse deny on Linear mutations (see below).

## Setup (once per machine)

1. Real prompt: `agenix -e secrets/personal/ticket-drafts-prompt.age`
   (replace the sentinel placeholder; content = adapted Cowork SKILL.md steps
   + comment-patterns.md style guide; scripts refuse to run on the placeholder).
2. Linear key: mint a personal API key (Linear → Settings → API), then
   `agenix -e secrets/personal/linear-api-key.age` (single line, no quotes).
3. Hook gate: install and trust `hooks/never-post-linear.json` per the
   comments in that file (codex requires interactive trust of the exact hook
   definition once; re-trust on any change — tamper-evident by design).
4. Without a darwin-rebuild the scripts still work: they fall back to
   `rage -d -i ~/.age/personal-key.txt` against this repo's ciphertexts. After
   activation (home-manager module `agent-tasks.nix`), secrets resolve from
   `~/.local/share/agenix/` and the scripts are on PATH.

## Running

```sh
just ticket-drafts             # daily batch (F1)
just ticket-drafts-one SDKS-1234   # single ticket, skips daily gates (F2)
just ticket-drafts-review      # review, approve/edit/deny, post (F3)
ticket-drafts-run --dry-run    # validation mode: auth + context, no pending drafts
```

Manual invocation is deliberate for v0; the launchd/home-manager scheduler is
a later increment (see plan Scope Boundaries).

## A/B notes

- The Cowork task stays enabled and untouched; comparison is the daily review
  plus `decisions.jsonl` (approve/edit/deny + draft-vs-posted deltas).
- Run records note whether the hook gate was active (`hook_gate_active`) so
  arm provenance stays clean.
- A red run (auth, connector, rate-limit, timeout, malformed-output,
  incomplete, evidence-free-skip, placeholder-secret) is an
  arm-unavailability datapoint, never a draft-quality datapoint.

## Local-plaintext doctrine

Per `tools/agents/README.md`: prompts are local plaintext delivered via the
agenix overlay, never a URL an agent is told to fetch. The committed `.age`
files are sentinel placeholders; real content exists only encrypted here and
decrypted on machines holding the age identity. Runtime records under
`~/.agents/outbox/` contain work-internal text — they stay machine-local.
