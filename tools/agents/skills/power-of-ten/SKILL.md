---
name: power-of-ten
description: >
  Apply NASA/JPL's Power of Ten rules while writing systems code, not only
  when reviewing it: Rust crates that expose an `extern "C"` surface, FFI
  shims, callbacks crossing a language boundary, `unsafe` blocks, and the
  Dart/JS code that calls them. Trigger on "power of ten", "power of 10",
  "holzmann", "safety-critical", "bounded", "assertion density", or when
  Alyssa is about to write or edit an `extern "C"` function, an `unsafe`
  block, a callback registered with foreign code, or a loop over
  foreign-owned memory. Carries no rule text: it reads the rubric the
  code-critic agent judges against and adds the Rust/FFI mapping of each
  rule, so the same ten rules guide the writing and the review.
---

# Power of Ten

Gerard Holzmann wrote the ten rules (NASA/JPL, 2006) for C on
spacecraft. Alyssa's daily work is a Rust core behind `extern "C"` shims,
called from Dart, JS/wasm, Swift, and C. The rules map cleanly, but the
mapping is not in the rubric, and `code-critic` re-derives it on every
review. This skill writes it down once, for use before the code exists.

## The rules live in the rubric

Read `~/.agents/rubrics/power-of-ten.md` before you apply this skill. It is
the ten rules verbatim. `agents.nix` builds `code-critic` from the same file, so what
this skill guides and what the critic judges cannot drift.

If that file does not exist, say so and stop. Do not reconstruct the rules
from memory. `agents.nix` deploys `tools/agents/rubrics/` to that path.

## Rule by rule, in Rust at an FFI boundary

Each entry names the rule, the Rust form, and the check that proves it.

1. **Simple control flow, no recursion.** No recursion in any function
   reachable from an `extern "C"` entry point or a foreign-invoked callback.
   Walk trees with an explicit stack and a bound. No panic may reach an
   `extern "C"` frame. Since Rust 1.81 the non-unwind ABIs abort the process
   on an uncaught unwind, and before 1.81 that was undefined behavior. Wrap
   the body in `std::panic::catch_unwind` and convert to an error code.
   `extern "C-unwind"` is a deliberate choice with a comment, never a
   default.
   Check: every entry point reaches a guard. Counting the two does not
   show that, so do not compare the totals — measured against six
   correctly guarded shims on 2026-09-22, the comparison reported a
   finding on all six. `catch_unwind` also appears on the `use` line and
   in the doc comment that explains the guard, and entry points that
   delegate to one shared helper share its single guard, so the guard
   count is legitimately unequal to the entry-point count in both
   directions.

   Use the counts to find the files worth reading, then read them:

   ```sh
   grep -nE 'extern "C" fn [A-Za-z_]' src/ffi.rs   # every entry point
   grep -n  'catch_unwind'            src/ffi.rs   # every guard, use line included
   ```

   The first pattern matches definitions and not `Option<extern "C" fn(...)>`
   parameter types. Zero guards beside one or more entry points is the
   finding worth acting on. Any other ratio needs the file read: trace
   each entry point to the guard it reaches, directly or through the
   helper it calls.

2. **Every loop has a fixed upper bound.** Iterate over a slice or a
   `take(n)`. A `loop {}` carries a counted retry bound, not a condition.
   Never scan foreign memory for a sentinel: a C string from the caller
   arrives with a length parameter, or you bound it with `CStr::from_bytes_until_nul`
   over a slice of known length, never `CStr::from_ptr` on untrusted input.

   The length has to come from the protocol. `from_bytes_until_nul` needs a
   `&[u8]`, a `&[u8]` needs a length, and building one with
   `slice::from_raw_parts(ptr, MAX)` over a shorter allocation reads past
   the end — that trades an unbounded scan for undefined behavior and is
   never the fix. So at a bare `const char *` boundary this rule is
   unsatisfiable without changing the signature. That is a finding under
   Process step 5, not a reason to reach for the unsound bound: say the
   protocol carries no length, say what adding one would cost, and state
   the caller's promise in the `# Safety` section so it is a named limit
   rather than an omission.
   Check: every `while` and `loop` in the shim has a bound named in the
   same function.

