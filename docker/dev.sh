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
run_container() {
  dir="${1:-$PWD}"
  set -- --rm \
    -v devhome:/root \
    -v claude-home:/root/.claude \
    -v "$dir":/work -w /work \
    --network host \
    "$IMAGE"

  if in_foreground; then
    if [ -t 0 ]; then
      exec docker run -it "$@"
    elif (true </dev/tty) 2>/dev/null; then
      exec docker run -it "$@" </dev/tty
    fi
  fi

  # No terminal we may use: cron, CI, a detached session, or a backgrounded job
  # that SIGTTIN would stop. An interactive dev shell is not a thing we can
  # start here, and `docker run` without -it would just take EOF and exit. Say
  # so rather than hanging or failing inside docker.
  #
  # The command below is rendered from the same "$@" the exec branches use, so
  # it cannot drift from the real invocation. It did drift once, when
  # --network host was added above and the hand-written copy here kept the old
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
The image is built; start it from an interactive terminal with:
  docker run -it$hint
USAGE
  exit 1
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
