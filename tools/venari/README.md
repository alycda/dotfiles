# venari — the always-on box

A small rented VM running Debian 12. It was stood up on 2026-09-16 as a
trial home for Hermes, and kept on 2026-09-18.
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

An unknown key sees no repos and cannot clone, including non-private ones;
`docker-compose.yml` has the settings that make that true.

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
- **`20-soft-tunnel.conf`** — sshd's copy of the same restriction, and the only
  layer that stops `-R`; the file says why.
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

## Updates and reboots

`unattended-upgrades` runs daily and may reboot the box at 11:00 UTC — see
`apt/52unattended-reboot`. Every container uses `restart: unless-stopped` and
docker starts at boot, so services come back by themselves.

That reboot is why `cloud/99-hostname.cfg` exists: cloud-init would otherwise
revert the hostname at the next one, days after anyone connected the two. The
file says how.

Backups of files under `/etc` go in `/root/config-backups/`, not beside the
original: a `*.bak-<ts>` left in `/etc/apt/apt.conf.d/` makes apt print
`Ignoring file … invalid filename extension` on every single run.

## Not covered yet

- Backups. `data/` (repos plus db) should be backed up as a unit, and the
  planned home for that is restic to R2. `ledger-age` is itself a backup
  (ciphertext, with the plaintext still on felixia), so losing it is
  recoverable. The Moment repos are not.
