---
name: topcoat
description: >
  Write, read, or review a web app built on Topcoat (tokio-rs/topcoat), the
  server-rendered Rust framework: `view!`, `#[component]`, `#[page]`,
  `#[layout]`, `#[procedure]`, `#[shard]`, `live!`, `signal`, `app_context`,
  `Cx`, `topcoat dev`, `topcoat ui`. Trigger when Cargo.toml depends on
  `topcoat`, on "topcoat", or when Alyssa compares a full-stack Effect app
  (create-epoch-app, Confect, effect-atom) with its Rust equivalent. Finds
  the installed version first and reads the guides that ship inside the
  crates at that version. Carries no API reference of its own. Adds the
  Effect ↔ Topcoat pairing and two contracts the compiler does not check.
  Not for work inside the Topcoat repository itself, which has its own
  contributor skills in `.agents/skills/`.
---

# Topcoat

Topcoat is pre-1.0; its README says "Early-stage and experimental. Expect
breaking changes." And the guides on `main` drift from the release (13 guide files
changed between v0.8.1 and `main` in the nine days after the tag). Read the
docs for the version in `Cargo.lock`, never `main`.

This skill is a thin layer. The guides are upstream's. It adds a version gate,
two runtime contracts that the compiler does not check, and the pairing with
the Effect stack, which is where Alyssa is coming from.

## Step 0: version and docs

```sh
grep -A1 '^name = "topcoat"$' Cargo.lock        # resolved version
rustc --version                                  # 0.8.1 needs >= 1.98
ls -d ~/.cargo/registry/src/*/topcoat-*<ver>/docs \
      ~/.cargo/registry/src/*/topcoat-*<ver>/macro/docs 2>/dev/null
```

The guides are embedded in the published crates (`include_str!` into the API
docs), so after a `cargo build` they are on disk at the resolved version:
`topcoat-<ver>/docs/` holds the facade guides (router, context, app_context,
runtime, session, ui, …), and `topcoat-<crate>-macro-<ver>/docs/` holds the
macro references (`view.md`, `live.md`, `procedure.md`, `shard.md`, …).
`cargo doc --open -p topcoat` renders the same text.

The guide *index* is `AGENTS.md` in the repository, and it does **not** ship in
the crate. Read it at the matching tag:
`https://github.com/tokio-rs/topcoat/blob/v<ver>/AGENTS.md`. Its "Project
structure" section and the `.agents/skills/` it references are for Topcoat
contributors; only the "Documentation" index applies to an app.

Before you write code in an area, read its guide. Start with
`functions_not_middlewares.md`; it is the framework's design argument, and
the rest assumes it.

## Contracts the compiler does not check

**`app_context::<T>(cx)` is a runtime lookup.** It is keyed by `TypeId`. A type
that was never registered with `.app_context(value)` compiles, then panics on
every request that reaches the call. Topcoat catches the panic and responds
500; other routes keep serving (checked on 0.8.1: the page returned
`internal server error [500]` and the log named the missing type). So:

- Register every app-context value in the one `Router::builder()` chain, and
  treat that chain as the list of what the app depends on.
- Use `try_app_context::<T>(cx)` when a value is optional; it returns `None`.
- A green `cargo build` says nothing about registration. Smoke-test by
  requesting each route once. This is the same lesson as "passing activation
  is not proof a tool works" in this repo's CLAUDE.md.
- One value per type. Registering a type twice panics at startup; wrap in
  newtypes (`struct PrimaryDb(Database)`).

