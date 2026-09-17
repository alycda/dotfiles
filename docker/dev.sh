#!/bin/sh
# Bootstrap/run helper for the dotfiles dev container.
#
# POSIX sh on purpose: the target machine may have nothing but docker - no
# git, no make (both come from Xcode CLT on macOS), no just, no nix. The
# script is also curl-able for a clone-free bootstrap:
#   curl -fsSL https://raw.githubusercontent.com/alycda/dotfiles/main/docker/dev.sh | sh -s -- start
# (`start` pulls the prebuilt arm64 image from GHCR; `up` builds it here
# instead - the fallback for an amd64 machine or a tree nobody has pushed.)
#
# The justfile's docker-* recipes delegate here - this file is the single
# source of truth for how the container is built and run.
#
# The image can come from three places - `build` (docker fetches the repo),
# `build-local` (this checkout) or `pull` (the prebuilt one the dev-image
# workflow pushed to GHCR, .github/workflows/dev-image.yml) - and all three
# end at the same local tag, $IMAGE. `run` and .devcontainer.json only ever
# name that tag, so where the image came from is invisible to them.

set -eu

REPO_URL="${REPO_URL:-https://github.com/alycda/dotfiles.git}"
IMAGE="${IMAGE:-dev}"
REGISTRY_IMAGE="${REGISTRY_IMAGE:-ghcr.io/alycda/dev}"

usage() {
  cat <<'USAGE'
usage: dev.sh <command>

  build [ref]    build the image; docker fetches the repo itself (no clone
                 needed). ref pins a branch/tag, default: default branch
  build-local    build from the checkout containing this script
  pull [tag]     skip the build: pull the prebuilt image from GHCR and tag it
                 as IMAGE. tag is latest (default), a branch name, or
                 sha-<short> - whatever the dev-image workflow pushed
  run [dir]      start the container, mounting dir (default: current
                 directory) at /work. devhome + claude-home volumes persist
                 nix/jj/ssh state and Claude auth across --rm
  up [ref]       build then run the current directory
  start [tag]    pull then run the current directory

env overrides: REPO_URL       (default: https://github.com/alycda/dotfiles.git)
               IMAGE          (default: dev)
               REGISTRY_IMAGE (default: ghcr.io/alycda/dev)

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

# Pull the prebuilt image and retag it as $IMAGE, so the rest of this script
# and .devcontainer.json keep naming `dev` whether it was built or pulled.
# The workflow tags a branch build with the branch name, every character
# outside [A-Za-z0-9._-] replaced by `-` (docker/metadata-action's ref
# sanitizing), so accept the ref as typed and apply the same rule. `docker
# pull` re-fetches a moved tag; `docker run` alone would keep using whatever
# `latest` was the first time.
#
# --platform is the architecture guard. The workflow publishes linux/arm64
# only, and a plain single-arch manifest pulls *successfully* onto an amd64
# daemon (the 2012 MBP) - it would then be retagged over the amd64 image
# `just docker-build` made, and `run` would exec an arm64 rootfs under
# emulation, with no message saying so. Asking for the daemon's own
# architecture makes that mismatch a hard error instead.
pull_image() {
  tag="$(printf '%s' "${1:-latest}" | sed 's/[^A-Za-z0-9._-]\{1,\}/-/g')"
  arch="$(docker version -f '{{.Server.Arch}}')"
  old="$(docker image inspect -f '{{.Id}}' "$IMAGE" 2>/dev/null || true)"
  if ! docker pull --platform "linux/$arch" "$REGISTRY_IMAGE:$tag"; then
    # The build fallback takes a git ref. A branch name works as typed; a
    # sha-<short> tag does not, because docker's remote build context only
    # fetches a commit by its full 40-character id, so for those say so
    # rather than suggest a command that fails.
    case "${1:-latest}" in
      latest) ref= ;;
      sha-*)  ref='<branch>' ;;
      *)      ref="$1" ;;
    esac
    cat >&2 <<HINT
dev.sh: could not pull $REGISTRY_IMAGE:$tag for linux/$arch. Likely causes:
  - the package is still private, or nothing has been pushed to it yet: an
    anonymous pull shows both as "denied". The dev-image workflow header in
    the repo has the one-time visibility step.
  - nothing was built with that tag ("manifest unknown"): dispatch the
    dev-image workflow on that ref first.
  - "does not match the specified platform": the workflow only publishes
    linux/arm64; an amd64 machine builds locally instead.
Build it here instead (the checkout is not needed; docker fetches the repo):
  curl -fsSL https://raw.githubusercontent.com/alycda/dotfiles/main/docker/dev.sh | sh -s -- up${ref:+ $ref}
HINT
    exit 1
  fi
  docker tag "$REGISTRY_IMAGE:$tag" "$IMAGE"
  # Retagging strands the previous image (~10GB) as dangling. Say so rather
  # than prune it: `docker image prune` is the user's call, and this is the
  # machine whose Dockerfile header already has a "no space left" recipe.
  new="$(docker image inspect -f '{{.Id}}' "$IMAGE")"
  if [ -n "$old" ] && [ "$old" != "$new" ] \
     && [ -z "$(docker image inspect -f '{{join .RepoTags " "}}' "$old" 2>/dev/null)" ]; then
    echo "dev.sh: the previous $IMAGE image is now dangling; reclaim it with: docker image prune"
  fi
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
  pull)
    pull_image "${1:-}"
    ;;
  run)
    run_container "${1:-$PWD}"
    ;;
  up)
    docker build -t "$IMAGE" "$REPO_URL${1:+#$1}"
    run_container "$PWD"
    ;;
  start)
    pull_image "${1:-}"
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
