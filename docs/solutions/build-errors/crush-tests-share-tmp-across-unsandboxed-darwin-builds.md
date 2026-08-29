---
title: "crush failed to build with 'permission denied' on /tmp/crush-test — dissolved by moving off the nixpkgs source build"
date: 2026-08-29
category: build-errors
module: lib/charm-nur.nix
problem_type: build_error
component: tooling
severity: medium
symptoms:
  - "darwin-rebuild switch dies in crush's checkPhase: 'Cannot build /nix/store/...-crush-0.88.1.drv. Reason: builder failed with exit code 1.'"
  - "internal/agent tests fail with 'Received unexpected error: mkdir /tmp/crush-test/<TestName>: permission denied'"
  - "The cascade below it is noise: home-manager-applications, home-manager-path, user-environment, activation-<user> and darwin-system all report 'Reason: 1 dependency failed.'"
  - "The same nixpkgs revision builds crush fine on Linux, and built fine on this Mac the previous time"
  - "Surfaced by a flake.lock bump (#127) that does not touch crush's version at all"
root_cause: upstream_bug
resolution_type: dependency_change
related_components:
  - development_workflow
  - nix
tags:
  - nix
  - nix-darwin
  - crush
  - go
  - sandbox
  - unfree
  - flake-update
---

# crush failed to build with `permission denied` on `/tmp/crush-test`

**Status: no longer reachable.** PR #128 moved crush from nixpkgs to
`charmbracelet/nur`, which ships GoReleaser *release binaries* rather than a
source build — no `checkPhase`, so these tests never run here again. Kept
because the failure mode generalises to every package this repo still builds
from source on a Mac.

## Problem

`just _rebuild` on the Mac, against PR #127 (an automated `nix flake update`
whose CI was green), died here:

```
error: Cannot build '/nix/store/yc8wwgsk5cv9f5jbgv8iv9inpnh488vg-crush-0.88.1.drv'.
       Reason: builder failed with exit code 1.
       > --- FAIL: TestRun_QueuedRunIDPromptRunsRecursivelyAndPublishesRunComplete (0.00s)
       >     common_test.go:69:
       >          Error:  Received unexpected error:
       >                  mkdir /tmp/crush-test/TestRun_QueuedRunIDPromptRunsRecursivelyAndPublishesRunComplete: permission denied
```

crush's shared test fixture writes its scratch working directory to a **fixed
absolute path** (`internal/agent/common_test.go:65`, v0.88.1):

```go
workingDir := filepath.Join("/tmp/crush-test/", t.Name())
os.RemoveAll(workingDir)

err := os.MkdirAll(workingDir, 0o755)
require.NoError(t, err)
```

Every build on the machine therefore competes for one directory instead of
getting its own. On Linux this stays invisible — the build sandbox hands each
build a private `/tmp`. **Nix on darwin builds unsandboxed** (`sandbox`
defaults to false there, and nothing in `darwin/configuration.nix` turns it
on), so `/tmp/crush-test` is the machine's real one, shared across all 32
`_nixbld` users:

1. The first crush build creates it, owned by some `_nixbld`*N*, mode `0755`.
2. `os.RemoveAll(workingDir)` targets the *subdirectory*, so the stale parent
   survives — and its error is discarded anyway.
3. The next build draws a different `_nixbld` user and cannot create anything
   inside a directory it does not own. `EACCES`.

Read the error path closely: it names `/tmp/crush-test/<TestName>`, not
`/tmp/crush-test`. Go's `MkdirAll` reports the component it failed on, so the
parent already existed and was merely unwritable — which distinguishes this
from the other candidate explanation (a sandbox denying `/tmp` outright, which
would have failed one level up). Confirm on the machine with `ls -ld
/tmp/crush-test`: owned by an `_nixbld` user, not you.

## Why a lockfile bump surfaced it when crush didn't change

`pkgs/by-name/cr/crush/package.nix` was **byte-identical** at the old pin
(`e5bdc4a`) and the new one (`9fbb54b`) — same 0.88.1, same source hash, same
`checkFlags` skip list. Nothing about crush moved. What moved was everything
underneath: a nixpkgs bump ten days wide changes the Go toolchain and stdenv,
so crush's derivation hash changes, so it compiles again, so the checkPhase
runs again.

And crush compiled *locally* every time, because it is unfree (FSL-1.1-MIT)
and `cache.nixos.org` carries no binaries for unfree packages. So the source
build was on the critical path of every single flake update — with roughly
31-in-32 odds of drawing a losing build user once the stale directory existed.
`sudo rm -rf /tmp/crush-test` unblocks exactly one rebuild and re-arms the trap
for the next.

## Resolution

Superseded before it needed a fix of its own. **#128** replaced
`pkgs.crush` with `pkgs.charm-nur.crush` (`lib/charm-nur.nix`) for an unrelated
reason — nixpkgs' crush was three releases stale with no open bump PR. Charm's
NUR repo serves `fetchurl` of the GoReleaser tarball, `sourceProvenance =
binaryNativeCode`. No Go build, no `checkPhase`, no `/tmp/crush-test`.

That is worth noticing as a pattern and not just luck: **changing where a
package comes from can retire a class of local build failures that patching the
package would only have deferred.** The narrow fix considered here was an
overlay `substituteInPlace`-ing that one line to `t.TempDir()`; it would have
worked, and it would have needed re-checking on every crush bump forever.

## Prevention

- **On a Mac, "builds from source" and "has a hardcoded path in its tests" are
  a live combination.** Nix on darwin is unsandboxed, so anything a test writes
  outside `t.TempDir()` (or the build's own `$TMPDIR`) is shared with every
  other build on the host. The symptom is always the same shape: passes once,
  then `permission denied` forever.
- **Know which of your packages have no cache.** An upstream test bug in a
  cached package is someone else's problem, fixed by waiting for a channel
  bump. In a package with no binary cache — every entry in
  `lib/core-packages.nix` marked UNFREE — it is a hard blocker on your own
  rebuild, and the source of the package is a legitimate lever.
- **CI cannot catch this class.** The check job evaluates configurations
  (`.github/scripts/eval-configurations.sh`); it does not build them, and the
  runners are sandboxed Linux anyway. A green automated lockfile PR proves the
  lock evaluates, not that it builds on the Mac. `darwin-rebuild switch` is the
  first real build.
- **Read past the cascade.** Everything after the first `Reason: builder failed
  with exit code 1.` is `Reason: 1 dependency failed.` repeated up the tree to
  `darwin-system`. Only the first error carries information.
