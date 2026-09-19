#!/usr/bin/env bash
# One restic backup of $HOME, then apply the retention policy. Shared as a
# plain file: home-manager wraps it as `restic-backup` (with the env file and
# excludes paths filled in from the store), the mise accounts run it from
# ~/dotfiles as `mise run backup`. Same script both ways, so a machine that
# cannot run a switch still backs up the same paths under the same policy.
#
#   backup.sh              back up $HOME, then forget+prune
#   backup.sh <restic...>  run any restic command against the same repo,
#                          e.g. `backup.sh snapshots`, `backup.sh init`
#
# Inputs, all optional:
#   RESTIC_ENV_FILE   sourced first; sets RESTIC_REPOSITORY and RESTIC_PASSWORD
#                     (default ~/.config/restic/env; home-manager points this
#                     at the agenix copy of secrets/personal/restic-env.age)
#   RESTIC_EXCLUDES   the exclude file (default ~/dotfiles/tools/restic/excludes.txt)
#
# Exit codes follow restic's: 0 clean, 3 when some files could not be read
# (macOS TCC denies a non-Full-Disk-Access process ~/Library/Mail and friends;
# the snapshot is still complete for everything else, so retention still runs
# and the exit is 3 so the log shows it).
set -euo pipefail

env_file="${RESTIC_ENV_FILE:-$HOME/.config/restic/env}"
excludes="${RESTIC_EXCLUDES:-$HOME/dotfiles/tools/restic/excludes.txt}"

if [ ! -r "$env_file" ]; then
  echo "restic-backup: no env file at $env_file" >&2
  echo "  home-manager: just edit-secret personal/restic-env.age, then switch" >&2
  echo "  mise (felixia): mise run decrypt personal/restic-env.age $HOME/.config/restic/env" >&2
  exit 78 # EX_CONFIG
fi
set -a
# shellcheck disable=SC1090,SC1091
. "$env_file"
set +a

if [ "${RESTIC_PASSWORD:-PLACEHOLDER}" = PLACEHOLDER ] || [ -z "${RESTIC_REPOSITORY:-}" ]; then
  # The committed secret is a placeholder so the module evaluates before the
  # repository exists. Refusing here is what keeps `init` from creating a
  # repository keyed to the word PLACEHOLDER.
  echo "restic-backup: $env_file still holds the placeholder; set RESTIC_REPOSITORY and RESTIC_PASSWORD" >&2
  exit 78
fi

if [ $# -gt 0 ]; then
  exec restic "$@"
fi

# uname rather than hostname: nixpkgs coreutils has uname and not hostname,
# and the wrapper runs with only that on PATH under launchd.
host="$(uname -n)"
host="${host%%.*}"
rc=0
restic backup \
  --host "$host" \
  --one-file-system \
  --exclude-caches \
  --exclude-file "$excludes" \
  "$HOME" || rc=$?
case $rc in
  0) ;;
  3) echo "restic-backup: snapshot done, some files unreadable (rc 3); see warnings above" >&2 ;;
  *) exit "$rc" ;;
esac

# Retention. Grouped by host and path set, so each machine's snapshots are
# kept and thinned on their own: a year of monthlies, three of yearlies. The
# repository is shared across machines only for deduplication.
restic forget --prune \
  --host "$host" \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12 \
  --keep-yearly 3
exit "$rc"
