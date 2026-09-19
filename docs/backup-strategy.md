# Backup strategy

Two tiers, two tools, because "get files off this machine but keep them
browsable" and "offsite backup" have opposite access patterns, and one
product serving both is what made S3 with Glacier lifecycle rules
unworkable: a deduplicating backup tool needs random reads into its pack
files at backup, prune and restore time, and an archive tier that answers
in hours with per-request fees breaks that model rather than tuning it.

## Backup tier: restic

restic holds the backups and nothing else does. Client-side encryption,
content-addressed dedup across every machine into one repository, per-host
snapshots and retention, file-level random-access restore.

- **Repository:** rsync.net over SFTP, or Cloudflare R2 over S3. The choice
  is one line in `secrets/personal/restic-env.age`, not in any module, and
  `restic copy` moves snapshots between the two, so either can become the
  second site later without a tool change.
- **Why rsync.net for the primary:** server-side ZFS snapshots the client
  cannot delete. That is the one property a backup needs that no bucket gives
  cheaply: protection from your own `rm -rf`, a bad prune, or a leaked
  credential. No egress fees, no retrieval tiers. With restic the backend sees
  ciphertext and sizes only, so rsync.net's advantage over Cloudflare is
  immutability and billing shape, not confidentiality.
- **Why restic over borg:** borg is SSH-only and single-writer; restic runs
  the same against SFTP and S3, which keeps the rsync.net-vs-R2 decision
  reversible.
- **What runs:** `tools/restic/backup.sh` with `tools/restic/excludes.txt`.
  home-manager wraps it as `restic-backup` and schedules it through launchd
  (`home-manager/modules/tools/restic.nix`); the accounts without Nix run
  the same script as `mise run backup`. One script, one exclude list, every
  machine.
- **Retention:** 7 daily, 4 weekly, 12 monthly, 3 yearly, per host.

## Offload tier: rclone to R2 (not built yet)

The "virtual file system": cold directories moved off the laptop but still
browsable. rclone speaks S3, so it reuses the R2 token already in
`secrets/personal/r2-*.age`; a `crypt` remote over anything sensitive;
`rclone nfsmount` for a Finder-visible mount without macFUSE.

iCloud, Google Drive and Proton Drive stay what they are: app sync. A sync
store propagates deletes, and rclone's iCloud and Proton backends are
reverse-engineered and rate-limited. Nothing here depends on them.

## The cleanup order

Offload-then-delete produces one copy. So, per directory:

1. `restic-backup` (snapshot the machine as it is)
2. `rclone move <dir> r2:cold/<dir>`
3. delete locally

The offloaded data now exists in the restic repository and on R2 before the
local copy goes. Never delete before a snapshot has been verified with
`restic-backup check --read-data-subset=1/20`.

## Setup checklist

1. Account and SSH key on rsync.net (or an R2 bucket + token).
2. `just edit-secret personal/restic-env.age`: real `RESTIC_REPOSITORY`,
   generated `RESTIC_PASSWORD`. Put the password in Proton Pass; it is the
   only key to every snapshot.
3. Switch; `restic-backup init`; `restic-backup` by hand once.
4. macOS: grant Full Disk Access to the restic binary, or `~/Library/Mail`
   and friends are silently absent (exit 3 in the log). Again after each
   restic bump, since the grant is on the store path.
5. felixia: `mise run decrypt personal/restic-env.age ~/.config/restic/env`,
   then `mise run backup`. Its restic pin is 0.17.3, the newest that runs on
   10.15 (run there 2026-09-18); see `tools/mise/felixia/config.toml`.

## Later

- A NAS becomes a local first tier (Time Machine, or a restic REST server)
  and changes nothing offsite.
- Retire the AWS bucket once the first `restic-backup check` passes against
  the new repository.
