---
title: "curl | sh bootstrap builds the image then dies: cannot attach stdin to a TTY-enabled container"
date: 2026-08-05
category: runtime-errors
module: docker/dev.sh
problem_type: runtime_error
component: tooling
severity: medium
symptoms:
  - "`curl -fsSL .../docker/dev.sh | sh -s -- up` finishes the build (`naming to docker.io/library/dev:latest`) and then prints 'cannot attach stdin to a TTY-enabled container because stdin is not a terminal'"
  - "No container starts; the exit status is docker's, not a build failure — rebuilding does not help because the build already succeeded"
  - "The identical `docker run -it ...` command typed by hand in the same terminal works"
root_cause: config_error
resolution_type: config_change
related_components:
  - development_workflow
  - documentation
tags:
  - docker
  - devcontainer
  - shell
  - posix-sh
  - tty
  - bootstrap
---

# `curl | sh` bootstrap builds the image then dies: cannot attach stdin to a TTY-enabled container

## Problem

The documented clone-free bootstrap

```sh
curl -fsSL https://raw.githubusercontent.com/alycda/dotfiles/main/docker/dev.sh | sh -s -- up
```

builds the image successfully — 268s of BuildKit output ending in `naming to
docker.io/library/dev:latest` — and then immediately fails:

```
cannot attach stdin to a TTY-enabled container because stdin is not a terminal
```

Nothing about the image, the flake, or home-manager is wrong. The build half of
`up` worked; the run half never started a container.

## Root cause

`sh -s` tells the shell to read its script **from stdin**, which is what makes
the curl pipe work at all. That means fd 0 of the shell — and of every command
it runs, including `docker` — is the pipe from curl, not the terminal.

`docker run -it` asks for two separate things: `-i` keeps stdin open and
attached, `-t` allocates a pseudo-terminal. Docker refuses the combination when
the stdin it is handed is not itself a terminal, because there would be no
terminal on the client end to relay to the pty. Hence the error, from the
docker CLI's client-side validation — the container is never created.

The tell that this is about *fd 0* and not about the environment: the same
command typed directly into the same terminal works. Only the pipe differs.

## Solution

The controlling terminal is still there — `curl | sh` runs inside a terminal
session, it just spent fd 0 on the pipe. A process with a controlling terminal
can always reopen it by name at `/dev/tty`, so `docker/dev.sh` hands that to the
container instead of inheriting the pipe:

```sh
run_container() {
  dir="${1:-$PWD}"
  set -- --rm \
    -v devhome:/root \
    -v claude-home:/root/.claude \
    -v "$dir":/work -w /work \
    "$IMAGE"

  if [ -t 0 ]; then
    exec docker run -it "$@"
  elif (true </dev/tty) 2>/dev/null; then
    exec docker run -it "$@" </dev/tty
  fi
  # ...no terminal anywhere: explain, exit 1
}
```

Three cases, in order:

1. **stdin is already a terminal** (`sh docker/dev.sh run`, `just docker-run`) —
   unchanged behaviour.
2. **stdin is a pipe but a controlling terminal exists** (`curl | sh`) — redirect
   the container's stdin from `/dev/tty`. `-it` is then honest: docker's client
   really does have a terminal to relay.
3. **No terminal at all** (CI, cron, `nohup`) — print the ready-to-paste
   `docker run` command and exit 1. Dropping to `docker run -i` without `-t`
   would "work" only in the sense that the shell would read EOF from the closed
   pipe and exit instantly; a silent no-op container is worse than a message.

Extracting `run_container` also removed the duplicated `docker run` invocation
that `run` and `up` each carried, which is how the two could have drifted.

### Details that matter in the probe

`(true </dev/tty) 2>/dev/null` looks over-engineered next to `[ -c /dev/tty ]`;
both halves are load-bearing:

- **The subshell.** A failed redirection on a *special builtin* (`:` is one,
  `true` is not) makes a POSIX non-interactive shell exit outright rather than
  return non-zero. Using `true` inside `( )` makes the failure a plain false
  branch under dash, bash and busybox alike.
- **Opening it, not stat-ing it.** `/dev/tty` exists as a device node in
  containers and daemonised sessions that have *no* controlling terminal; the
  open is what fails there (`ENXIO`), so only an actual open distinguishes
  case 2 from case 3.

## Verification

With a stub `docker` on `PATH` that reports whether its stdin is a tty, all
three cases were exercised under `sh`, `dash` and `bash` — case 2 reproduced
with `script -qec "cat dev.sh | sh -s -- run"`, which supplies a controlling
terminal while stdin stays a pipe, i.e. exactly the user-reported shape:

| invocation | branch | stdin seen by docker |
|---|---|---|
| `sh dev.sh run` under a pty | 1 | tty |
| `cat dev.sh \| sh -s -- run` under a pty | 2 | tty |
| `cat dev.sh \| sh -s -- run`, no pty | 3 | (refused with instructions) |

## Prevention

- **A script that may be piped into `sh` cannot assume fd 0.** Anything it runs
  interactively — `docker run -it`, `ssh -t`, a `read` prompt, `sudo` asking for
  a password — needs `< /dev/tty`, because the pipe owns fd 0 for the script's
  whole lifetime.
- **Test the delivery mechanism, not just the script.** `sh docker/dev.sh up`
  from a terminal passes while `curl … | sh -s -- up` fails; only the second is
  what the README tells people to run. Pipe it locally (`cat script | sh -s --
  …`) before publishing a curl-able command.
- **Keep the run invocation in one function.** `run` and `up` had byte-identical
  `docker run` blocks; a fix applied to one and not the other is the obvious
  next bug.

## Related

- PR #86 — where the report and the fix live.
- `docker/dev.sh` — the single source of truth for build/run; `just docker-*`
  and the README curl one-liner both go through it.
- `Dockerfile` header troubleshooting block — carries a short version of this
  entry for people who hand-write the `docker run`.
