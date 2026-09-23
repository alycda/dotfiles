# Hyrum's Law

> Hyrum Wright. Canonical statement and essay: <https://www.hyrumslaw.com/>
> (named by Titus Winters; popularized in *Software Engineering at Google*).

> With a sufficient number of users of an API,
> it does not matter what you promise in the contract:
> all observable behaviors of your system
> will be depended on by somebody.

The essay's corollary, "The Law of Implicit Interfaces": *given enough use,
there is no such thing as a private implementation.* The documented contract
is the floor of what callers depend on, not the ceiling. The rest is the
implicit interface, and it grows without anyone deciding to grow it; the
essay's example is performance, which no contract promised and every consumer
came to expect. Its conclusion: "the interface reaches much deeper than you
think."

Read the essay itself; it is short. What follows is how this repo applies it,
not part of the original.

## Applying it

The law is a statement about scale, so first ask **who can observe this**.
A helper with one caller in the same change is not subject to it. A library,
a CLI, a config format, a wire protocol, an FFI boundary, or a file other
tools read is: its users are not in the diff.

For any change to such a surface, enumerate the observable behavior that
moves, **whether or not the contract promised it**:

- **Output shape**: field and key order, whitespace, trailing newlines,
  casing, the exact text of messages and errors (people `grep` them).
- **Ordering**: iteration order of maps and sets, sort stability, the order
  results or events arrive in.
- **Failure modes**: which inputs error versus succeed, exit codes, errno
  values, panic versus `Result`, what a partial failure leaves behind.
- **Defaults and absence**: default values, how empty or unset is treated
  (an empty env var dropped versus honored), what a missing field decodes to.
- **Timing and resources**: latency, allocation, blocking versus not, what
  happens under load. Unpromised, and depended on anyway.
- **Layout and ABI**: struct size, field offsets, alignment, symbol names,
  calling convention, ownership of returned memory. At an FFI boundary the
  implicit interface *is* the interface; there is no type checker on the far
  side.
- **Paths and names**: file locations, generated names, database names, env
  var names, anything another program finds by convention.

Then say, for each: is it promised, depended on (or plausibly so), or
neither? "Not in the contract" is not "safe to change". It is "no one was
warned it might change".

## What to do about it

In rough order of preference:

1. **Keep it unobservable in the first place.** Don't expose what you
   aren't willing to freeze. Randomizing unpromised behavior makes this
   hold in practice: Rust's `HashMap` seeds `RandomState` per instance, and
   Go randomizes map iteration order, so nobody can come to rely on one
   order.
2. **Promise it explicitly.** If callers already depend on a behavior and
   it's reasonable, write it into the contract and test it. The test then
   documents it.
3. **Change it deliberately.** Version it, deprecate first, give a
   migration, and treat the change as breaking, even though the contract
   says it isn't.
4. **Find the dependents before changing it.** Search callers (`sem
   impact`, `rg`) for the in-repo ones. For out-of-repo users, accept that
   search is incomplete and prefer 1-3.

## Precedent in this repo

Both came from the ghost.build client (#56), where "the CLI needs no patch
because we serve its OpenAPI contract" turned out to be false twice:

- The client hard-coded `dbName := "tsdb"`. The contract never said so; the
  hosted service made it true, because every database had its own instance.
- viper drops empty environment variables unless `AllowEmptyEnv` is set, so
  "set it to empty to disable" was never available from a wrapper.

In both cases the contract matched and the behavior the client depended on
did not.
