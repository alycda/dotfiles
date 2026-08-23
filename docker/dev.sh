#!/bin/sh
# Bootstrap/run helper for the dotfiles dev container.
#
# POSIX sh on purpose: the target machine may have nothing but docker - no
# git, no make (both come from Xcode CLT on macOS), no just, no nix. The
# script is also curl-able for a clone-free bootstrap:
#   curl -fsSL https://raw.githubusercontent.com/alycda/dotfiles/main/docker/dev.sh | sh -s -- up
#
# The justfile's docker-* recipes delegate here - this file is the single
# source of truth for how the container is built and run.

set -eu

REPO_URL="${REPO_URL:-https://github.com/alycda/dotfiles.git}"
IMAGE="${IMAGE:-dev}"

usage() {
  cat <<'USAGE'
usage: dev.sh <command>

  build [ref]    build the image; docker fetches the repo itself (no clone
                 needed). ref pins a branch/tag, default: default branch
  build-local    build from the checkout containing this script
  run [dir]      start the container, mounting dir (default: current
                 directory) at /work. devhome + claude-home volumes persist
                 nix/jj/ssh state and Claude auth across --rm
  exec [ctr]     open a second shell in a container already started by `run`,
                 forwarding $TERM (default: the newest one from this image)
  up [ref]       build then run the current directory

env overrides: REPO_URL (default: https://github.com/alycda/dotfiles.git)
               IMAGE    (default: dev)

ssh-agent forwarding and the ragenix age key are manual extras - see the
Dockerfile header in the repo.
USAGE
}

# True when we are the terminal's foreground process group - the condition for
# being allowed to read it and reconfigure it. Having a terminal is not the
# same as being allowed to use it: a backgrounded or job-controlled invocation
# keeps its controlling terminal, so `[ -t 0 ]` and an open of /dev/tty both
# still succeed there, but `docker run -it` then reads the tty and calls
# tcsetattr from a non-foreground group, takes SIGTTIN/SIGTTOU and silently
# stops. A silent stop is exactly what the loud fallback below exists to
# prevent, so this gates *both* terminal branches, not just the /dev/tty one.
#
# A ps without pgid/tpgid (busybox) leaves both sides empty and equal, which
# degrades to the previous behaviour rather than refusing to run.
in_foreground() {
  [ "$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')" \
    = "$(ps -o tpgid= -p $$ 2>/dev/null | tr -d ' ')" ]
}

# `docker run -it` demands a terminal on stdin. Piping this script into sh -
# the documented curl bootstrap - makes stdin the curl pipe, and docker aborts
# with "cannot attach stdin to a TTY-enabled container because stdin is not a
# terminal". The controlling terminal is still reachable as /dev/tty in that
# case (the pipeline runs in a terminal; only fd 0 was taken), so borrow it for
# the container instead of demanding the caller reshape their command line.
#
# "$@" is the complete docker argv - subcommand, -it and all - so this serves
# `run` and `exec` alike.
attach_tty() {
  if in_foreground; then
    if [ -t 0 ]; then
      exec docker "$@"
    elif (true </dev/tty) 2>/dev/null; then
      exec docker "$@" </dev/tty
    fi
  fi

  # No terminal we may use: cron, CI, a detached session, or a backgrounded job
  # that SIGTTIN would stop. An interactive dev shell is not a thing we can
  # start here, and `docker run` without -it would just take EOF and exit. Say
  # so rather than hanging or failing inside docker.
  #
  # The command below is rendered from the same "$@" the exec branches use, so
  # it cannot drift from the real invocation. It did drift once, when
  # --network host was added below and the hand-written copy here kept the old
  # flag list.
  hint=
  for arg in "$@"; do
    case "$arg" in
      *[!A-Za-z0-9_/.:=-]*) hint="$hint '$arg'" ;;
      *)                    hint="$hint $arg" ;;
    esac
  done
  cat >&2 <<USAGE
dev.sh: no terminal available, so the container's shell has nothing to attach to.
Run this from an interactive terminal instead:
  docker$hint
USAGE
  exit 1
}

run_container() {
  dir="${1:-$PWD}"
  attach_tty run -it --rm \
    -v devhome:/root \
    -v claude-home:/root/.claude \
    -v "$dir":/work -w /work \
    --network host \
    "$IMAGE"
}

# Second shell into the container that `run` started.
#
# `-e TERM` is the point of this existing at all. A plain `docker exec` builds
# its environment from the image, not from the terminal you typed the command
# into, so TERM is unset and the container falls back to `xterm` - a 1980s
# description that silently mis-renders everything a modern terminal does
# (alt-screen, scrollback, 256 colors, modified arrow keys). Forwarding the
# host's TERM is the other half of shipping a terminfo database; issue #116 was
# both halves missing at once, and neither half is any use alone.
#
# Falls back to xterm-256color rather than to nothing when the caller has no
# TERM (a cron job, an editor's task runner): still a guess, but a guess that
# matches what the container can actually do.
#
# The container is found by image, since `run` deliberately doesn't --name it
# (that would cap you at one). Pass a name or id to pick a specific one.
exec_container() {
  target="${1:-}"
  if [ -z "$target" ]; then
    target=$(docker ps -q --filter "ancestor=$IMAGE" | head -n 1)
  fi
  if [ -z "$target" ]; then
    cat >&2 <<USAGE
dev.sh: no running container found for image '$IMAGE'.
Start one with:  dev.sh run
...or name an already-running container:  dev.sh exec <name-or-id>
USAGE
    exit 1
  fi

  # Same guarded launch as the image's CMD: zsh comes from the home-manager
  # profile, and if activation failed it does not exist. Dropping to bash keeps
  # the container's own recovery instructions reachable.
  attach_tty exec -it -e TERM="${TERM:-xterm-256color}" "$target" \
    sh -c 'if command -v zsh >/dev/null 2>&1; then exec zsh -l; else exec bash -l; fi'
}

cmd="${1:-}"
[ $# -gt 0 ] && shift

case "$cmd" in
  build)
    docker build -t "$IMAGE" "$REPO_URL${1:+#$1}"
    ;;
  build-local)
    docker build -t "$IMAGE" "$(dirname "$0")/.."
    ;;
  run)
    run_container "${1:-$PWD}"
    ;;
  exec)
    exec_container "${1:-}"
    ;;
  up)
    docker build -t "$IMAGE" "$REPO_URL${1:+#$1}"
    run_container "$PWD"
    ;;
  ''|-h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
