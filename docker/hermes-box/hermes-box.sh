#!/bin/sh
# Hermes in a box - drive the locked-down Hermes stack in compose.yaml.
#
# POSIX sh for the same reason docker/dev.sh is: the machine this has to work on
# may have nothing but docker. This script is the single source of truth for
# env, profiles and the verification procedure; `just hermes-box-*` delegates
# here, exactly as the docker-* recipes delegate to docker/dev.sh.
#
#   ./hermes-box.sh init        # data dir + seeded config.yaml
#   ./hermes-box.sh verify      # PROVE the box has no route out
#   ./hermes-box.sh chat        # talk to it
#
# The boundary is `internal: true` on the hermes-box network. Everything else
# here - disabled web tools, proxy env vars, the allowlist - is depth behind
# that one structural fact.

set -eu

# Where the caller was, captured before the cd below: that directory - not this
# one - is what becomes the agent's /workspace by default.
invoked_from=$PWD
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cd "$here"

BOX_NET=hermes-box
EGRESS_NET=hermes-box-egress
NET_IMAGE=hermes-box-net:local
HERMES_CTR=hermes-box

: "${HERMES_BOX_MODE:=host-model}"          # host-model | contained-model
: "${HERMES_BOX_DATA:=$HOME/.hermes-box}"
: "${HERMES_BOX_WORKSPACE:=$invoked_from}"
: "${HERMES_BOX_WORKSPACE_MODE:=rw}"
export HERMES_BOX_DATA HERMES_BOX_WORKSPACE HERMES_BOX_WORKSPACE_MODE

# Host uid/gid so files the agent writes into /workspace are yours, not root's.
if [ -z "${HERMES_BOX_UID:-}" ]; then HERMES_BOX_UID=$(id -u); fi
if [ -z "${HERMES_BOX_GID:-}" ]; then HERMES_BOX_GID=$(id -g); fi
export HERMES_BOX_UID HERMES_BOX_GID

die() { echo "hermes-box: $*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
usage: hermes-box.sh <command> [args]

  init                 create the data dir and seed config.yaml (safe to re-run)
  up [--allowlist]     start the box; --allowlist also opens the filtered door
  down                 stop and remove the box's containers
  chat [args]          interactive Hermes TUI inside the box
  setup                Hermes' own setup wizard inside the box
  run <args>           any hermes subcommand inside the box (run kanban list)
  models               what the box can actually see on the model endpoint
  pull <model>         contained-model mode: fetch a model through the one door
  verify               prove it: no route out, model reachable, controls sane
  status               containers, and which network each one sits on
  logs [service]       docker compose logs -f
  proxy-log            the allowlist door's audit trail (every allow and deny)

env (all optional):
  HERMES_BOX_MODE=host-model       host-model | contained-model
  HERMES_BOX_DATA=~/.hermes-box    Hermes' whole state dir (/opt/data)
  HERMES_BOX_WORKSPACE=<cwd>       mounted at /workspace (the directory you
                                   ran this from; must not contain this box
                                   in rw mode)
  HERMES_BOX_WORKSPACE_MODE=rw     rw | ro
  HERMES_BOX_OLLAMA_UPSTREAM=host.docker.internal:11434
  HERMES_BOX_ALLOWLIST=./net/allowlist  must be outside an rw workspace;
                                   no symlink, one hard link
USAGE
}

# --- compose plumbing -------------------------------------------------------

if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"   # v1.28+ understands profiles; older does not
else
  die "no docker compose (v2 plugin) and no docker-compose on PATH"
fi

model_profile() {
  case "$HERMES_BOX_MODE" in
    host-model)      echo "--profile host-model" ;;
    contained-model) echo "--profile contained-model" ;;
    *) die "HERMES_BOX_MODE must be host-model or contained-model (got: $HERMES_BOX_MODE)" ;;
  esac
}