3. **No dynamic allocation after initialization.** The literal rule does
   not fit Rust. Its purpose does: predictable memory ownership. At the
   boundary that means the same side allocates and frees. Prefer
   caller-provided buffers (`*mut u8`, `len`) to returning allocated memory.
   Every `<thing>_new` that hands ownership to foreign code has a
   `<thing>_free` beside it, and no other path frees that memory. No
   allocation inside a callback invoked from a foreign thread unless the
   contract says the callback may allocate.
   Check: `_new` and `_free` pairs match one-to-one in the header.

4. **Functions fit on one page, about 60 lines.** Applies as written. An
   `extern "C"` shim does checks, conversion, one call into safe Rust,
   and conversion back. Logic belongs in the safe function it calls.
   Check: `clippy::too_many_lines` at its default of 100 catches the worst.
   Set it to 60 for the shim crate.

5. **Two assertions per function, with recovery.** The rule requires an
   explicit recovery action, so at the boundary an assertion is a runtime
   check that returns an error code, not a panic: null pointer, zero or
   oversized length, misaligned pointer, invalid enum discriminant, handle
   already closed. Inside safe Rust, `debug_assert!` states invariants.
   Never `unwrap` or `expect` on anything that came from the caller.
   Check: each `extern "C"` function has at least one check per pointer
   parameter and one per length parameter, before the first dereference.

6. **Smallest scope for every data object.** No `static mut`. Shared state
   goes behind `OnceLock`, `Mutex`, or a handle the caller owns. Declare at
   first use. A `thread_local!` is a scope decision and needs a comment
   saying which thread owns it and why.
   Check: this is empty, comment lines included in the filter because
   `grep -rn` prefixes each hit with `file:line:`, so a bare `^//` never
   matches.

   ```sh
   grep -rn 'static mut' --include='*.rs' | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//'
   ```

   The comment filter matters: a codebase that got this right tends
   to carry a comment saying why it chose `AtomicI32` or `OnceLock` *over*
   a `static mut`, and the unfiltered grep turns that comment into a
   finding.

7. **Check every return value. Check every parameter.** `Result` is
   `#[must_use]` already, so a bare `fallible();` warns with no help. Put
   `#[must_use]` on every function that returns a plain status code
   (`c_int`), because integers are not. `let _ = fallible();` passes both,
   so enable `clippy::let_underscore_must_use` (restriction group) in the
   shim crate. Do not reach for `unused_results`: it fires on every
   discarded non-unit value, `HashMap::insert` included. Warnings become
   failures through rule 10's `-D warnings` in CI, never in source.
   Parameter checks are rule 5's checks. Nullable pointers are `Option<&T>`
   or `Option<extern "C" fn(...)>`, which are FFI-safe and force the check
   at the type level.
   Check: no `let _ =` on a `Result` or a status code in the shim.

8. **Preprocessor use limited.** Rust's equivalents are `macro_rules!`,
   proc macros, `cfg`, and `build.rs`. A macro expands to complete items
   and exists to remove boilerplate that would otherwise be copied per
   type. It never hides control flow or a dereference. Keep `cfg` to
   platform selection at module boundaries, not scattered through function
   bodies. Generated bindings (bindgen, cbindgen, ffigen) live in one
   module that is never hand-edited.
   Check: no `cfg` inside a function body in the shim. Grepping for
   `cfg(` answers a different question — it also matches the `#[cfg(test)]`
   on the test module, which every well-tested shim has. Look for `cfg`
   between a `fn` signature and its closing brace.

