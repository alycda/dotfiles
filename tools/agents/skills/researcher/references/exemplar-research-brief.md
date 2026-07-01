# Research Brief: Prior Art for the Kitchen-Sink FFI Validation Suite

> Audience: a deep-research agent. You have no prior context on this project. Read the *Project Summary* below, then execute the *Research Tasks* and return the *Required Deliverables*. Cite primary sources (arxiv DOI, repo URL + commit/tag, official docs URL). Skip blog-rehashes unless they point to a primary source we'd otherwise miss.

---

## Project Summary (read first)

We are building a **language-agnostic, end-to-end test suite** that validates the FFI boundary of a Rust-based, peer-to-peer document database called **Ditto**. The suite exercises Ditto's `#[ffi_export]` surface — initialize peer, configure LAN transport, execute DQL queries, register store observers, sync documents — entirely from **C** and **WASM**, with **no SDK code** in the loop.

Two linked motivations:

1. **Break a circular dependency.** Today, Rust core changes can only be validated through SDK tests, and SDK tests can't pass until every SDK has implemented the breaking change. The FFI ABI itself should be the validation point.
2. **Enable a black-box state verifier (`ditto-cli`).** A downstream tool will link `libdittoffi` to inspect store state inside SDK integration tests without instrumenting the app.

Concrete technical anchors:

- Rust core compiled to a C dylib (`libdittoffi`) plus a generated C header (`dittoffi.h`) and a structured metadata file (`dittoffi.metadata.json`), produced by **`safer-ffi`**.
- WASM target is **`wasm32-unknown-unknown`** running in headless Chrome/Firefox via **`wasm-pack test --headless`** with `wasm_bindgen_test_configure!(run_in_browser)`. We may also need `wasm32-wasi` for the CLI variant.
- Holdout scenarios include CRDT sync between two in-process C peers, observer callbacks, parameterized DQL via CBOR, and ABI stability across two consecutive core versions.
- A pure-C reference app (`examples/carsapp`, SDL2 + Clay UI, ~1KLOC) already drives the full peer lifecycle through the FFI; it's the existence proof, not the test suite.

