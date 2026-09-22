# venari — the always-on box

A small rented VM (2 vCPU, 4 GB, 38 GB disk, Debian 12, Helsinki). It was
stood up on 2026-09-16 as a trial home for Hermes, and kept on 2026-09-18.
Hermes moved back to felixia on 2026-09-21 — the agent needs the ledger broker
on felixia's loopback and the iCloud inbox, and neither can follow it here —
so what this box is now is a private git server and a small dev box.

The name is its own, like felixia's: it says nothing about the provider, the
plan, or what happens to be running this week. All three have already changed
once.

Nothing deploys this directory: each file says where it lives on the box, and
the box is the running copy.

| Here | On the box |
|---|---|
| `soft-serve/docker-compose.yml` | `/srv/soft-serve/docker-compose.yml`, with `.env` (from `.env.example`) and `data/` beside it |
| `apt/52unattended-reboot` | `/etc/apt/apt.conf.d/52unattended-reboot` |
| `cloud/99-hostname.cfg` | `/etc/cloud/cloud.cfg.d/99-hostname.cfg` |
| `ssh/20-soft-tunnel.conf` | `/etc/ssh/sshd_config.d/20-soft-tunnel.conf` |
| `ssh/soft-tunnel.authorized_keys` | `/var/lib/soft-tunnel/.ssh/authorized_keys` (root-owned, 644) |
| `ghost/docker-compose.yml` | `/srv/ghost/docker-compose.yml`, with `.env` (from `.env.example`), `certs/`, `data/` and `server/` beside it |
| `ghost/server/Dockerfile` | `/srv/ghost/server/Dockerfile`, next to the `ghost-server` binary it packages |

The dev-box side is `tools/mise/venari/` — the same arrangement felixia has,
for the same reason: no Nix here either.

## Access

SSH is the only way in: the provider's cloud firewall admits port 22 alone
(checked 2026-09-18: a listener on another port answered on the box and timed
out from outside). Login is key-only. The box's address is kept in ssh config
aliases, never in this repo.

Day-to-day login is the unprivileged user `alyssa` (`Host venari`), which owns
the dev tools and its own mise config. Root is a separate alias
(`Host venari-root`) and is what the system files in this directory are
installed with; `alyssa` is deliberately not in the `docker` group, since
membership there is root-equivalent.

Soft Serve listens on the box's loopback. Reach it through the box's sshd:

```sshconfig
Host venari-git
  HostName 127.0.0.1
  Port 23231
  ProxyJump venari
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  HostKeyAlias venari-git
  StrictHostKeyChecking yes
```

Pin its host key from the box rather than on first use, and derive it from the
private key: `ssh-keygen -y -f /srv/soft-serve/data/ssh/soft_serve_host_ed25519`.
The only `.pub` in that directory is Soft Serve's *client* key, and pinning it
fails as a host key mismatch.

```sh
ssh venari-git repo create myrepo -p       # private repo
jj git remote add venari venari-git:myrepo  # then: jj git push --remote venari -b <bookmark>
ssh venari-git                             # TUI
```

Anonymous and keyless access are both off (upstream defaults to anonymous
read). An unknown key sees no repos and cannot clone, including non-private ones.

## felixia's access: one tunnel, one repo

felixia pushes an age-encrypted bundle of its ledger (`offsite-ledger.sh` in
the ledger pipeline) to the private repo `ledger-age`. Only ciphertext is
stored here: the ledger's own pre-push hook forbids plaintext copies off that
disk. felixia gets exactly the access that needs, in two layers on the box and
one in Soft Serve:

- **Box user `soft-tunnel`**, a system user with `/usr/sbin/nologin` as its
  shell. Its key line (`restrict,port-forwarding,permitopen=...`) allows one
  local forward to Soft Serve's loopback port and nothing else. The file is
  root-owned, so the user cannot edit its own line.
- **`20-soft-tunnel.conf`** repeats that for the user in sshd itself, and adds
  what a key line cannot: `AllowTcpForwarding local` blocks `-R`, which the
  key's `port-forwarding` would otherwise re-enable.
- **Soft Serve user `felixia`**: not an admin, and a read-write collaborator on
  `ledger-age` only.

Setup, from a machine with root on the box and Soft Serve admin:

```sh
# on the box
useradd --system --home-dir /var/lib/soft-tunnel --create-home \
  --shell /usr/sbin/nologin soft-tunnel
install -d -m 755 -o root -g root /var/lib/soft-tunnel/.ssh
install -m 644 -o root -g root soft-tunnel.authorized_keys /var/lib/soft-tunnel/.ssh/authorized_keys
install -m 644 20-soft-tunnel.conf /etc/ssh/sshd_config.d/
sshd -t                                   # then compare `sshd -T -C user=root,...`
systemctl reload ssh                      # before and after: root's must not change

# Soft Serve
ssh venari-git user create felixia
ssh venari-git user add-pubkey felixia "'ssh-ed25519 AAAA...'"   # the quotes survive ssh's re-split
ssh venari-git repo create ledger-age -p
ssh venari-git repo collab add ledger-age felixia read-write
```

The risk with a `Match` block in an included file is that it stays open and
captures the directives that follow the `Include` in the main config, changing
them for everyone. Not measured in general; here, `sshd -t` passed and root's
full `sshd -T` output was identical before and after.

