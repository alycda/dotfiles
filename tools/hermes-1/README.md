# hermes-1 — the always-on box

A small Hetzner Cloud VM (CX23, Helsinki, Debian 12), rented as a trial home
for Hermes and kept on 2026-09-18, mainly as a private git server. Nothing
deploys this directory: each file says where it lives on the box, and the box
is the running copy.

| Here | On the box |
|---|---|
| `soft-serve/docker-compose.yml` | `/srv/soft-serve/docker-compose.yml`, with `.env` (from `.env.example`) and `data/` beside it |
| `apt/52unattended-reboot` | `/etc/apt/apt.conf.d/52unattended-reboot` |
| `ssh/20-soft-tunnel.conf` | `/etc/ssh/sshd_config.d/20-soft-tunnel.conf` |
| `ssh/soft-tunnel.authorized_keys` | `/var/lib/soft-tunnel/.ssh/authorized_keys` (root-owned, 644) |

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
ssh hermes-git user create felixia
ssh hermes-git user add-pubkey felixia "'ssh-ed25519 AAAA...'"   # the quotes survive ssh's re-split
ssh hermes-git repo create ledger-age -p
ssh hermes-git repo collab add ledger-age felixia read-write
```

The risk with a `Match` block in an included file is that it stays open and
captures the directives that follow the `Include` in the main config, changing
them for everyone. Not measured in general; here, `sshd -t` passed and root's
full `sshd -T` output was identical before and after.

felixia's ssh config, with the box's address in place of `<box>`:

```sshconfig
Host hermes-tunnel
  HostName <box>
  User soft-tunnel
  IdentityFile ~/.ssh/soft-serve-ledger
  IdentitiesOnly yes
  BatchMode yes

Host soft-serve
  HostName 127.0.0.1
  Port 23231
  ProxyJump hermes-tunnel
  HostKeyAlias hermes-git
  IdentityFile ~/.ssh/soft-serve-ledger
  IdentitiesOnly yes
  BatchMode yes
```

Checked from felixia (2026-09-18). `ls-remote` and push work. These all fail:
a shell ("This account is currently not available"), `-W` to another port
("administratively prohibited"), `-R` ("remote port forwarding failed"),
reading any other repo ("not authorized"), and admin commands ("unauthorized").

## Updates and reboots

`unattended-upgrades` installs security updates daily (Debian's default; the
run is around 06:30 UTC). `52unattended-reboot` lets it reboot when an update
needs one, at 11:00 UTC (04:00 Pacific). Every container on the box uses
`restart: unless-stopped` and docker starts at boot, so services come back by
themselves.

## Not covered yet

- Backups. `data/` (repos plus db) should be backed up as a unit, and the
  planned home for that is restic to R2. `ledger-age` is itself a backup
  (ciphertext, with the plaintext still on felixia), so losing it is
  recoverable. The Moment repos are not.
