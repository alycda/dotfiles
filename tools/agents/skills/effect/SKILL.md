---
name: effect
description: >
  Write, read, review, or explain TypeScript that uses the Effect library
  (`effect` package: Effect.gen, Layer, Context, Schema, Scope, Fiber,
  Schedule). Trigger when a file imports from "effect" or "effect/*", when
  package.json lists `effect`, or on "effect-ts", "effectts", "Effect v4",
  "typed errors in TypeScript", or "how does this map to Rust". Detects the
  installed major version first, because v3 and v4 code do not compile
  against each other. On v4 it defers to the guidance the package ships
  (node_modules/effect/AGENTS.md); on both versions it adds a Rust
  translation table from Alyssa's effect-playground. Carries no v4 API
  reference of its own. Does not migrate: a v3-to-v4 upgrade is the pinned
  effect-v3-to-v4 skill, run only when Alyssa asks for it.
---

# Effect

This skill is a thin layer. The rules for writing v4 Effect code come from the
Effect team, not from here. The skill adds three things upstream does not
have: a version gate, the Rust mapping from
[effect-playground](https://tangled.org/alycda.tngl.sh/effect-playground), and
the v3/v4 traps found by typechecking that playground against v4.

## Step 0: find the installed version

Do this before you write a line of Effect code. Do not infer the version from
examples in your memory or on the web; most of both are v3.

```sh
node -p "require('effect/package.json').version"   # resolved version
grep '"effect"' package.json                       # declared range
```

| Result | Do this |
|---|---|
| `4.x` (including `-rc.N` / `-beta.N`) | Read `node_modules/effect/AGENTS.md` completely, then follow its links into `node_modules/effect/ai-docs/src/`. For an API it does not cover, search `node_modules/effect/src/`. Use the v4 column below. |
| `3.x` | The v3 package ships no `AGENTS.md`. Search `node_modules/effect/src/` for signatures. Use the v3 column below. Do not copy code from v4 docs, from `AGENTS.md` in another project, or from the pinned `effect-ts` skill; it will not compile. |
| not installed, new project | Ask v3 or v4. Give the tradeoff in one line: npm `latest` is v3 and matches the effect.website docs; v4 is a release candidate, is what the Effect team's own skill installs, and ships agent docs in the package. |
| not installed, existing code | Find out why before you install anything. |

As of 2026-09-22: npm `latest` = `3.22.2`, `rc` = `4.0.0-rc.117`. Re-check with
`npm view effect dist-tags` before you state it.

**Do not upgrade the major version unasked.** The pinned `effect-ts` skill
(`~/.agents/skills/effect-ts/`) starts with `pnpm add effect@rc`. In a v3
project, that command is a v3-to-v4 migration. Use `effect-ts` only to set up a
v4 repo. For a migration, Alyssa runs `/effect-v3-to-v4`, which has
`disable-model-invocation: true` and so never starts automatically.

If `~/.agents/skills/effect-ts/` does not exist, the v4 path still works:
`node_modules/effect/AGENTS.md` is the content that skill points at.

## Rust translation

Same table as the playground README, with a v4 column. Every v4 entry is either
unchanged or resolved against `migration/v3-to-v4.md` in Effect-TS/effect
(main, 4.0.0-rc.117). The four marked "checked" also typecheck and run on
rc.117.

| Rust | v3 | v4 | Lesson |
|---|---|---|---|
| `Result<T, E>` | `E` in `Effect<A, E, R>` | same | 00, 01 |
| `?` | `yield*` in `Effect.gen` | same; `Effect.fn("name")` for reusable functions | 00 |
| `enum Error` + `thiserror` | `Data.TaggedError` | `Data.TaggedError` still exists; `AGENTS.md` prefers `Schema.TaggedError<Self>()("Tag", {...})` (checked) | 01 |
| `match` on the error enum | `Effect.catchTags` | same (checked) | 01 |
| catch-all `Err(_)` | `Effect.catchAll` | `Effect.catch` | 01 |
| `Result` as a value | `Effect.either` → `Either` | `Effect.result` → `Result` | 01, 06 |
| `panic!` | defect (`Effect.die`) | same; `Cause.isDie` → `Cause.hasDies` | 01 |
| `Drop` / RAII | `Scope` + `Effect.acquireRelease` | same | 02 |
| `std::thread::scope` | `Effect.scoped` | same | 02 |
| trait / `&dyn Trait` | `Context.Tag("id")<Self, Shape>()` | `Context.Service<Self, Shape>()("id")`, a structural rewrite and not a rename (checked) | 03 |
| impl at the call site | `Layer` + `Effect.provide` | same; build the value with `Service.of({...})` | 03 |
| `tokio::spawn` | `Effect.fork` | `Effect.forkChild` (checked); `forkDaemon` → `forkDetach` | 04 |
| `tokio::select!` | `Effect.race` | same | 04 |
| `Semaphore` over a task set | `{ concurrency: n }` | same | 04, 06 |
| `serde` derive | `Schema.Struct` | same | 05 |
| `#[serde(with = ...)]` | `Schema.Date` (string → `Date`) | **`Schema.DateFromString`**; see the traps below | 05 |
| `backoff` crate | `Schedule.intersect`, `whileInput` | `Schedule.max([...])`, `Schedule.while`; see the traps below | 06 |
| `Arc<Mutex<T>>` | `Ref` | same | — |
| `impl Iterator` | `Stream` | same | — |

For a symbol that is not in this table, do not guess the v4 name. Search the
reference (the recipes are in `~/.agents/skills/effect-v3-to-v4/SKILL.md`) or
`node_modules/effect/src/`. This table was checked, and one guess still got
through: `Schema.TaggedErrorClass` does not exist.

## v3 → v4 traps that a rename table hides

These come from typechecking effect-playground (v3, strict tsconfig) against
`4.0.0-rc.117`. They matter when you read v3 code while you write v4 code, or
the other way round.

- **Same name, different meaning: `Schema.Date`.** v3 `Schema.Date` decodes an
  ISO string to a `Date`. v4 `Schema.Date` is the identity schema for a `Date`,
  and it rejects the string (the decode returns `Failure`; checked). The v3
  meaning is now called `Schema.DateFromString`. Code that keeps the v3 name
  still compiles and fails at runtime on every real payload. Lesson 05 exists
  to teach this boundary.
- **Different shape: `Schedule.intersect` → `Schedule.max`.** v4 `max` takes an
  array (`Schedule.max([a, b])`), so it cannot go in a `.pipe(...)` chain, and
  it outputs a `Duration`, not a tuple. v3 `whileInput(pred)` becomes
  `Schedule.while(({ input }) => pred(input))`. Lesson 06's backoff, ported
  this way, still makes 5 attempts on a persistent transient error and 1 on a
  permanent one (checked).
- **`Cause` is no longer a union you branch on.** `isFailType`, `isDie`, and
  the other variant guards now apply to entries of `cause.reasons`
  (`Cause.isFailReason`), or become cause-level predicates (`Cause.hasDies`).
  `Cause.TimeoutException` → `Cause.TimeoutError`, and the `_tag`
  discriminant changes with it.
- **Schema filters became checks.** `Schema.int()`, `between`, and `pattern`
  become `isInt`, `isBetween`, and `isPattern`, applied with `Schema.check` or
  a schema's `.check`. `Schema.annotations` → `Schema.annotate`.
  `Schema.decodeUnknown` → `Schema.decodeUnknownEffect`. `ParseResult` is
  gone. `Schema.Schema.Encoded` has no counterpart, so infer the type from the
  constructor.
- **Misleading cascade under `exactOptionalPropertyTypes`.** One unresolved
  symbol makes `R` infer as `unknown`, and `runPromise` then reports TS2379:
  "`Effect<void, unknown, unknown>` is not assignable to `Effect<void, unknown,
  never>` ... Consider adding 'undefined'". Do not add `undefined`. Fix the
  first TS2339/TS2551 in the file, and the TS2379 goes away.

## Writing rules for both versions

- An `Effect` is a description. Building one runs nothing. Retry, timeout, and
  interruption are combinators because the value can run twice or never.
- Use `Effect.gen` for sequential logic. Use `.pipe(...)` to decorate one
  effect (retry, timeout, catch). On v4, use `Effect.fn("name")` for a
  reusable function, and pass decorators as extra arguments, not `.pipe`
  (see `AGENTS.md`).
- To fail from a generator, write `return yield* new MyError(...)`. Without the
  `return`, TypeScript thinks execution continues.
- Expected failures go in `E` as tagged errors. Broken invariants are defects
  (`Effect.die`, `orDie`) and stay out of `E`. Name a payload field `reason`,
  not `cause`: `Data.TaggedError` extends `Error`, whose `cause` conflicts
  with a readonly redeclaration.
- Decode untrusted input with `Schema`. Do not cast.
- Keep the playground's tsconfig strictness: `strict`,
  `exactOptionalPropertyTypes`, `noUncheckedIndexedAccess`. Without `strict`,
  the error channel can degrade to `any`.
- Do not use `as` or `any` to silence an Effect type error. The error usually
  means the shape is different, and a cast deletes that information.

## Verify

Done means the code typechecks and runs. Hover inference alone is not proof.

```sh
npx tsc --noEmit                  # or the project's typecheck script
npx tsx path/to/file.ts           # run it; Effect code that typechecks can still fail at runtime (Schema.Date)
```

In effect-playground itself, `npm run check && npm test` is the gate. Lesson 06
calls a live API, so CI does not run it.

## Hand-offs

- Set up a new v4 repo: the pinned `effect-ts` skill.
- Migrate v3 → v4: `/effect-v3-to-v4`, and only on request. That skill forbids
  compat shims and casts. This one agrees.
- Rust→WASM through Effect (playground lesson 07): the Rust side is ordinary
  FFI work, so `power-of-ten` applies to any `unsafe` in it.
