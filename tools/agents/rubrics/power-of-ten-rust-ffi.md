# Power of Ten at a Rust FFI boundary: the review-side checks

> This repo's mapping of Holzmann's ten rules (see `power-of-ten.md`, the
> rules verbatim) onto a Rust core behind `extern "C"` shims called from
> Dart, JS/wasm, Swift, and C. It is the reviewer's half. The writer's half,
> the contract decisions that must be made before the code exists (rules 1,
> 2, 3, 5, 9 and the `# Safety` section), is the `power-of-ten` skill.
> The split follows the rule that coding standards are imposed at review,
> where the agent holds a diff and nothing else, not at implementation
> (#90). Cross-reference by rule number; the skill and this file describe
> the same ten rules from two sides.

Lint behavior in rules 7 and 10, the FFI-safety of `Option<extern "C" fn>`,
and the abort in rule 1 were checked against rustc 1.94.1 and clippy 0.1.94
on 2026-09-22.

## Contract rules: what to verify

The writer decided these. Review verifies the decision was carried through.

1. **Simple control flow, no recursion; no panic reaches an `extern "C"`
   frame.** Every entry point reaches a `catch_unwind` guard, directly or
   through the one shared helper it delegates to. Do not compare totals:
   measured against six correctly guarded shims on 2026-09-22, the count
   comparison reported a finding on all six, because `catch_unwind` also
   appears on the `use` line and in doc comments, and delegating entry
   points share one guard. Use the counts to find the files, then read them:

   ```sh
   grep -nE 'extern "C" fn [A-Za-z_]' src/ffi.rs   # every entry point
   grep -n  'catch_unwind'            src/ffi.rs   # every guard, use line included
   ```

   The first pattern matches definitions, not `Option<extern "C" fn(...)>`
   parameter types. Zero guards beside one or more entry points is the
   finding. Any other ratio needs the file read. `extern "C-unwind"` is a
   finding unless it carries a comment saying why.

2. **Every loop has a fixed upper bound.** Every `while` and `loop` in the
   shim names its bound in the same function. `CStr::from_ptr` on a pointer
   the caller supplied is an unbounded scan. `slice::from_raw_parts(ptr,
   MAX)` over an unknown-length C string is worse than the scan it replaces
   (undefined behavior, not a bound) and is always a finding. A bare
   `const char *` boundary with no length in the protocol is unsatisfiable
   without a signature change; the finding is "the protocol carries no
   length", and the `# Safety` section must state the caller's promise.

3. **Same side allocates and frees.** Every `<thing>_new` that hands
   ownership to foreign code has a `<thing>_free` beside it, one-to-one in
   the header, and no other path frees that memory. No allocation inside a
   callback invoked from a foreign thread unless the contract says so.

5. **Two assertions per function, with recovery.** Each `extern "C"`
   function has at least one check per pointer parameter and one per length
   parameter, before the first dereference, and each check returns an error
   code rather than panicking. `unwrap` or `expect` on anything that came
   from the caller is a finding.

9. **Raw pointers stay in the shim.** `slice::from_raw_parts` and `&*ptr`
   appear only in the shim module, never in the crate it calls. A `**T` exists
   for the handle-out pattern only. Every callback has a typed `extern "C"
   fn` signature, is nullable only as `Option<extern "C" fn>`, is never
   produced by `transmute`, and carries a `*mut c_void` user-data pointer
   whose owner and lifetime the `# Safety` section names.

## Mechanical rules: mapping and check

These can be retrofitted by a reviewer or a lint without redesign, so they
are enforced here rather than held in the writer's context.

4. **Functions fit on one page, about 60 lines.** Applies as written. An
   `extern "C"` shim does checks, conversion, one call into safe Rust, and
   conversion back; logic belongs in the safe function it calls.
   Check: `clippy::too_many_lines` at its default of 100 catches the worst.
   Set it to 60 for the shim crate.

6. **Smallest scope for every data object.** No `static mut`. Shared state
   goes behind `OnceLock`, `Mutex`, or a handle the caller owns. Declare at
   first use. A `thread_local!` is a scope decision and needs a comment
   saying which thread owns it and why.
   Check: this is empty. Comment lines are filtered because `grep -rn`
   prefixes each hit with `file:line:`, so a bare `^//` never matches:

   ```sh
   grep -rn 'static mut' --include='*.rs' | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//'
   ```

   The filter matters: a codebase that got this right tends to carry a
   comment saying why it chose `AtomicI32` or `OnceLock` *over* a `static
   mut`, and the unfiltered grep turns that comment into a finding.

7. **Check every return value. Check every parameter.** `Result` is
   `#[must_use]` already, so a bare `fallible();` warns with no help. Every
   function that returns a plain status code (`c_int`) carries
   `#[must_use]`, because integers are not. `let _ = fallible();` passes
   both, so the shim crate enables `clippy::let_underscore_must_use`
   (restriction group). `unused_results` is the wrong lint: it fires on every
   discarded non-unit value, `HashMap::insert` included. Warnings become
   failures through rule 10's `-D warnings` in CI, never in source.
   Parameter checks are rule 5's checks. Nullable pointers are `Option<&T>`
   or `Option<extern "C" fn(...)>`, which are FFI-safe and force the check
   at the type level.
   Check: no `let _ =` on a `Result` or a status code in the shim; every
   `c_int`-returning function is `#[must_use]`.

8. **Preprocessor use limited.** Rust's equivalents are `macro_rules!`, proc
   macros, `cfg`, and `build.rs`. A macro expands to complete items and
   exists to remove boilerplate that would otherwise be copied per type. It
   never hides control flow or a dereference. `cfg` stays at module
   boundaries for platform selection, not inside function bodies. Generated
   bindings (bindgen, cbindgen, ffigen) live in one module that is never
   hand-edited.
   Check: no `cfg` between a `fn` signature and its closing brace in the
   shim. Grepping for `cfg(` answers a different question: it also matches
   the `#[cfg(test)]` on the test module, which every well-tested shim has.

10. **All warnings on, pedantic, and static analysis daily.** In source:
    `#![warn(clippy::pedantic)]` on the shim (scope note below),
    `#![deny(unsafe_op_in_unsafe_fn)]`, and `#![warn(missing_docs)]` so
    every public item has a doc comment. `missing_docs` does not demand a
    `# Safety` section. The lint that does, `clippy::missing_safety_doc`,
    fires only on `pub unsafe fn`. So every entry point that takes a raw
    pointer is `pub unsafe extern "C" fn`: the honest signature, since the
    caller must uphold the pointer contract, and it puts the section under a
    lint. A safe `pub extern "C" fn` gets its section from the writer's
    Process and from review, not from a lint. In CI only, never in source:
    `RUSTFLAGS=-Dwarnings`, `cargo clippy -- -D warnings`, and `cargo miri
    test` over the crate's `unsafe` code. Local: `bacon` with clippy as the
    default job, per preferred-tooling.
    Check: the CI job exists and fails on a warning; the attributes are on
    the shim and not the whole crate.

    Scope: "the shim crate" assumes the shim is its own crate. When it is a
    module inside a larger crate, the attributes go on the module
    (`#![warn(...)]` at the top of the module file), with a comment saying
    why. Crate-wide `pedantic` on a crate whose other modules are not
    boundary code buries the findings that matter: measured on one workspace
    on 2026-09-22, 155 findings across six crates, 12 of them in the shims.
    A lint nobody reads is rule 10 unsatisfied with the attribute present.

## The foreign side

The rules bind the caller too, and the shim cannot enforce them there. When
the diff includes the Dart, JS, Swift, or C caller:

- Rule 3: the caller frees what the shim says it owns, with the `_free` the
  shim provides. A finalizer is a backstop for a leak, never the primary
  release path.
- Rule 7: the call site checks every status code the shim returns.
- Rule 9: the user-data pointer handed to a callback stays alive for exactly
  the lifetime the `# Safety` section names.

## Reporting

One line per rule the change bends or cannot meet, `Rule N: <what> <why>`,
and whether it is a violation or a bend of the rule's spirit. A bound that
does not exist in the protocol is a finding for Alyssa, not a rule to skip.
