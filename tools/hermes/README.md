# Hermes — boxed stack (2012 MBP)

Captured 2026-07-27 from the live deployment on `Alyssas-MBP-12` (Catalina,
non-nix — the container boundary IS this machine's substitute for nix-managed
config). Decision of record: **less trust now** — the agent runs fully
containerized with no host shell; go native again only if/when agent trust
warrants raw power (computer control etc.).

## Layout

- `boxed/` — the `~/hermes-boxed/` compose unit: gateway+dashboard container
  (one container; `HERMES_DASHBOARD=1` — separate containers deadlock on the
  shared state's s6 log locks), workspace UI (docker runtime; the old
  native-node path was only a Catalina *build* workaround), and the isolated
  `draft` one-shot runner (`/ledger` ro, `/ledger/import` rw, own bridge
  network — it consumes untrusted PDF text). `state/` and `workspace.env`
  are secrets/runtime and never tracked; `*.env.example` documents the keys.
- `boxed/skills/ledger/` — the boxed ledger skill: all ledger operations via
  the host MCP broker's five verbs; read-only fava for browsing; deliverables
  to `/artifacts` (iCloud → Obsidian) only.
- `mbp12-host/` — the host-side privilege boundary and pipeline:
  - `ledger-broker/` — stdlib-python MCP server (127.0.0.1:8643, bearer
    token) exposing exactly ledger_status/check/ingest/draft/approve.
  - `ledger-ingest/` — inbox watcher pipeline: classify → contained
    bookkeeper draft → bean-check gate → git commit → Signal notify;
    `approve.sh` = host-side fixed-prompt one-shot with revert rails.
  - `signal-cli/` — dockerized signal-cli daemon (Temurin 25), state
    bind-mounted for offline sync; loopback :8080.
  - `launchd/` — the two host LaunchAgents (broker, inbox watcher).

## Not tracked (per-machine provisioning)

Venice key, API_SERVER_KEY/HERMES_API_TOKEN pair, HERMES_PASSWORD, Signal
account/state, broker token, tailscale/cloudflared credentials.

## Skills — pruned to 6 (2026-07-28)

The gateway prompt was carrying **~11,320 tokens of skills scaffolding on every
call** (107 skills x ~80 tokens of name+description; full SKILL.md only loads on
invocation). Pruned to six:

    ledger  obsidian  here.now  maps  nano-pdf  ocr-and-documents

Rationale is structural, not taste: the gateway mounts ONLY `state` and
`artifacts` — no source repo, no `/ledger` — so the 46 code skills
(compound-engineering 32, software-development 9, autonomous-ai-agents 4)
advertised capabilities the container physically cannot perform. `mlops` is
likewise moot on a 2012 dual-core with no GPU.

**How to prune (the dashboard cannot do this).** `hermes skills uninstall`
only handles HUB-installed skills; these are `builtin`, so there is no code
path — that is why the dashboard uninstall "UI bug" never worked. `hermes
skills config` is interactive-only with no flags. What works:

1. `rm -rf` the unwanted category dirs under `state/skills/`
2. `hermes skills opt-out` — writes `state/.no-bundled-skills`. **This is the
   load-bearing step**: every container boot re-syncs 73 bundled skills, and
   without the marker they all come straight back. Boot log should then read
   `skipped — profile opted out ... 0 total bundled`.
3. Delete `state/.skills_prompt_snapshot.json` — it is a CACHE and does NOT
   regenerate on restart; it will happily keep serving all 107 entries. It
   rebuilds lazily on the next agent turn.

Backup before pruning: `tar czf skills-backup-$(date +%Y%m%dT%H%M%S).tgz -C state skills`.

`here-now` is source `local` (not `builtin`), so it survives opt-out. The
repo-canonical copy lives in `tools/agents/skills/here-now/`.

