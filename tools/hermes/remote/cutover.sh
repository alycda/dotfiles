#!/usr/bin/env bash
# Move the running Hermes (gateway + workspace + signal-cli) between the 2012
# MBP and the remote box. Run from a third machine that can ssh to both.
#
#   cutover.sh to-box              MBP -> box
#   cutover.sh back                box off, MBP on; MBP resumes its OWN state
#   cutover.sh back --with-state   same, but the box's state goes home first
#   cutover.sh status              who is running what
#
# Invariant: at no instant are two signal-cli daemons up on the one account,
# and state is only ever read from a STOPPED stack. Every transition is
# stop -> verify stopped -> copy -> start.
#
# The ledger pipeline never moves. to-box pauses it (PAUSED stops model
# calls; the iCloud inbox is a queue, so PDFs wait) because its Signal
# notifications go through the signal-cli that is about to stop.
# shellcheck disable=SC2016  # '$HOME/...' is single-quoted on purpose: it must
# reach the far shell unexpanded (this machine's $HOME is not the MBP's).
set -euo pipefail

MBP="${HERMES_MBP:-alyssas-mbp-12.local}"
# An ssh_config alias, not an address: this repo is public, and the alias is
# also where the user and the non-default identity file live.
#   Host hermes-1 / HostName <ip> / User root / IdentityFile ~/.ssh/hetzner / IdentitiesOnly yes
BOX="${HERMES_BOX:-hermes-1}"
REMOTE_DIR=/srv/hermes/remote

# -4: the MBP's .local name resolves to a link-local IPv6 address first.
mbp() { ssh -4 -o BatchMode=yes -o ConnectTimeout=10 "$MBP" "export PATH=/usr/local/bin:\$PATH; $1"; }
box() { ssh -o BatchMode=yes -o ConnectTimeout=10 "$BOX" "$1"; }

MBP_CONTAINERS="hermes-workspace hermes-boxed signal-cli"

running() { # running <mbp|box> -> names of our containers that are up
  "$1" "docker ps --format '{{.Names}}' | grep -E '^(hermes-workspace|hermes-boxed|signal-cli)\$' || true"
}

require_stopped() {
  local up
  up="$(running "$1")"
  if [ -n "$up" ]; then
    echo "cutover: still running on $1: $up" >&2
    exit 1
  fi
}

# stream_dir <from> <src-parent> <name> <to> <dst-parent> [dst-name]
# tar-to-tar through this machine; nothing touches the local disk. Paths are
# double-quoted on the far side so a literal \$HOME expands THERE.
# COPYFILE_DISABLE keeps bsdtar from emitting AppleDouble ._ files;
# --numeric-owner keeps 501:20 on both ends (see docker-compose.yml).
stream_dir() {
  local from=$1 src=$2 name=$3 to=$4 dst=$5 dstname=${6:-$3}
  echo "  $from:$src/$name -> $to:$dst/$dstname"
  "$from" "cd \"$src\" && COPYFILE_DISABLE=1 tar --numeric-owner -cf - '$name'" |
    "$to" "mkdir -p \"$dst/.incoming\" && tar --numeric-owner -xpf - -C \"$dst/.incoming\" && rm -rf \"$dst/$dstname\" && mv \"$dst/.incoming/$name\" \"$dst/$dstname\" && rmdir \"$dst/.incoming\""
}

# stream_volume <from> <src-volume> <to> <dst-volume>
stream_volume() {
  local from=$1 srcvol=$2 to=$3 dstvol=$4
  echo "  $from:volume/$srcvol -> $to:volume/$dstvol"
  "$from" "docker run --rm -v '$srcvol':/v:ro debian:bookworm-slim tar --numeric-owner -cf - -C /v ." |
    "$to" "docker volume create '$dstvol' >/dev/null && docker run --rm -i -v '$dstvol':/v debian:bookworm-slim sh -c 'find /v -mindepth 1 -delete; tar --numeric-owner -xpf - -C /v'"
}

# count_files <host> <dir>: the cheap end-to-end check on a streamed copy.
count_files() { "$1" "find \"$2\" -type f | wc -l | tr -d ' '"; }

