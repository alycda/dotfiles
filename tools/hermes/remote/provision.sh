#!/usr/bin/env bash
# Provision the temporary Hermes box (Hetzner CX23, Debian 12). Run as root,
# over ssh, from a checkout:
#
#   ssh hermes-1 'bash -s' < tools/hermes/remote/provision.sh
#
# Safe to run again: every step checks before it changes anything.
#
# What it leaves behind: key-only sshd, 2G of swap, Docker from Docker's own
# apt repository, the two published images pulled BY DIGEST, and an empty
# /srv/hermes. It does not start anything and copies no state; the
# cutover from the MBP is a separate, deliberate step (only one signal-cli
# may receive at a time — two gateways double-handled a message on 09-15).
set -euo pipefail

# The digests that were running on the MBP on 2026-09-16. `:latest` today is
# not necessarily what wrote ./state, and a newer hermes-agent is free to
# migrate the state schema on first boot. Pull what was running; bump on
# purpose.
HERMES_AGENT='nousresearch/hermes-agent@sha256:6bdcde696e5e5fa3dc7d93b88f025d018238d937a1048ca5ff1ab68fa807a5db'
HERMES_WORKSPACE='ghcr.io/outsourc-e/hermes-workspace@sha256:2d2ba9aa5b1230766267322817e8e51113541780a5797802a582a47cc34a3df3'

export DEBIAN_FRONTEND=noninteractive

# --- sshd: keys only -------------------------------------------------------
# Hetzner's Debian image ships PasswordAuthentication yes even when the
# server was created with an ssh key. root has no password set, so it is not
# exploitable today; it becomes so the day anyone runs `passwd`.
drop=/etc/ssh/sshd_config.d/10-keys-only.conf
if [ ! -f "$drop" ]; then
  printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin prohibit-password\n' >"$drop"
  sshd -t
  systemctl reload ssh
fi

# --- swap ------------------------------------------------------------------
# 4G of RAM and no swap. The three containers idle at ~660M, but signal-cli
# is a JVM and the draft runner bursts; swap turns an OOM kill into a slow
# minute.
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >>/etc/fstab
fi

# --- Docker ----------------------------------------------------------------
# Docker's repository rather than Debian's docker.io: bookworm carries 20.10
# with compose v1 as a separate Python package, and the compose files here
# use v2 syntax (`name:`, `profiles:`).
if ! command -v docker >/dev/null; then
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl rsync >/dev/null
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  # shellcheck disable=SC1091
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    >/etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin >/dev/null
fi

# Cap container logs. The default json-file driver has no limit, and this
# disk is 38G.
if [ ! -f /etc/docker/daemon.json ]; then
  printf '{\n  "log-driver": "json-file",\n  "log-opts": { "max-size": "10m", "max-file": "3" }\n}\n' >/etc/docker/daemon.json
  systemctl restart docker
fi

# --- layout + images -------------------------------------------------------
# /srv/hermes mirrors tools/hermes/ (rsynced at cutover), so the compose
# file's relative build path to mbp12-host/signal-cli resolves unchanged.
install -d -m 0700 /srv/hermes

docker pull -q "$HERMES_AGENT"
docker pull -q "$HERMES_WORKSPACE"

echo "== done"
docker --version
docker compose version
swapon --show
sshd -T | grep -E '^(passwordauthentication|permitrootlogin) '
