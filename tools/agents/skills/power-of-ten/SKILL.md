---
name: power-of-ten
description: >
  Make the contract decisions NASA/JPL's Power of Ten rules require before
  writing systems code: Rust crates that expose an `extern "C"` surface, FFI
  shims, callbacks crossing a language boundary, `unsafe` blocks, and the
  Dart/JS code that calls them. Trigger on "power of ten", "power of 10",
  "holzmann", "safety-critical", "bounded", "assertion density", or when
  Alyssa is about to write or edit an `extern "C"` function, an `unsafe`
  block, a callback registered with foreign code, or a loop over
  foreign-owned memory. Carries the rules that must be settled before the
  code exists (who owns each pointer, who frees, where panics stop, what the
  `# Safety` section promises). The mechanical rules and every check live in
  the reviewer's rubric and are applied by `review` / `code-critic`, not
  here.
---

# Power of Ten

Gerard Holzmann wrote the ten rules (NASA/JPL, 2006) for C on spacecraft.
Alyssa's daily work is a Rust core behind `extern "C"` shims, called from
Dart, JS/wasm, Swift, and C. The rules map cleanly, but they split into two
kinds. Rules 1, 2, 3, 5, and 9 are contract decisions: who owns each
pointer, who frees, where a panic stops, what a length means. Retrofitting
one of those is a rewrite, so they must be settled before the code exists,
and this skill carries them. Rules 4, 6, 7, 8, and 10 are mechanical, and
a reviewer with a diff or a lint can apply them after the fact, so they
live in the reviewer's rubric and this skill does not repeat them.

## The rules live in the rubrics

Read `~/.agents/rubrics/power-of-ten.md` before you apply this skill. It is
the ten rules verbatim. `agents.nix` builds `code-critic` from the same
file, so what this skill guides and what the critic judges cannot drift.

`~/.agents/rubrics/power-of-ten-rust-ffi.md` is the reviewer's half: the
Rust mapping of the mechanical rules and the check for every rule. Do not
run those checks while writing. They are what the `review` skill and the
`code-critic` agent apply to the finished diff, and the implementer's job
is the code.

If either file does not exist, say so and stop. Do not reconstruct the
rules from memory. `agents.nix` deploys `tools/agents/rubrics/` to that path.

## The contract rules, in Rust at an FFI boundary

1. **Simple control flow, no recursion.** No recursion in any function
   reachable from an `extern "C"` entry point or a foreign-invoked callback.
   Walk trees with an explicit stack and a bound. No panic may reach an
   `extern "C"` frame. Since Rust 1.81 the non-unwind ABIs abort the process
   on an uncaught unwind, and before 1.81 that was undefined behavior. Wrap
   the body in `std::panic::catch_unwind` and convert to an error code.
   `extern "C-unwind"` is a deliberate choice with a comment, never a
   default. Entry points that delegate to one shared helper may share its
   single guard.

2. **Every loop has a fixed upper bound.** Iterate over a slice or a
   `take(n)`. A `loop {}` carries a counted retry bound, not a condition.
   Never scan foreign memory for a sentinel: a C string from the caller
   arrives with a length parameter, or you bound it with
   `CStr::from_bytes_until_nul` over a slice of known length, never
   `CStr::from_ptr` on untrusted input.

   The length has to come from the protocol. `from_bytes_until_nul` needs a
   `&[u8]`, a `&[u8]` needs a length, and building one with
   `slice::from_raw_parts(ptr, MAX)` over a shorter allocation reads past
   the end. That trades an unbounded scan for undefined behavior and is
   never the fix. So at a bare `const char *` boundary this rule is
   unsatisfiable without changing the signature. That is a finding under
   Process step 5, not a reason to reach for the unsound bound: say the
   protocol carries no length, say what adding one would cost, and state
   the caller's promise in the `# Safety` section so it is a named limit
   rather than an omission.

3. **No dynamic allocation after initialization.** The literal rule does
   not fit Rust. Its purpose does: predictable memory ownership. At the
   boundary that means the same side allocates and frees. Prefer
   caller-provided buffers (`*mut u8`, `len`) to returning allocated memory.
   Every `<thing>_new` that hands ownership to foreign code has a
   `<thing>_free` beside it, and no other path frees that memory. No
   allocation inside a callback invoked from a foreign thread unless the
   contract says the callback may allocate.

5. **Two assertions per function, with recovery.** The rule requires an
   explicit recovery action, so at the boundary an assertion is a runtime
   check that returns an error code, not a panic: null pointer, zero or
   oversized length, misaligned pointer, invalid enum discriminant, handle
   already closed. Inside safe Rust, `debug_assert!` states invariants.
   Never `unwrap` or `expect` on anything that came from the caller.

9. **Pointers restricted: one dereference, no function pointers.** Raw
   pointers exist only inside the `extern "C"` function that received them.
   Convert to a reference or a slice immediately after the rule 5 checks,
   and pass only safe types inward. One level of dereference: a `**T`
   out-parameter exists for the handle-out pattern only, and nowhere else.
   Function pointers are unavoidable for callbacks, so the rule's spirit
   applies: every callback has a typed `extern "C" fn` signature, is
   nullable only as `Option<extern "C" fn>`, is never produced by
   `transmute`, and carries a `*mut c_void` user-data pointer whose owner
   and lifetime the `# Safety` section names.

Rules 4, 6, 7, 8, and 10 (function length, `static mut`, `#[must_use]` and
`let _`, `cfg` placement, lint attributes and CI flags) are in the reviewer's
rubric. Writing with them in mind costs nothing; verifying them is not this
skill's job.

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

- **review** runs the Standards axis (`code-critic`, which holds both
  rubrics) and the Spec axis over the diff once the code is committed.
  Use this skill before, `review` after. Do not ask the critic to write.
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
2. Read the verbatim rubric.
3. Write the `# Safety` section first. It states the rule 3, 5, and 9
   contracts. Code that cannot satisfy its own section is wrong, not the
   section.
4. Write the shim: checks (rule 5), conversion (rule 9), one call into safe
   Rust, conversion back, error code out. Catch panics (rule 1).
5. Commit, then hand off to `review`. Report here only the rules the
   change could not satisfy and why. A bound that does not exist in the
   protocol is a finding for Alyssa, not a rule to skip silently.

## Output

The code, then one line per contract rule the change bends or cannot meet,
in the form `Rule N: <what> <why>`. Nothing when every rule holds. The
mechanical rules are reported by `review`, not here.