# set_ledger_mcp <host> <config.yaml> <true|false>
# The gateway's `ledger` MCP server is the broker on the MBP's loopback
# (host.docker.internal:8643). On the box nothing listens there, so the box's
# copy runs with it disabled and the MBP's copy keeps it; `back --with-state`
# turns it on again on the way home. Only `enabled:` inside mcp_servers.ledger
# is touched, and the result is read back: a pattern that silently matched
# nothing must not look like success. `cat >` rewrites in place, keeping the
# file's owner (501:20) and mode.
set_ledger_mcp() {
  local host=$1 cfg=$2 want=$3
  local flip='
    /^mcp_servers:/ { m = 1; print; next }
    m && /^[^ ]/    { m = 0 }
    m && /^  [^ ]/  { l = ($0 ~ /^  ledger:/) }
    m && l && /^    enabled:/ { sub(/enabled:.*/, "enabled: " want) }
    { print }'
  local read='
    /^mcp_servers:/ { m = 1; next }
    m && /^[^ ]/    { m = 0 }
    m && /^  [^ ]/  { l = ($0 ~ /^  ledger:/) }
    m && l && /^    enabled:/ { print $2 }'
  "$host" "awk -v want=$want '$flip' \"$cfg\" > \"$cfg.flip\" && cat \"$cfg.flip\" > \"$cfg\" && rm \"$cfg.flip\""
  local got; got="$("$host" "awk '$read' \"$cfg\"")"
  echo "  $host: mcp_servers.ledger.enabled = ${got:-<not found>}"
  [ "$got" = "$want" ]
}

to_box() {
  echo "== 1/5 pause the ledger pipeline, stop the MBP stack"
  mbp "touch ~/ledger-ingest/PAUSED"
  mbp "docker stop $MBP_CONTAINERS >/dev/null"
  require_stopped mbp
  require_stopped box

  echo "== 2/5 stream state"
  stream_dir mbp '$HOME/hermes-boxed' state box "$REMOTE_DIR"
  stream_dir mbp '$HOME/containers/signal-cli' state box "$REMOTE_DIR" signal-state
  mbp "cat ~/hermes-boxed/workspace.env" | box "umask 077; cat > $REMOTE_DIR/workspace.env"
  box "mkdir -p $REMOTE_DIR/artifacts && chown 501:20 $REMOTE_DIR/artifacts"

  echo "== 3/5 stream the workspace volumes"
  stream_volume mbp hermes-workspace_hermes-workspace-files box hermes-remote_workspace-files
  stream_volume mbp hermes-workspace_hermes-workspace-home box hermes-remote_workspace-home

  echo "== 4/5 verify the copy"
  local a b
  a="$(count_files mbp '$HOME/hermes-boxed/state')"; b="$(count_files box "$REMOTE_DIR/state")"
  echo "  state files:        mbp=$a box=$b"; [ "$a" = "$b" ]
  a="$(count_files mbp '$HOME/containers/signal-cli/state')"; b="$(count_files box "$REMOTE_DIR/signal-state")"
  echo "  signal-state files: mbp=$a box=$b"; [ "$a" = "$b" ]
  # After the counts, so they compare two untouched copies.
  set_ledger_mcp box "$REMOTE_DIR/state/config.yaml" false

  echo "== 5/5 start the box"
  box "cd $REMOTE_DIR && docker compose up -d"
  echo "cutover: box is live. The MBP stack is stopped with its state intact,"
  echo "         and ~/ledger-ingest/PAUSED is set. Verify with a Signal round-trip."
}

back() {
  echo "== 1/3 stop the box"
  box "cd $REMOTE_DIR && docker compose stop"
  require_stopped box
  require_stopped mbp

  if [ "${1:-}" = --with-state ]; then
    echo "== 2/3 carry state home (the MBP's copy is kept beside it)"
    local ts; ts="$(date +%Y%m%dT%H%M%S)"
    mbp "cp -Rp ~/hermes-boxed/state ~/hermes-boxed/state.pre-return-$ts && cp -Rp ~/containers/signal-cli/state ~/containers/signal-cli/state.pre-return-$ts"
    stream_dir box "$REMOTE_DIR" state mbp '$HOME/hermes-boxed'
    stream_dir box "$REMOTE_DIR" signal-state mbp '$HOME/containers/signal-cli' state
    # The box ran without the ledger; the MBP has the broker, so turn it back on.
    set_ledger_mcp mbp '$HOME/hermes-boxed/state/config.yaml' true
  else
    echo "== 2/3 no state copied; the MBP resumes from where it stopped"
  fi

  echo "== 3/3 start the MBP stack, resume the ledger pipeline"
  mbp "docker start signal-cli hermes-boxed hermes-workspace >/dev/null"
  mbp "rm -f ~/ledger-ingest/PAUSED"
  echo "cutover: MBP is live."
}

case "${1:-}" in
  to-box) to_box ;;
  back) back "${2:-}" ;;
  status)
    echo "mbp: $(running mbp | tr '\n' ' ')"
    echo "box: $(running box | tr '\n' ' ')"
    echo "mbp PAUSED: $(mbp 'test -e ~/ledger-ingest/PAUSED && echo yes || echo no')"
    ;;
  *)
    sed -n '2,10p' "$0" >&2
    exit 64
    ;;
esac
