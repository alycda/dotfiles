#!/usr/bin/env bash
# Minimal pre-upgrade backup: the things nix-darwin + home-manager cannot rebuild.
#
# This is NOT a rollback plan. Rolling back to Sequoia needs a full Time Machine
# backup taken before the upgrade, because Migration Assistant refuses to restore
# a Tahoe-era backup onto Sequoia. This script is the *rebuild* plan: enough to
# make a freshly-installed machine yours again after a `darwin-rebuild switch`.
#
# Usage:  ./pre-upgrade-backup.sh /Volumes/<external-disk>
set -euo pipefail

DEST="${1:?usage: $0 <destination-directory>}"
STAMP="$(date +%Y%m%dT%H%M%S)"
OUT="$DEST/macos-pre-upgrade-$STAMP"
mkdir -p "$OUT"/{keys,config,state,repos}

log() { printf '  %s\n' "$*"; }

# Absent is fine and common (not every machine has every tool). A copy that
# FAILS on something present is not fine - this is a backup, so it has to be
# loud rather than logged as a skip. Deliberately not `A && B || C`, which
# reports the failure as an absence.
FAILURES=0
copy() {
  if [ ! -e "$1" ]; then
    log "skip  $1 (absent)"
  elif cp -a "$1" "$2"; then
    log "ok    $1"
  else
    log "FAIL  $1  <- NOT backed up"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "==> tier 0: keys and identity (IRREPLACEABLE)"
copy ~/.age/personal-key.txt          "$OUT/keys/"
copy ~/.ssh                           "$OUT/keys/"
copy ~/Library/Keychains/login.keychain-db "$OUT/keys/"

echo "==> tier 1: credentials and tool config not in the dotfiles repo"
copy ~/.config/gh                     "$OUT/config/"    # gh oauth token
copy ~/.config/jj                     "$OUT/config/"
copy ~/.aws                           "$OUT/config/"
copy ~/.gitconfig                     "$OUT/config/"
copy ~/.gitignore_global              "$OUT/config/"
copy ~/.npmrc                         "$OUT/config/"
copy ~/.yarnrc                        "$OUT/config/"

echo "==> tier 1: unmanaged runtime state (CLAUDE.md: install the binary, leave state alone)"
copy ~/.taskbook.json                 "$OUT/state/"
copy ~/.taskbook                      "$OUT/state/"
copy ~/.hackmd                        "$OUT/state/"
copy ~/.herenow                       "$OUT/state/"
copy ~/.sem                           "$OUT/state/"
copy ~/.logseq                        "$OUT/state/"
copy ~/.workflowy                     "$OUT/state/"
copy ~/.zsh_history                   "$OUT/state/"

# ~/.claude is 201M, nearly all transcripts and plugin caches. Take the parts
# that are authored rather than generated: settings, and the auto-memory the
# global CLAUDE.md maintains per project.
echo "==> tier 1: claude (selective - skipping 147M of transcripts)"
mkdir -p "$OUT/state/claude"
copy ~/.claude.json                   "$OUT/state/claude/"
copy ~/.claude/settings.json          "$OUT/state/claude/"
copy ~/.claude/settings.local.json    "$OUT/state/claude/"
copy ~/.claude/CLAUDE.md              "$OUT/state/claude/"
copy ~/.claude/keybindings.json       "$OUT/state/claude/"
for d in ~/.claude/projects/*/memory; do
  [ -d "$d" ] || continue
  proj="$(basename "$(dirname "$d")")"
  mkdir -p "$OUT/state/claude/memory/$proj"
  cp -a "$d/." "$OUT/state/claude/memory/$proj/"
  log "ok    memory/$proj"
done

echo "==> tier 2: local-only git history"
# Bundles, not tarballs: the working trees are tens of GB of target/ and
# node_modules, the history is megabytes. One bundle per real repository -
# linked worktrees share a common dir and would otherwise bundle N times.
: > "$OUT/repos/MANIFEST.txt"
seen_common=""
for root in ~/dotfiles ~/gh-alycda ~/gitlab ~/glitch ~/nix-dotfiles ~/Projects ~/vc ~/WIP ~/cf ~/Offline; do
  [ -d "$root" ] || continue
  while IFS= read -r g; do
    r="$(dirname "$g")"
    git -C "$r" rev-parse HEAD >/dev/null 2>&1 || continue
    common="$(cd "$r" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || continue
    case "$seen_common" in *"|$common|"*) continue ;; esac
    seen_common="$seen_common|$common|"

    slug="$(printf '%s' "${r#"$HOME"/}" | tr '/ ' '__')"
    # Each capture is wrapped: `set -o pipefail` otherwise turns a git that
    # exits non-zero (stash list in a bare repo) or gets SIGPIPEd by head into
    # an abort of the whole backup. Hit on Projects/RUST/AoC, a .bare + linked
    # worktree layout.
    has_remote="$( { git -C "$r" remote 2>/dev/null || true; } | head -1 || true)"
    dirty="$( { git -C "$r" status --porcelain 2>/dev/null || true; } | head -1 || true)"
    stashes="$( { git -C "$r" stash list 2>/dev/null || true; } | wc -l | tr -d ' ')"

    # No remote means the history exists nowhere else. Bundle everything.
    if [ -z "$has_remote" ]; then
      # A bundle can legitimately fail (no branch refs, only a detached HEAD).
      # Record it and keep going - one odd repo must not abort the backup.
      if git -C "$r" bundle create "$OUT/repos/$slug.bundle" --all >/dev/null 2>&1; then
        echo "BUNDLE   $r" >> "$OUT/repos/MANIFEST.txt"; log "bundle $r"
      else
        echo "FAILED   $r (bundle --all produced nothing)" >> "$OUT/repos/MANIFEST.txt"
        log "FAIL   $r  <- check by hand"
      fi
      continue
    fi
    # Has a remote: history is recoverable, but uncommitted work and stashes
    # are not. Capture those as patches.
    if [ -n "$dirty" ] || [ "$stashes" != "0" ]; then
      mkdir -p "$OUT/repos/$slug"
      git -C "$r" status --porcelain > "$OUT/repos/$slug/status.txt" 2>/dev/null || true
      git -C "$r" diff HEAD          > "$OUT/repos/$slug/uncommitted.patch" 2>/dev/null || true
      git -C "$r" ls-files --others --exclude-standard > "$OUT/repos/$slug/untracked.txt" 2>/dev/null || true
      i=0
      while [ "$i" -lt "$stashes" ]; do
        git -C "$r" stash show -p "stash@{$i}" > "$OUT/repos/$slug/stash-$i.patch" 2>/dev/null || true
        i=$((i + 1))
      done
      # local commits the remote has never seen
      git -C "$r" log --branches --not --remotes --oneline > "$OUT/repos/$slug/unpushed.txt" 2>/dev/null || true
      echo "PATCHES  $r (dirty=${dirty:+Y} stashes=$stashes)" >> "$OUT/repos/MANIFEST.txt"
      log "patch  $r"
    fi
  done < <(find "$root" -maxdepth 3 -name .git 2>/dev/null)
done

echo "==> manifest"
{
  echo "host:    $(scutil --get LocalHostName 2>/dev/null || hostname)"
  echo "os:      $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
  echo "date:    $(date -Iseconds)"
  echo "nix:     $(nix --version 2>/dev/null || echo absent)"
  echo
  echo "restore: clone the dotfiles repo, place keys/personal-key.txt at"
  echo "         ~/.age/personal-key.txt and keys/.ssh at ~/.ssh (chmod 700,"
  echo "         600 on the private keys), THEN darwin-rebuild switch."
} > "$OUT/MANIFEST.txt"

du -sh "$OUT"
echo
echo "Wrote $OUT"
if [ "$FAILURES" -ne 0 ]; then
  echo "WARNING: $FAILURES item(s) failed to copy - scroll up for FAIL lines." >&2
fi
cat <<'NEXT'

Next, and the order matters:

  1. Lift the age identity OUT of the archive first. If the only copy of
     personal-key.txt is inside an archive encrypted TO that key, nothing can
     open it. Put the plaintext somewhere you physically control.

       cp "$OUT/keys/personal-key.txt" <somewhere-safe>/AGE-IDENTITY-KEEP-SAFE.txt

  2. Encrypt the rest (it contains SSH private keys and a keychain):

       tar -czf - -C "$(dirname "$OUT")" "$(basename "$OUT")" \
         | rage -e -r age1mxz3lqtpxg35s2cct2gex76l66wrw9xpv5v8tk340gqxsdzxh5msq8vp09 \
         > <dest>/pre-upgrade.tar.gz.age

  3. Verify it round-trips BEFORE removing the plaintext:

       rage -d -i ~/.age/personal-key.txt <dest>/pre-upgrade.tar.gz.age \
         | tar -tzf - | head

This is a REBUILD plan, not a rollback. Rolling back to an older macOS needs a
full Time Machine backup taken before the upgrade: Migration Assistant will not
restore a newer-OS backup onto an older OS.
NEXT
