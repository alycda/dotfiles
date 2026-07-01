# SEED: Kitchen Sink FFI Validation Suite

> Entry point for agentic development. Follow the loop: Validation → Feedback → repeat until holdout scenarios pass and stay passing.

---

## What We're Building

A language-agnostic, end-to-end test suite that validates Ditto's `#[ffi_export]` surface entirely from C and WASM, independent of any SDK implementation.

The suite exercises the complete peer lifecycle: initialize, configure transport, execute DQL, register observers, sync documents. It becomes the authoritative validation layer for all SDK FFI contracts — not just Flutter and JS/wasm — and is the proposed resolution to the SDK/Core circular dependency that currently blocks cross-SDK velocity.

**One-line version:** Prove the FFI boundary is correct without touching an SDK.

---

## Why This Exists

**Current state:** Validating Rust core changes requires SDK tests. SDK tests can't pass until all SDKs implement breaking core changes. This deadlock serializes delivery across every SDK team.

**Target state:** The FFI boundary is validated independently. Core ships. SDKs consume. The circular dependency (<INTERNAL-TICKET-D>) is broken at the layer where it should be broken — the ABI contract itself.

**Secondary use case:** The `ditto-cli` black-box state verifier — a tool that uses this same C FFI surface to inspect store state in SDK integration tests without instrumenting the app under test.

---

## Validation Harness

> Must be end-to-end, as close to real as possible: real binary, real sync protocol, real platform matrix.

### Holdout Scenarios (loop runs until these pass and stay passing)

| # | Scenario | Platform |
|---|----------|----------|
| 1 | Initialize a `DittoPeer` from pure C using `#[ffi_export]` symbols | Linux x86_64, ARM64, macOS |
| 2 | Configure LAN transport (SmallPeersOnly, no Big Peer) | all |
| 3 | Execute a DQL `INSERT` and `SELECT` | all |
| 4 | Register a store observer; receive callback on mutation | all |
| 5 | Sync a document between two in-process C peers | all |
| 6 | All of the above under WASM async constraints | Node + WASM / wasm-pack test |
| 7 | FFI surface is ABI-stable across two consecutive Rust core versions | Linux x86_64 |

### What "Real Environment" Means Here

- Real `libdittoffi` binary fetched at build time (same path as `dittolive-ditto-sys`)
- Real sync protocol, no stubbed transport
- WASM tests run in a browser-like async runtime — this is where async-only constraints surface, critical for Flutter Web/WASM validation
- CI matrix matches current SDK CI: Linux x86_64, ARM64, macOS (co-mac3 when available)
- No mocking of the Rust core layer

### What Is NOT "Real" (explicitly out of scope)

- Big Peer / cloud sync (LAN-only for this seed)
- SDK-layer tests (those belong in <INTERNAL-TICKET-A>)
- Performance benchmarking
- Bluetooth / transport-layer permissioning (separate CI infra issue — see <INTERNAL-TICKET-C>)

---

## Feedback Loop

Each run of the validation harness produces a feedback signal fed back into the inputs:

| Output | Fed Back As |
|--------|-------------|
| Pass/fail per holdout scenario | Patch scope for next iteration |
| `#[ffi_export]` symbol coverage map | Identifies gaps; drives new export PRs |
| ABI drift report (version N vs N+1) | Triggers safer-ffi annotation fixes |
| WASM async failure traces | Identifies missing `async`/`Sync` bounds in export surface |
| SDK integration test failures | Reclassified: FFI-layer bug vs. SDK-layer bug |

**Loop exit condition:** All holdout scenarios green across all target platforms, on two consecutive core version bumps.

---

## Apply More Tokens

> For every obstacle, ask: how can we convert this problem into a representation the model can understand?

| Obstacle | Token Form |
|----------|------------|
| Incomplete `#[ffi_export]` surface | Paste the generated C header (`dittoffi.h`) as direct context |
| Which scenarios to cover | <INTERNAL-TICKET-A> sub-issues (14 categories: Init, Auth, Store Ops, Sync, Transports, Presence, Attachments, Observers, Transactions, ...) as holdout spec |
| Incident replays | i-604 (TransactionTooLarge disconnect loop) as an adversarial sync scenario: does the C peer reproduce the infinite replay? |
| CI failure logs | Buildkite traces as token input for debugging flaky WASM async tests |
| Existing SDK tests | Flutter/JS test cases converted to C equivalents — what the C suite must cover to achieve parity |
| WASM async constraints | Flutter Web CI failures as annotated failure transcripts |
| Customer integration context | <INTERNAL-TICKET-B> (smallPeersOnly / license token) as a real customer-shaped scenario the suite must exercise |

