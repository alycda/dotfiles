# hermes-boxed — containerized Hermes stack (2012 MBP, 2026-07-27)

Everything Hermes runs in this compose: gateway+dashboard (one container,
HERMES_DASHBOARD=1), workspace UI, and the isolated `draft` one-shot runner.
Native launchd services are retired. See HANDOVER.md in the ledger repo for
the full architecture (broker, MCP, containment rationale).

- state/          — HERMES_HOME (config.yaml, .env with secrets, skills, logs) — NOT tracked
- workspace.env   — workspace secrets (HERMES_API_TOKEN == state API_SERVER_KEY) — NOT tracked
- Broker (host): ~/ledger-broker/broker.py, launchd com.alyssa.ledger-broker, 127.0.0.1:8643
- Artifacts: containers write /artifacts -> iCloud/Hermes -> Obsidian
- Draft runner: /ledger ro + /ledger/import rw, own network (untrusted PDF input)

Intended dotfiles capture (issue #40 shape): this compose + the ledger skill
+ curated skill surface; secrets provisioned per-machine.
