#!/usr/bin/env bash
# docker-watchdog.sh — restart Docker Desktop when its VM dies.
#
# This machine is an always-on server, but Docker Desktop's hyperkit VM has died
# twice: once after a sleep (fixed with `pmset -c sleep 0`) and once with no
# identified cause. The failure is silent and total — the Docker.app UI process
# keeps running and logging while the VM is gone, so nothing looks wrong, but
# `docker ps` hangs forever and every container is unreachable. That takes down
# fava, signal-cli, the Hermes gateway, the ledger pipeline and the 08:30
# reminder at once.
#
# Detection: `docker info` with a hard timeout. Hanging IS the failure mode, so a
# plain exit-code check is not enough — we must bound the wait.
# Recovery: quit and relaunch Docker Desktop, then wait for the daemon.
#
# Runs every 10 minutes from launchd. Notifies via Signal on restart only.

set -uo pipefail
BIN=/Users/alyssa/ledger-ingest
DOCKER=/usr/local/bin/docker
LOG="$BIN/docker-watchdog.log"
STATE="$BIN/.docker-watchdog-last"
ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ echo "$(ts) $*" >> "$LOG"; }

# `timeout` is not on macOS; bound the call with a background kill instead.
docker_alive() {
    "$DOCKER" info >/dev/null 2>&1 &
    local pid=$!
    local n=0
    while kill -0 "$pid" 2>/dev/null; do
        n=$((n+1))
        [ "$n" -ge 30 ] && { kill -9 "$pid" 2>/dev/null; return 1; }   # ~30s
        sleep 1
    done
    wait "$pid" 2>/dev/null
}

if docker_alive; then
    exit 0
fi

log "docker unreachable — restarting Docker Desktop"

# Don't thrash: at most one restart per 30 minutes.
now=$(date +%s)
last=$(cat "$STATE" 2>/dev/null || echo 0)
case "$last" in ''|*[!0-9]*) last=0 ;; esac
if [ $(( (now - last) / 60 )) -lt 30 ]; then
    log "restart suppressed (last attempt $(( (now-last)/60 ))m ago) — needs a human"
    "$BIN/notify.sh" "docker: still down after a restart $(( (now-last)/60 ))m ago. Needs manual attention on the 2012 MBP." || true
    exit 1
fi
echo "$now" > "$STATE"

pkill -f "com.docker.cli" 2>/dev/null
pkill -f "^docker " 2>/dev/null
osascript -e 'quit app "Docker"' >/dev/null 2>&1
sleep 8
pkill -f "com.docker.backend" 2>/dev/null
sleep 3
open -a Docker
log "relaunched; waiting for daemon"

for i in $(seq 1 30); do
    sleep 10
    if docker_alive; then
        log "daemon back after ~$((i*10))s"
        running=$("$DOCKER" ps --format '{{.Names}}' 2>/dev/null | wc -l | tr -d ' ')
        "$BIN/notify.sh" "docker: VM had died; Docker Desktop restarted automatically. $running containers back up." || true
        exit 0
    fi
done

log "daemon did NOT return within 300s"
"$BIN/notify.sh" "docker: VM died and did NOT recover after an automatic restart. The 2012 MBP needs attention — fava, Hermes and the ledger pipeline are all down." || true
exit 1