**Correction:** earlier revisions of this README claimed
`tools/agents/skills/` is mounted read-only into the gateway at
`/opt/data/skills/dotfiles`. **That mount does not exist** — it was never
added to docker-compose.yml, and the gateway has exactly two mounts (`state`,
`artifacts`). Skills currently live in untracked runtime state; provisioning a
fresh machine means copying `tools/agents/skills/*` into
`state/skills/<category>/` by hand, then doing steps 2 and 3 above.

## Credit preflight — why runs failed silently

Hermes swallows Venice **HTTP 402** and reports only `hermes -z: no final
response was produced; treating the run as failed`, which is indistinguishable
from a genuine agent failure. That cost hours of misdiagnosis chasing s6 log
locks and gateway races. `ledger-ingest/preflight.sh` checks the balance first;
`draft.sh` calls it and exits **75 (EX_TEMPFAIL)** logging `OUT OF CREDITS`,
leaving the PDF pending for the next ingest instead of lying about the agent.

Note: Venice prices DIEM and USD **1:1 and identically** for GLM and Claude
models — diem is not a cheaper open-source-only currency. The epoch refills at
00:00 UTC (5pm PDT).

## OCR fallback — image-only statements

PayPal statements are image-rendered with no text layer: pypdf returns ~200
bytes of mail-barcode junk, which is *not empty*, so it slipped past the `-z`
guard and got classified from garbage. `ledger-ingest/pdfocr.swift` (compiled
with `swiftc -O -o pdfocr pdfocr.swift`, macOS Vision, no network, no deps) is
the fallback; `ingest.sh` invokes it whenever the extracted text is under 400
bytes. Verified: 201B -> 16,867B, and the statement then classifies correctly.

## Publishing policy

SOUL.md (in state) forbids publishing to any external service without an
explicit ask in the conversation. `here-now` publishes anonymously with no
setup; authenticated updates need `HERENOW_API_KEY` (see state.env.example)
or `~/.herenow/credentials` inside the container — neither is provisioned by
default, which is the intended safe posture. s3-now is work-only; cf-now
behind zerotrust is future.

## Payment reminders (don't-let-a-one-off-slip)

`ledger-ingest/duedates.sh` parses due dates / minimums / past-due amounts
out of the statement text extracts plus future-dated ledger `note`
directives. Wired into `status.sh` (so the agent sees it on every status)
and into a daily 08:30 Signal reminder (`com.alyssa.ledger-duedates`).
Dismiss a handled item with a substring line in `~/ledger-ingest/paid.txt`
— statements are static, so paid items otherwise nag forever.

## Pre-push secret scan (repo-wide)

`tools/githooks/pre-push` blocks pushes whose ADDED lines contain credentials
**or account-shaped digit runs**. Enable it once per clone:

    git config core.hooksPath tools/githooks

It scans every commit in the push, not just the tip — fixing a secret in a
later commit does not remove it from the history you are about to publish,
which is exactly how a bank account number reached this public repo once.
GitHub's own secret scanning would not have caught it: an account number
matches no partner pattern, because it is an identifier rather than a
credential.

False positives go in `.secretscanignore` (one ERE per line, matched against
`path:line`). Deliberate override: `SKIP_SECRET_SCAN=1 git push`.

## Artifacts land in an Obsidian vault (fixed 2026-07-29)

The gateway mounts an **Obsidian vault** at `/artifacts`:

    ~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Hermes

It previously mounted `com~apple~CloudDocs/Hermes`, which is a *different iCloud
container* and is not inside any vault — so agent markdown never appeared in
Obsidian on the phone, which was the whole point of writing it there. Obsidian
on iOS only sees vaults under `iCloud~md~obsidian/Documents/`.

A standalone `Hermes` vault was chosen over a folder inside an existing vault so
that nothing an agent writes can reach the personal notes (Claudia alone has
~3,170 files). Add it once as a vault on the phone.

`/artifacts` remains the ONLY host path outside `ledger/import` the agent can
write to, and the ledger skill still just says "write deliverables to
/artifacts" — no skill change was needed, only the mount.