9. **Pointers restricted: one dereference, no function pointers.** Raw
   pointers exist only inside the `extern "C"` function that received them.
   Convert to a reference or a slice immediately after the rule 5 checks,
   and pass only safe types inward. One level of dereference: a `**T`
   out-parameter exists for the handle-out pattern only, and nowhere
   else. Function pointers are unavoidable for callbacks, so the rule's
   spirit applies: every callback has a typed `extern "C" fn` signature,
   is nullable only as `Option<extern "C" fn>`, is never produced by
   `transmute`, and carries a `*mut c_void` user-data pointer whose owner
   and lifetime the `# Safety` section names.
   Check: `slice::from_raw_parts` and `&*ptr` appear only in the shim
   module, never in the crate it calls.

10. **All warnings on, pedantic, and static analysis daily.** In source:
    `#![warn(clippy::pedantic)]` on the shim — see the scope note below —
    `#![deny(unsafe_op_in_unsafe_fn)]`, and `#![warn(missing_docs)]` so
    every public item has a doc comment. `missing_docs` does not demand a
    `# Safety` section. The lint that does, `clippy::missing_safety_doc`,
    fires only on `pub unsafe fn`. So declare every entry point that takes
    a raw pointer as `pub unsafe extern "C" fn`. That is the honest
    signature, since the caller must uphold the pointer contract, and it
    puts the section under a lint. A safe `pub extern "C" fn` gets its
    section from Process step 3 and from review, not from a lint. In CI
    only, never in source: `RUSTFLAGS=-Dwarnings`,
    `cargo clippy -- -D warnings`, and `cargo miri test` over the crate's
    `unsafe` code. Local: `bacon` with clippy as the default job, per
    preferred-tooling.
    Check: the CI job exists and fails on a warning.

    Scope: "the shim crate" assumes the shim is its own crate. When it is a
    module inside a larger crate, put the attributes on the module
    (`#![warn(...)]` at the top of the module file) rather than the crate
    root, and say why in a comment. Crate-wide `pedantic` on a crate whose
    other modules are not boundary code buries the findings that matter —
    measured on one workspace on 2026-09-22, 155 findings across six
    crates, 12 of them in the shims. A lint nobody reads is rule 10
    unsatisfied with the attribute present.

    Lint behavior in rules 7 and 10, the FFI-safety of
    `Option<extern "C" fn>`, and the abort in rule 1 were checked against
    rustc 1.94.1 and clippy 0.1.94 on 2026-09-22.

## The other side of the boundary

The rules bind the foreign side too, and the shim cannot enforce them
there. When writing the Dart, JS, Swift, or C caller:

- Rule 3: the caller frees what the shim says it owns, with the `_free`
  the shim provides, and nothing else. A finalizer is a backstop for a
  leak, never the primary release path.
- Rule 7: the call site checks every status code the shim returns.
- Rule 9: the user-data pointer handed to a callback stays alive for
  exactly the lifetime the `# Safety` section names.

State the mapping for that language in one line when you write the
caller. This skill does not carry it.

## Handoffs

- **code-critic** judges finished code against this rubric, TigerStyle,
  and Test Desiderata. Use this skill before, the critic after. Do not ask
  the critic to write.
- **ste100** owns the prose in `# Safety` sections and error strings, in
  strict mode. This skill says what the section must state. ste100 says
  how to state it so it has one reading.
- **TigerStyle** (`~/.agents/rubrics/tiger-style.md`) covers design goals
  and assertion style beyond these ten rules. Read it when the question is
  architecture rather than a function.

## Process

1. Name the boundary: which language calls in, on which thread, and who
   owns each pointer that crosses. If any of those is unknown, ask before
   writing.
2. Read the rubric.
3. Write the `# Safety` section first. It states the rule 3, 5, and 9
   contracts. Code that cannot satisfy its own section is wrong, not the
   section.
4. Write the shim: checks (rule 5), conversion (rule 9), one call into safe
   Rust (rule 4), conversion back, error code out (rule 7). Catch panics
   (rule 1).
5. Run the checks listed under each rule that the change touches. Report
   which rules the change could not satisfy and why. A bound that does not
   exist in the protocol is a finding for Alyssa, not a rule to skip
   silently.

## Output

The code, then one line per rule the change bends or cannot meet, in the
form `Rule N: <what> <why>`. Nothing when every rule holds.