**Procedures and shards are public HTTP endpoints.** Their arguments come from
the browser and "must not be trusted" (upstream's words, both guides). Do the
auth check inside the body with a `cx` function (`require_auth(cx).await?`),
not by assuming the page that renders the button was guarded. A procedure's
`Err` becomes an error response that the calling expression cannot observe;
if the browser must react to a failure, return it as data
(`Result<Result<T, String>>`).

## Coming from Effect: the pairing

create-epoch-app (Rhys Sullivan: Effect + Convex + Next.js + effect-atom, on
Effect 3.19, last commit 2026-01-11) is the full-stack Effect shape; Topcoat is
the nearest Rust shape. Rows marked "checked" were run; the rest come from the
0.8.1 guides and the epoch-app source.

| Concern | create-epoch-app / Effect | Topcoat 0.8.1 |
|---|---|---|
| Ask for a dependency | `const db = yield* Database`; epoch-app's rule is "prefer `yield*` over passing deps as arguments" | `app_context::<Db>(cx)` inside a small `fn(cx: &Cx)`; "functions, not middlewares" is the same rule |
| Missing dependency | **Compile error**: the service stays in `R`, and `runPromise` rejects `Effect<A, E, Db>` (checked, TS2345) | **Runtime panic → 500** on that request only (checked) |
| Wire implementations | `Layer` + `Effect.provide`; swap a Layer for tests | `Router::builder().app_context(value)`; swap the value in a test router |
| Request-scoped dedupe | no one-to-one; `RequestResolver` dedupes and batches | `#[memoize]` on a `cx` function, per request |
| Error type | typed `E` channel, tagged errors, `catchTags` | `topcoat::Error` wraps `anyhow::Error` (type-erased); router error types map to status codes, anything else is 500. Keep `thiserror` enums in the domain and convert at the handler |
| Auth guard | Better Auth on Convex; a service you `yield*` | `topcoat-session` (bring your own storage) plus `require_auth(cx)` functions called where the data is used |
| Server call from UI | Confect RPC (`factory.query/mutation`), typed errors cross the wire via Schema | `#[procedure]` async fn called in a runtime expression; `Err` is opaque to the client |
| Client state | effect-atom (`useAtom`, `useAtomValue`) | `signal(cx, init)` + runtime expressions (`@click`, `:value`) |
| Re-render on input change | atom-derived React component | `#[shard]`: the browser tracks the signals, the server re-renders, the DOM swaps |
| Slow data | React Suspense | `live!` / `emit!` stream regions into the same response; `suspense`/`error_boundary` components |
| Push after load | Convex live queries | no DB subscription; `Sse` response (`sse` feature), or Datastar over SSE |
| Test database | `convex-test` (in-memory Convex) | a Ghost fork per test run or agent task (`ghost fork seeded run-42`) on venari's Ghost server. Ghost is the *test* database, not the Convex replacement: its databases share one role, use unverified TLS, and are disposable by design (`tools/venari/README.md`, "Ghost") |
| Validate input | `Schema.decodeUnknown` | `FromRequest` extractors (`content.md`) and serde |
| UI kit | `@packages/ui` (shadcn / Radix) + Tailwind via Node | `topcoat ui` copies component source from a registry (the shadcn model) + standalone Tailwind CLI, no Node |
| Client build | Next.js bundle, bun, turbo | none: no wasm, no JS build step |
| Tracing | `Effect.withSpan`, `@effect/opentelemetry` | a router layer (tower), which the guide reserves for transport concerns like tracing |

The row that decides most design arguments is the second. Effect moves the
"did you wire it" check into the type system; Topcoat keeps it a startup and
request-time invariant, and buys a smaller, plainer API with it. Say which
side of that trade a design relies on.

The "Server call from UI" row is where the two differ most on errors: a
Confect endpoint declares an error schema, so the client gets a typed
failure; a Topcoat procedure cannot deliver one unless the error is part of
the `Ok` value.

## Tooling

- `topcoat dev` (from `cargo install topcoat-cli`): build, watch, restart.
  Pages that include `topcoat::dev::script()` reload themselves.
- `topcoat fmt`: formats macro bodies (`view!` and others) alongside
  `rustfmt`. Run it before you commit view code.
- `HOST` / `PORT` set the bind address; the default is `127.0.0.1:3000`.

## Unsafe

Topcoat's own workspace sets `unsafe_code = "deny"`. Suggestion, not a
requirement: an app on it rarely needs `unsafe` either, so the same lint in
`[lints.rust]` costs nothing. Where FFI does need it, `power-of-ten` applies.

## Hand-offs

- The Effect side of any comparison: the `effect` skill (version gate first).
- A third-party SDK wrapped as an Effect service: `effect-client-wrapper`.
