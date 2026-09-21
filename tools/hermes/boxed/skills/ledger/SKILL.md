---
name: ledger
description: Beancount ledger operations — status, ingest, drafting, and approving statement drafts — via the ledger MCP tools. Use whenever Alyssa asks about her ledger, finances, statements, paystubs, drafts, reconciliation, or says "approve".
---

# Ledger Operations (boxed agent)

You run inside a container with NO shell access to the ledger or the host.
All ledger operations go through the `ledger` MCP server's tools; all
browsing goes through read-only fava. Do not attempt filesystem paths like
/Users/alyssa/ledger — they do not exist here.

## Tools (MCP server `ledger`)

- **ledger_status** — bean-check state, pending drafts, inbox, recent
  activity, git log. Start here for any "how's the ledger" question.
- **ledger_check** — bean-check the live ledger. This is the ONLY valid way
  to verify ledger math. NEVER verify amounts with your own arithmetic.
- **ledger_ingest** — start the inbox pipeline in the BACKGROUND (new PDFs →
  classify → auto-draft → gate → Signal notify). Returns immediately; don't
  wait — check ledger_status after the Signal notification.
- **ledger_draft** {file} — start a background draft for one staged PDF.
  Same async pattern: takes minutes, result appears in ledger_status.
- **ledger_read_import** {file} — read staged text from import/: extracted
  statement text (`<pdf>.txt`), drafts (`*.draft.beancount`), sidecars. THIS
  is how you read statement contents (APRs, terms, due dates, line items) —
  the PDFs themselves aren't served, their .txt extracts are.
- **ledger_approve** {name} — approve a clean draft by PDF basename. The
  host executes the draft's PLAN with bean-check + git-revert rails and
  refuses REVIEW_NEEDED drafts — those need Alyssa herself (fava :5000 or
  the M4); tell her so instead of retrying.

## Fava

- **http://host.docker.internal:5001** — read-only fava. Use for browsing,
  queries, reachability checks.
- :5000 is the read-write instance, basic-auth protected, HUMAN-ONLY. Never
  request it.

## Deliverables

Any report, summary, or document you produce for Alyssa: write it as
markdown into **/artifacts/** (synced to her Obsidian via iCloud). Use
dated, descriptive filenames (e.g. `2026-07-31 ledger month-close.md`).
Never scatter output files anywhere else.