Adjacent prior tooling we already know about (do **not** spend research budget rediscovering these — instead, find what's *adjacent* or *competing*): `bindgen`, `cbindgen`, `safer-ffi`, `wasm-bindgen`, `wasm-pack`, `cargo-fuzz`, `criterion`, the `dittolive-ditto-sys` thin binary-distributor crate pattern.

---

## Research Tasks

For each topic below, return: the strongest 3–8 primary sources, what each contributes, and where it falls short for our use case. Prefer recent (≤ 5 yrs) unless the canonical source is older.

### 1. FFI ABI stability & drift detection

We need to diff `dittoffi.h` + `dittoffi.metadata.json` between core versions N and N+1 and produce a drift report. What's the state of the art?

- Tools that diff C ABIs: **`abidiff` / `libabigail`** (Red Hat), **`abi-compliance-checker`**, **`cargo-public-api`** for Rust, **`cargo-semver-checks`**, **`rust-semverver`** (archived?), Swift's ABI checker, Go's `apidiff`.
- Approaches in the Rust FFI world specifically: `safer-ffi`'s own guarantees, `diplomat`, `uniffi-rs` (Mozilla), `interoptopus`, `cxx` (Dtolnay).
- Academic: arxiv/USENIX/PLDI/POPL papers on **ABI compatibility checking**, **structural type-equivalence across compilation units**, **soundness of C-Rust FFI** (the RustBelt-FFI line, Galeed, Sandcrust, XRust, and follow-ons).
- Industrial postmortems on ABI breakage (glibc symbol versioning, libstdc++ dual-ABI, etc.) — what failure modes did they catch that a header-diff wouldn't?

### 2. Cross-language / multi-SDK validation harnesses

Other projects with a Rust core + many language SDKs (or a C core + many language SDKs) have hit the same circular-dependency problem. Find their solutions.

- **Mozilla Application Services / Glean / Firefox Sync** — multi-SDK, Rust core, used `uniffi-rs`. How do they validate the FFI without each SDK? Look for `application-services`, `glean`, `mozilla/uniffi-rs`.
- **automerge / automerge-rs** — Rust CRDT core, multiple language bindings (JS, Swift, Python). How do they test the C FFI? See `automerge/automerge` and the `automerge-c` crate.
- **diem / move-language**, **Solana**, **libsignal** (Signal's `libsignal-protocol` has bindings for iOS/Android/Desktop) — `signalapp/libsignal` testing strategy.
- **librdkafka**, **libsql / Turso**, **DuckDB**, **SQLite** — extensive C-API test suites; what does SQLite's TH3/TCL test harness teach us about *kitchen-sink* C-only validation?
- **MaterializeDB**, **TigerBeetle**, **FoundationDB** simulator — relevant for distributed-state black-box testing patterns.
- **Tauri**, **Neon (Node + Rust)**, **PyO3**, **JNR / JNI** — what do their cross-language test patterns look like?

For each: how do they decouple core CI from per-SDK CI? Do they run a "language-agnostic conformance suite" against the core directly?

### 3. WASM async testing & browser-target Rust tests

Our holdout #6 ("everything works under WASM async constraints") is the riskiest. Find prior art on:

- `wasm-bindgen-test` / `wasm-pack test --headless` patterns at scale. Repos with large `#[wasm_bindgen_test]` suites: `wasm-bindgen`, `web-sys`, `js-sys`, `yew`, `leptos`, `dioxus`, `automerge-wasm`.
- The specific failure mode where a Rust API works on native but deadlocks/panics under the browser executor because of `Send`/`Sync` bounds, single-threaded executor assumptions, or `std::thread` use. Are there lints, `clippy` rules, or static-analysis projects that catch this?
- `wasm32-wasi` vs `wasm32-unknown-unknown` test parity — when does WASI catch what browser-WASM doesn't, and vice versa?
- Any academic work on **testing async Rust** generally (loom, shuttle, miri's async support) and how those apply at the FFI boundary.

### 4. Black-box state verification of embedded databases

Our secondary use case (`ditto-cli` as black-box verifier) maps to a known testing pattern.

- **Jepsen** / **Maelstrom** / **Porcupine** for distributed systems linearizability checking — overkill for our scale, but the *interface* (external observer, no instrumentation) is the right shape.
- **SQLite**'s shell + `.dump` as a black-box state inspector inside tests.
- Test-protocol-over-socket patterns: **Selenium/WebDriver**, **Chrome DevTools Protocol**, **Playwright**, **gRPC test reflection**. Our existing `tools/ditto-test-protocol` (DTP) takes this route — find its closest competitors.
- CRDT-specific testing: arxiv papers on **CRDT correctness testing**, **convergence property testing**, **operational vs state-based CRDT equivalence checking**. Look for Shapiro, Preguiça, Burckhardt, Kleppmann.

### 5. C-from-Rust test harnesses & "pure C consumer" idioms

We will write C test code that links `libdittoffi`. What's the cleanest established pattern?

- Rust projects that ship a `tests/c/` or `examples/c/` consumer harness as part of CI: look at `rusqlite`, `sled`, `redb`, `surrealdb`, `quiche` (Cloudflare), `boring` / `boring-sys`, `rustls-ffi`. What build systems do they use (CMake? Meson? raw `cc-rs`?), what's their CI matrix, how do they handle macOS universal / Linux ARM64 / Windows?
- Specifically `rustls-ffi` — Cloudflare/ISRG's C-API for rustls — has a documented "FFI-first" testing philosophy. What's their integration test layout?
- Pure-C unit test frameworks worth comparing: **Unity**, **Check**, **Criterion (the C one)**, **Greatest**, **CMocka**, **µnit**. Pick the 1–2 most relevant for an embedded-database-style suite where each test spins up a peer.

### 6. CBOR-encoded parameterized query plumbing across FFI

Our DQL queries cross the FFI as CBOR-encoded parameter blobs. Prior art on:

- Schema-less / schema-evolved binary protocols at FFI boundaries: CBOR, MessagePack, FlatBuffers, Cap'n Proto, Bincode-over-FFI. Trade-offs for testability.
- How other databases pass parameterized-query parameters across an FFI (SQLite's `sqlite3_bind_*`, DuckDB's prepared statements, libsql's wire format).

### 7. Solving the SDK/Core circular-dependency pattern

This is more of a *methodology* search. We want prior writing — blog posts from staff engineers, conference talks, internal engineering memos that leaked, RFCs — on the general pattern of "core team velocity blocked by N SDK teams."

- Mozilla's "Rust components" RFCs, the Glean SDK rollout writeups.
- AWS SDK Common Runtime (CRT) — they decoupled per-language SDKs from a shared C core. Find their testing/conformance writeups.
- gRPC's interop test suite (`grpc-go`, `grpc-java`, etc. all run a shared conformance test). This is *exactly* the pattern we're after at the FFI layer instead of the wire layer.
- OpenTelemetry's spec-conformance tests across SDKs.
- The general idea has a name in the literature ("conformance test suite", "contract testing", "consumer-driven contracts" à la **Pact**) — collect the best writeups.

### 8. Adversarial / replay testing for sync protocols

Holdout-adjacent: we have an incident (i-604, `TransactionTooLarge` disconnect loop) we want to replay as an adversarial scenario inside the C suite.

- **Antithesis** (deterministic-simulation testing as a service), **TigerBeetle's VOPR**, FoundationDB's simulator — primary sources, talks, or papers.
- Property-based testing across an FFI: `proptest`, `quickcheck`, `hypothesis-rust`, and their use against C-callable surfaces.

---

## Required Deliverables

Return a single Markdown document with these sections:

1. **Top 10 must-read sources** — ranked, with one-paragraph annotations. These are the things every engineer joining this sprint should read first.
2. **Per-topic findings** — one section per research task above. Include sources, a 2–3 sentence "what it gives us", and an explicit "gap" line (what it does *not* solve for our case).
3. **Tool shortlist** — concrete tools/libraries we should evaluate for each of: ABI diffing, C test harness, WASM browser test runner, CBOR codec choice, property-testing framework. For each: repo URL, last-release date, license, maintenance health (commits in last 90 days, open-issue trend), and a one-sentence "use it / don't / maybe".
4. **Reference architectures** — 3–5 projects whose layout we should mimic or steal from. Link to the specific files/dirs (path + line ranges if relevant). For each, a 2–3 sentence "what to copy".
5. **Open research questions** — things you searched for and *couldn't* find good prior art on. These are real gaps and tell us where we'll have to invent.
6. **Source ledger** — flat list of every URL you cite, deduplicated, with arxiv DOIs preferred over arxiv abstract URLs.

## Constraints on the search

- **Authoritative > popular.** Prefer arxiv preprints, official docs, primary repos, conference talks (with video), and engineering blogs from the team that built the thing. Skip Medium reposts, listicles, AI-generated summaries.
- **Show your work on adjacency.** When a source is *almost* relevant but not quite, say what's analogous and what's different. We learn as much from near-misses as from direct hits.
- **Recency matters for tooling, not for theory.** ABI-diffing tooling from 2018 may already be superseded; a 2014 CRDT paper probably isn't.
- **Don't pad.** If a topic has only two good sources, return two. If it has fifteen, prune to the strongest five plus a "see also".
- **Flag licensing landmines.** Anything GPL/AGPL or with patent grants we'd inherit by linking — call it out explicitly.

## Scope guardrails (don't bother)

- Don't research general Rust learning material, async-Rust tutorials, or generic CI tooling (we have CI).
- Don't research Big Peer / cloud sync — explicitly out of scope for this seed.
- Don't research Bluetooth / transport-layer permissioning — separate ticket (<INTERNAL-TICKET-C>).
- Don't research SDK-layer test patterns — that's <INTERNAL-TICKET-A>'s problem.
- Don't propose architectures or write code; this is a sourcing exercise.

---

*Brief authored: 2026-04-30. Companion to `SEED.md`. Output expected as `docs/research/PRIOR-ART.md` or returned inline.*
