# Behavioral Subtyping (Liskov Substitution)

> Barbara Liskov and Jeannette M. Wing, "A Behavioral Notion of Subtyping",
> ACM TOPLAS 16(6), November 1994, pp. 1811–1841.
> <https://dl.acm.org/doi/10.1145/197320.197383>. The formal version of the
> substitution property from Liskov's 1987 OOPSLA keynote, "Data Abstraction
> and Hierarchy".

The Subtype Requirement:

> Let φ(x) be a property provable about objects x of type T. Then φ(y)
> should be true for objects y of type S where S is a subtype of T.

## The rules

Paraphrased from the paper. S may stand in for T only if:

- **Signatures**: argument types are contravariant, result types are
  covariant, and S's methods raise no exceptions T's did not declare.
- **Preconditions** are not strengthened: whatever T accepts, S accepts.
- **Postconditions** are not weakened: whatever T guarantees, S
  guarantees.
- **Invariants** are preserved: every invariant of T holds for S.
- **History constraint**: S permits no state change T's specification
  rules out, *including through methods T does not have*. This rule is the
  paper's own contribution, and the one that matters for mutable types. A
  mutable subtype of an immutable type fails it, whatever its signatures
  say.

Everything below is how this repo applies the rules, not part of the paper.

## Applying it

Rust has almost no subtyping (lifetimes and variance only), so the type
checker rarely raises this question. The rules still apply wherever one
thing stands in for another behind a contract. Route here when reviewing:

- **A trait impl.** It must honor the trait's documented contract, not only
  its signature. `Hash` must agree with `Eq`, `Ord` must be a total order,
  `ExactSizeIterator::len` must be exact, `Borrow` must preserve `Eq`, `Ord`
  and `Hash`. The compiler accepts a violation, and the bug shows up as
  wrong behavior elsewhere, in someone else's `HashMap` or `sort`.
- **An `unsafe trait` impl** (`Send`, `Sync`, `GlobalAlloc`). Here the
  contract is a soundness obligation, so a violation is undefined
  behavior. Cite the specific safety requirement the impl relies on.
- **An alternate implementation**: a second backend, a replacement library
  behind an FFI boundary, a server written for someone else's client. There
  is no type system across the boundary, so the specification is the only
  check. Write down which one you are matching.
- **A new version of anything with users.** Semver's "compatible" means
  "a behavioral subtype of the previous version's specification". A
  weakened postcondition or a new failure mode is a breaking change even
  when every signature is unchanged.
- **A test double** (fake, stub, mock). A double that violates the contract
  of the thing it replaces (accepts what the real one rejects, never fails
  where the real one can, orders results differently) makes the tests pass
  for the wrong reason. Judge it by the same rules as an implementation.

For each, name the rule at stake (precondition, postcondition, invariant,
history), what the contract says, and what the implementation does.

## Relation to Hyrum's Law

The two answer halves of one question, "can Y replace X?":

- **Liskov is normative**: Y must preserve what is *provable from the
  specification*. The contract is the floor.
- **Hyrum is empirical** (`hyrums-law.md`): with enough users, they depend
  on everything *observable*. The contract is not the ceiling.

A replacement that passes this rubric is correct. Whether it is safe to
ship depends on the other one: the specification its users rely on is
larger than the one written down.