# The allowlist door is sticky: once it is up, later commands keep its profile
# active so `down` and `logs` still see it.
allowlist_profile() {
  if [ "${WANT_ALLOWLIST:-0}" = 1 ] || docker ps --format '{{.Names}}' 2>/dev/null | grep -qx hermes-box-egress-proxy; then
    echo "--profile allowlist"
  fi
}

dc() {
  # shellcheck disable=SC2046  # word splitting of the profile flags is intended
  $DC $(model_profile) $(allowlist_profile) "$@"
}

ensure_net_image() {
  docker image inspect "$NET_IMAGE" >/dev/null 2>&1 && return 0
  echo "hermes-box: building $NET_IMAGE (socat + tinyproxy + curl)" >&2
  docker build -q -t "$NET_IMAGE" "$here/net" >/dev/null
}

# The agent must never be able to write the box's own definition: compose.yaml,
# net/allowlist, net/tinyproxy.conf. With /workspace mounted rw over a directory
# that contains this one, it could widen its own allowlist and wait for the next
# `up --allowlist` to pick the edit up. The no-route claim would survive that;
# the allowlist door's would not. Checked on every command that starts the agent.
#
# HERMES_BOX_ALLOWLIST can move the allowlist out of this directory, so it gets
# the same check on its own: an allowlist inside the workspace is the same
# attack by a different path. A symlink or a second hard link could point into
# the workspace from outside it, so both are refused rather than chased.
guard_workspace() {
  [ "$HERMES_BOX_WORKSPACE_MODE" = rw ] || return 0
  ws=$(CDPATH='' cd -- "$HERMES_BOX_WORKSPACE" 2>/dev/null && pwd -P) \
    || die "workspace $HERMES_BOX_WORKSPACE does not exist"
  box=$(pwd -P)
  case "$box/" in
    "${ws%/}"/*)
      die "workspace $ws contains this box ($box), so the agent could rewrite
  its own allowlist. Run from the directory the agent should work in, or set
  HERMES_BOX_WORKSPACE=<dir>, or HERMES_BOX_WORKSPACE_MODE=ro." ;;
  esac

  # Relative paths resolve against this directory, as compose resolves them.
  al=${HERMES_BOX_ALLOWLIST:-./net/allowlist}
  [ ! -L "$al" ] || die "allowlist $al is a symlink - point HERMES_BOX_ALLOWLIST
  at the file itself, so where it lives can be checked"
  [ -f "$al" ] || die "allowlist $al is not a file"
  # shellcheck disable=SC2012  # field 2 (link count) precedes the name
  [ "$(ls -ld -- "$al" | awk '{print $2}')" = 1 ] \
    || die "allowlist $al has more than one hard link, so it may also be
  reachable from inside the workspace - give it a single link"
  al_dir=$(CDPATH='' cd -- "$(dirname -- "$al")" && pwd -P)
  case "$al_dir/" in
    "${ws%/}"/*)
      die "allowlist $al_dir/$(basename -- "$al") is inside the workspace $ws,
  so the agent could rewrite it. Keep HERMES_BOX_ALLOWLIST outside the
  workspace, or set HERMES_BOX_WORKSPACE_MODE=ro." ;;
  esac
}

# Run a shell snippet in a throwaway container on a given network.
on_net() {
  _net=$1; shift
  ensure_net_image
  docker run --rm --network "$_net" "$NET_IMAGE" sh -c "$*" 2>/dev/null
}

# --- commands ---------------------------------------------------------------

cmd_init() {
  mkdir -p "$HERMES_BOX_DATA"
  if [ -f "$HERMES_BOX_DATA/config.yaml" ]; then
    echo "config.yaml already exists at $HERMES_BOX_DATA/config.yaml (left alone)"
  else
    cp "$here/config.yaml.example" "$HERMES_BOX_DATA/config.yaml"
    echo "seeded $HERMES_BOX_DATA/config.yaml"
  fi
  # Hermes writes secrets to .env. In this box there should be nothing in it;
  # create it empty so the image does not prompt for one.
  [ -f "$HERMES_BOX_DATA/.env" ] || : > "$HERMES_BOX_DATA/.env"
  cat <<EOF

data dir : $HERMES_BOX_DATA
workspace: $HERMES_BOX_WORKSPACE ($HERMES_BOX_WORKSPACE_MODE)
mode     : $HERMES_BOX_MODE

next:
  1. edit $HERMES_BOX_DATA/config.yaml and set model.default to a model you have
     (host-model mode: \`ollama list\` on the host; contained: hermes-box.sh pull)
  2. from the directory the agent should work in:
       $here/hermes-box.sh up
  3. $here/hermes-box.sh verify     # do this before you trust anything above
  4. $here/hermes-box.sh chat
EOF
}

cmd_up() {
  [ -d "$HERMES_BOX_DATA" ] || die "no data dir - run: ./hermes-box.sh init"
  guard_workspace
  dc up -d
  echo
  dc ps
  echo
  echo "run './hermes-box.sh verify' - the boundary is not a thing to take on trust"
}

cmd_down() { WANT_ALLOWLIST=1; dc --profile fetch down "$@"; }

cmd_chat() { guard_workspace; dc run --rm hermes chat "$@"; }
cmd_setup() { guard_workspace; dc run --rm hermes setup "$@"; }
cmd_run() { [ $# -gt 0 ] || die "run needs a hermes subcommand"; guard_workspace; dc run --rm hermes "$@"; }

cmd_models() {
  out=$(on_net "$BOX_NET" 'curl -fsS -m 5 http://ollama:11434/v1/models') || {
    echo "no answer from http://ollama:11434/v1/models inside the box." >&2
    case "$HERMES_BOX_MODE" in
      host-model) echo "is ollama running on the host, and is the shim up? (./hermes-box.sh status)" >&2 ;;
      contained-model) echo "is the ollama service up, and has a model been pulled? (./hermes-box.sh pull <model>)" >&2 ;;
    esac
    return 1
  }
  # Tolerant of whitespace: ollama's /v1/models is compact, a proxy in front of
  # it may pretty-print. Falls back to the raw body rather than printing nothing.
  ids=$(echo "$out" | tr ',' '\n' | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  if [ -n "$ids" ]; then echo "$ids"; else echo "$out"; fi
}

cmd_pull() {
  [ $# -eq 1 ] || die "usage: hermes-box.sh pull <model>"
  [ "$HERMES_BOX_MODE" = contained-model ] || die "host-model mode: pull on the host instead (ollama pull $1)"
  echo "opening the fetch door (ollama-fetch on the egress network only)..."
  $DC --profile fetch up -d ollama-fetch
  # The image's entrypoint is the ollama binary; `serve` is its CMD. exec into
  # the running server to pull, then close the door again.
  $DC --profile fetch exec ollama-fetch ollama pull "$1"
  $DC --profile fetch stop ollama-fetch
  $DC --profile fetch rm -f ollama-fetch
  echo "door closed. model is in the hermes-box-ollama-models volume."
}

cmd_status() {
  printf '%-32s %s\n' CONTAINER NETWORKS
  for c in $(docker ps --filter label=com.docker.compose.project=hermes-box --format '{{.Names}}'); do
    nets=$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$c")
    printf '%-32s %s\n' "$c" "$nets"
  done
  echo
  printf 'network %s internal=%s\n' "$BOX_NET" \
    "$(docker network inspect "$BOX_NET" -f '{{.Internal}}' 2>/dev/null || echo '(not created yet)')"
}

cmd_logs() { dc logs -f "$@"; }
cmd_proxy_log() {
  docker ps --format '{{.Names}}' | grep -qx hermes-box-egress-proxy \
    || die "the allowlist door is not open (./hermes-box.sh up --allowlist)"
  docker logs -f hermes-box-egress-proxy
}

# --- verify: the part that matters ------------------------------------------
#
# Every claim here is checked against a CONTROL on the ordinary bridge network.
# A box that cannot reach the internet proves nothing if the host cannot reach
# it either - that is an inconclusive run, not a pass, and it says so.

pass=0; fail=0; incon=0
ok()   { pass=$((pass+1)); printf '  \033[32mok\033[0m    %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m  %s\n' "$1"; }
warn() { incon=$((incon+1)); printf '  \033[33m????\033[0m  %s\n' "$1"; }

# A probe that did not run must never read as a pass. Both agent-side probes
# therefore have to print something positive - the route table's header, or a
# CONNECTED/BLOCKED token - and anything else (exec failed, no python3 in the
# image, empty output) is inconclusive, not "no route".

# Classify a /proc/net/route dump: none | default | unreadable. Parsed here, on
# the host, so the probe needs only `cat` in the container, not awk.
route_state() {
  case "$1" in
    Iface*) ;;             # the header line: the table was actually read
    *) echo unreadable; return ;;
  esac
  if printf '%s\n' "$1" | awk '$2=="00000000"{f=1} END{exit !f}'; then
    echo default
  else
    echo none
  fi
}

report_route() {
  _who=$1; _table=$2
  case "$(route_state "$_table")" in
    none)    ok "$_who has no default route" ;;
    default) bad "$_who HAS a default route" ;;
    *)       warn "could not read the route table of $_who - the probe did not run" ;;
  esac
}

cmd_verify() {
  docker network inspect "$BOX_NET" >/dev/null 2>&1 || die "box network missing - run: ./hermes-box.sh up"
  ensure_net_image

  echo "topology"
  if [ "$(docker network inspect "$BOX_NET" -f '{{.Internal}}')" = true ]; then
    ok "$BOX_NET is internal (docker installs no gateway and no NAT for it)"
  else
    bad "$BOX_NET is NOT internal - everything below is theatre"
  fi

  table=$(on_net "$BOX_NET" 'cat /proc/net/route') || table=
  report_route "a container on $BOX_NET" "$table"

  echo
  echo "egress from inside the box (control: same probe on $EGRESS_NET)"
  # By raw IP first: this bypasses DNS entirely, so a pass cannot be explained
  # away by "name resolution was broken".
  control=0
  on_net "$EGRESS_NET" 'curl -s -m 8 -o /dev/null https://1.1.1.1/' && control=1
  if on_net "$BOX_NET" 'curl -s -m 8 -o /dev/null https://1.1.1.1/'; then
    bad "reached 1.1.1.1:443 from inside the box"
  elif [ "$control" = 1 ]; then
    ok "1.1.1.1:443 unreachable from the box, reachable from the control network"
  else
    warn "1.1.1.1:443 unreachable from the box - but also from the control network,"
    printf '        so this host proves nothing today (offline? corporate filter?)\n'
  fi

  control=0
  on_net "$EGRESS_NET" 'curl -s -m 8 -o /dev/null https://github.com/' && control=1
  if on_net "$BOX_NET" 'curl -s -m 8 -o /dev/null https://github.com/'; then
    bad "reached github.com from inside the box"
  elif [ "$control" = 1 ]; then
    ok "github.com unreachable from the box, reachable from the control network"
  else
    warn "github.com unreachable from both box and control - inconclusive"
  fi

  if on_net "$BOX_NET" 'getent hosts github.com >/dev/null'; then
    printf '  \033[36mnote\033[0m  names still RESOLVE inside the box (docker proxies DNS).\n'
    printf '        connect() is what fails. Resolution is not the boundary.\n'
  fi

  echo
  echo "the model door"
  if on_net "$BOX_NET" 'curl -fsS -m 5 http://ollama:11434/v1/models >/dev/null'; then
    ok "http://ollama:11434/v1/models answers inside the box"
    cmd_models 2>/dev/null | sed 's/^/        /'
  else
    bad "the model endpoint is unreachable inside the box (see: ./hermes-box.sh status)"
  fi

  if docker ps --format '{{.Names}}' | grep -qx hermes-box-egress-proxy; then
    echo
    echo "the allowlist door"
    # Plain HTTP first: a filtered GET comes back as a real 403 from tinyproxy.
    if [ "$(on_net "$BOX_NET" 'curl -s -m 8 -o /dev/null -w "%{http_code}" -x http://egress-proxy:8888 http://github.com/')" = 403 ]; then
      ok "proxy refuses an off-list host over HTTP (403)"
    else
      bad "proxy did NOT refuse github.com - check FilterDefaultDeny in net/tinyproxy.conf"
    fi
    # And over CONNECT, where the refusal kills the tunnel before TLS starts, so
    # curl reports a transport failure rather than an HTTP status.
    if on_net "$BOX_NET" 'curl -s -m 8 -o /dev/null -x http://egress-proxy:8888 https://github.com/'; then
      bad "proxy tunnelled CONNECT to an off-list host"
    else
      ok "proxy refuses an off-list host over CONNECT (no tunnel)"
    fi
    printf '  \033[36mnote\033[0m  allowed hosts are full bidirectional channels. Audit: ./hermes-box.sh proxy-log\n'
  fi

  # The real subject: the agent's own container, not a probe that looks like it.
  if docker ps --format '{{.Names}}' | grep -qx "$HERMES_CTR"; then
    echo
    echo "inside the agent container itself"
    table=$(docker exec "$HERMES_CTR" cat /proc/net/route 2>/dev/null) || table=
    report_route "$HERMES_CTR" "$table"
    # Only an OSError counts as blocked: that is what a refused, unreachable or
    # timed-out connect() raises. Anything else escapes, prints no token, and
    # lands in the inconclusive branch with the rest of "the probe never ran".
    sock=$(docker exec "$HERMES_CTR" python3 -c '
import socket
s = socket.socket(); s.settimeout(8)
try:
    s.connect(("1.1.1.1", 443)); print("CONNECTED")
except OSError as e:
    print("BLOCKED", e)' 2>/dev/null) || true
    case "$sock" in
      CONNECTED*) bad "$HERMES_CTR opened a socket to 1.1.1.1:443" ;;
      BLOCKED*)   ok "$HERMES_CTR cannot open a socket to 1.1.1.1:443 (${sock#BLOCKED })" ;;
      *)          warn "socket probe in $HERMES_CTR did not run (exec failed, or no python3 in the image)" ;;
    esac
  else
    printf '\n  \033[36mnote\033[0m  the hermes container is not running; checked the network, not the agent.\n'
  fi

  echo
  echo "$pass ok, $fail failed, $incon inconclusive"
  [ "$fail" -eq 0 ] || return 1
  [ "$incon" -eq 0 ] || return 2
}

# --- dispatch ---------------------------------------------------------------

cmd=${1:-}
[ $# -gt 0 ] && shift || true

# `up --allowlist` is the only flag that changes which profiles are active.
WANT_ALLOWLIST=0
case "${1:-}" in
  --allowlist) WANT_ALLOWLIST=1; shift ;;
esac

case "$cmd" in
  init)      cmd_init "$@" ;;
  up)        cmd_up "$@" ;;
  down)      cmd_down "$@" ;;
  chat)      cmd_chat "$@" ;;
  setup)     cmd_setup "$@" ;;
  run)       cmd_run "$@" ;;
  models)    cmd_models "$@" ;;
  pull)      cmd_pull "$@" ;;
  verify)    cmd_verify "$@" ;;
  status)    cmd_status "$@" ;;
  logs)      cmd_logs "$@" ;;
  proxy-log) cmd_proxy_log "$@" ;;
  ''|-h|--help|help) usage ;;
  *) usage >&2; exit 1 ;;
esac
