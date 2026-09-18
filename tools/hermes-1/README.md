# hermes-1 — the always-on box

A small Hetzner Cloud VM (CX23, Helsinki, Debian 12), rented as a trial home
for Hermes and kept on 2026-09-18, mainly as a private git server. Nothing
deploys this directory: each file says where it lives on the box, and the box
is the running copy.

| Here | On the box |
|---|---|
| `soft-serve/docker-compose.yml` | `/srv/soft-serve/docker-compose.yml`, with `.env` (from `.env.example`) and `data/` beside it |
| `apt/52unattended-reboot` | `/etc/apt/apt.conf.d/52unattended-reboot` |

## Access

SSH is the only way in: the Hetzner cloud firewall admits port 22 alone
(checked 2026-09-18: a listener on another port answered on the box and timed
out from outside). Login is key-only. The box's address is kept in ssh config
aliases, never in this repo.

Soft Serve listens on the box's loopback. Reach it through the box's sshd:

```sshconfig
Host hermes-git
  HostName 127.0.0.1
  Port 23231
  ProxyJump hermes-1
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  HostKeyAlias hermes-git
  StrictHostKeyChecking yes
```

Pin its host key from the box rather than on first use, and derive it from the
private key: `ssh-keygen -y -f /srv/soft-serve/data/ssh/soft_serve_host_ed25519`.
The only `.pub` in that directory is Soft Serve's *client* key, and pinning it
fails as a host key mismatch.

```sh
ssh hermes-git repo create myrepo -p       # private repo
jj git remote add hermes hermes-git:myrepo  # then: jj git push --remote hermes -b <bookmark>
ssh hermes-git                             # TUI
```

Anonymous and keyless access are both off (upstream defaults to anonymous
read). An unknown key sees no repos and cannot clone, including non-private ones.

## Updates and reboots

`unattended-upgrades` installs security updates daily (Debian's default; the
run is around 06:30 UTC). `52unattended-reboot` lets it reboot when an update
needs one, at 11:00 UTC (04:00 Pacific). Every container on the box uses
`restart: unless-stopped` and docker starts at boot, so services come back by
themselves.

## Not covered yet

- Backups. `data/` (repos plus db) should be backed up as a unit, and the
  planned home for that is restic to R2.