---

## Related Tickets

- `<INTERNAL-TICKET-E>` — C and WASM tests for Rust FFI validation (primary)
- `<INTERNAL-TICKET-A>` — Cypress UI kitchen sink testing (parallel track; shares holdout scenario spec)
- `<INTERNAL-TICKET-B>` — Flutter license token / smallPeersOnly (customer scenario input)
- `<INTERNAL-TICKET-D>` — SDK/Core circular dependency analysis (the problem this solves)
- `<INTERNAL-TICKET-C>` — 16KB page size Flutter/Android (downstream beneficiary once CI harness stabilizes)

---

## Open Questions (Resolved)

1. **Does the current `#[ffi_export]` surface cover enough to initialize a peer and configure LAN transport entirely from C, or do new exports need to land first?**

   **Yes — sufficient.** `examples/carsapp` is a pure-C GUI (SDL2 + Clay UI, ~1KLOC) that already drives the full peer lifecycle through the C FFI: init, P2P mesh sync (BLE, LAN/mDNS, AWDL), Big Peer WebSocket sync with playground auth, DQL CRUD via CBOR-encoded parameterized queries, sync subscriptions, and presence graph. It is the existence proof that holdout scenarios 1–5 are reachable from `#[ffi_export]` symbols today, with no new exports required to start the loop. Use it as the reference shape when porting holdout scenarios into the suite.

2. **Which WASM runtime is the test target — Node with wasm-pack, or a headless browser?**

   **Headless Chrome + Firefox via `wasm-pack test --headless`**, matching the established pattern in `scripts/rust/test_wasm.sh`. Node + wasm-pack is rejected: it bypasses the browser async executor that Flutter Web and JS-on-Web actually run against, so async-only failures would not surface. `wasm_bindgen_test_configure!(run_in_browser)` is already the convention across `ditto-store`, `ditto-time`, `ditto-auth`, and `ditto-blob-storage-test`, and CI installs both browsers for the `wasm-crate-tests` job. Sub-question worth flagging separately: whether to additionally cover `wasm32-wasi` for a server-side/CLI variant (relevant to the `ditto-cli` black-box verifier in the secondary use case) — currently the repo only targets `wasm32-unknown-unknown` in browser.

3. **Does the `ditto-cli` black-box verifier share the same C test harness, or is it a downstream consumer of a stable harness?**

   **Downstream consumer.** `ditto-cli` does not exist yet — it is a forward-looking design — so we get to set the boundary. Set it as a consumer: `ditto-cli` links against the same `libdittoffi` and reuses the `#[ffi_export]` coverage map this suite produces, but ships as its own binary with its own UX (state inspection, store dumps) and its own release cadence. Reason: the kitchen-sink suite's job is to prove the FFI contract; the verifier's job is to *use* a known-good FFI contract from outside an app. Coupling them would force every UX change in `ditto-cli` through the validation harness's CI gate, and would entangle two release cadences for no architectural benefit. Worth flagging: the existing [`tools/ditto-test-protocol/`](main/tools/ditto-test-protocol/) (DTP) takes a different approach — protocol-over-TCP into a Rust-SDK test app — and is not a substitute for C-FFI validation. DTP and this suite are complementary; `ditto-cli` may end up speaking DTP *and* linking `libdittoffi`, but that does not change the harness boundary.

4. **Who owns the ABI drift report format — this suite, or `dittolive-ditto-sys`?**

   **This suite owns the format. `dittolive-ditto-sys` stays a thin binary distributor.** The inputs already exist in-tree: [`crates/dittoffi/dittoffi.h`](main/crates/dittoffi/dittoffi.h) and the structured [`crates/dittoffi/dittoffi.metadata.json`](main/crates/dittoffi/dittoffi.metadata.json) are emitted by [`crates/dittoffi-gen-headers/`](main/crates/dittoffi-gen-headers/) via `safer-ffi` and committed to the repo. The suite consumes those two artifacts at versions N and N+1, diffs them, and produces the drift report. [`sdks/rust/dittolive-ditto-sys/`](main/sdks/rust/dittolive-ditto-sys/) only fetches the prebuilt `libdittoffi` and runs toolchain-mismatch checks — it does not parse headers or validate annotations, and pulling drift detection into a `*-sys` crate would violate the convention that sys-crates are thin veneers. Hybrid escape hatch if downstream consumers need the report at install time: the suite remains the source of truth for the schema, and the report is published as an artifact alongside `libdittoffi` releases for `dittolive-ditto-sys` to surface opaquely.

---

*Seed authored: 2026-04-30. Loop not yet started. Holdout scenarios: not yet green.*