felixia's ssh config, with the box's address in place of `<box>`:

```sshconfig
Host venari-tunnel
  HostName <box>
  User soft-tunnel
  IdentityFile ~/.ssh/soft-serve-ledger
  IdentitiesOnly yes
  BatchMode yes

Host soft-serve
  HostName 127.0.0.1
  Port 23231
  ProxyJump venari-tunnel
  HostKeyAlias venari-git
  IdentityFile ~/.ssh/soft-serve-ledger
  IdentitiesOnly yes
  BatchMode yes
```

Checked from felixia (2026-09-18). `ls-remote` and push work. These all fail:
a shell ("This account is currently not available"), `-W` to another port
("administratively prohibited"), `-R` ("remote port forwarding failed"),
reading any other repo ("not authorized"), and admin commands ("unauthorized").

## Ghost: disposable Postgres for agents

[Ghost](https://ghost.build) was Timescale's hosted "database for agents":
create a Postgres database per task, fork it, throw it away. The service is
winding down, so `/srv/ghost/` runs our own. The CLI is unchanged apart from
learning one field; the server is `ghost-server` from the `ghost-server`
branch of the `alycda/ghost` fork (see `internal/server/` there). Everything
about the design is in that package's doc comment; the parts that matter on
this box:

- One TimescaleDB cluster (`ghost-postgres`). Each Ghost database is a Postgres
  database named after its ID; a fork is `CREATE DATABASE ... TEMPLATE`, so it
  copies files and needs no one connected to the source (the server ends those
  sessions first). Pause is `ALLOW_CONNECTIONS false`.
- One role, `tsdbadmin`, because the CLI hardcodes it. `ghost password`
  therefore changes the password for every database.
- TLS is on with a self-signed certificate, because the CLI insists on
  `sslmode=require`. It does not verify the certificate.
- Bookkeeping is in the cluster (`ghost.databases`, `ghost.settings` in the
  `postgres` database), so `data/` is the whole state.

Both containers listen on the box's loopback. From the laptop:

```sh
just ghost-tunnel                       # ssh -fN venari-ghost: 8787 -> API, 15432 -> Postgres
ghost create scratch && ghost psql scratch
ghost fork scratch experiment
ghost delete experiment --confirm
just ghost-tunnel-close
```

The `ghost` on PATH is a wrapper (`home-manager/modules/tools/ghost.nix`) that
points the CLI at `127.0.0.1:8787`, turns off analytics, the update check and
the Timescale docs proxy, and exports the API key from agenix. Connection
strings it prints say `127.0.0.1:15432`, which is the tunnel's Postgres end.

Deploying a new server binary: `just ghost-deploy` cross-compiles
`cmd/ghost-server` from `~/Projects/ghost` for linux/amd64, copies it to
`/srv/ghost/server/`, rebuilds the tiny image and restarts the container.
Nothing else needs a Go toolchain: the box has none.

Setup from scratch, as root on the box, after copying `ghost/` here to
`/srv/ghost/`:

```sh
cd /srv/ghost && umask 077
printf 'POSTGRES_PASSWORD=%s\nGHOST_API_KEY=gt_%s\n' "$(openssl rand -hex 24)" "$(openssl rand -hex 20)" > .env
openssl req -new -x509 -days 3650 -nodes -subj /CN=venari-ghost -keyout certs/server.key -out certs/server.crt
chown 70:70 certs/server.*; chmod 600 certs/server.key; chmod 644 certs/server.crt   # uid 70 = the image's postgres
docker compose up -d                    # after `just ghost-deploy` has delivered server/ghost-server
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8787/v0/health
```

Then encrypt the box's `GHOST_API_KEY` into `secrets/personal/ghost-api-key.age`
(`just edit-secret`), so the wrapper can find it.

Not supported, and answered with 501: billing, spaces beyond the one, members,
invites, shares, API-key management (the key is configuration). `ghost logs`
returns an empty page. Backups: the cluster rides the provider's box backups,
like Soft Serve's `data/`; Ghost databases are disposable by design.

## Updates and reboots

`unattended-upgrades` installs security updates daily (Debian's default; the
run is around 06:30 UTC). `52unattended-reboot` lets it reboot when an update
needs one, at 11:00 UTC (04:00 Pacific). Every container on the box uses
`restart: unless-stopped` and docker starts at boot, so services come back by
themselves.

That reboot is also what makes `cloud/99-hostname.cfg` necessary. cloud-init
runs `set_hostname` and `update_hostname` on every boot, and the provider's own
`90-hetznercloud.cfg` sets `preserve_hostname: false` — so a plain
`hostnamectl set-hostname` would have been quietly undone at the next reboot,
days after anyone connected the two. Drop-ins merge in lexical order, so the
`99-` file wins.

Backups of files under `/etc` go in `/root/config-backups/`, not beside the
original: a `*.bak-<ts>` left in `/etc/apt/apt.conf.d/` makes apt print
`Ignoring file … invalid filename extension` on every single run.

## Not covered yet

- Backups. `data/` (repos plus db) should be backed up as a unit, and the
  planned home for that is restic to R2. `ledger-age` is itself a backup
  (ciphertext, with the plaintext still on felixia), so losing it is
  recoverable. The Moment repos are not.
