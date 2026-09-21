#!/bin/bash
# offsite-ledger.sh - the ledger's offsite copy, encrypted.
#
# ~/ledger is complete financial records, and its pre-push hook refuses any
# plaintext push off this disk ("encrypt it first"). This is the encrypted
# copy that rule asks for:
#   1. bundle the ledger's history (git bundle --branches --tags)
#   2. encrypt it to the `alyssa` age recipient: public key only, so this
#      machine needs no secret to write a backup; reading one needs
#      ~/.age/personal-key.txt
#   3. commit the ciphertext as ledger.bundle.age and push it to the private
#      Soft Serve repo ledger-age on the Hetzner box (ssh alias soft-serve)
# Only ciphertext leaves this machine. Each push is a new commit, so earlier
# bundles stay retrievable. A run is skipped when the ledger's branches and
# tags have not moved since the last push. Uncommitted files are not in any
# bundle, as they were not in the old ~/git/ledger.git either.
#
# ingest.sh and approve.sh call this after each commit; safe to run by hand.
# Restore, on any machine that holds the key:
#   git clone ssh://hermes-git/ledger-age && cd ledger-age
#   rage -d -i ~/.age/personal-key.txt -o /tmp/ledger.bundle ledger.bundle.age
#   git clone /tmp/ledger.bundle ledger
set -euo pipefail
umask 077

LEDGER="$HOME/ledger"
STATE="$HOME/.local/state/ledger-offsite"
REMOTE="ssh://soft-serve/ledger-age"
RECIPIENT="age1mxz3lqtpxg35s2cct2gex76l66wrw9xpv5v8tk340gqxsdzxh5msq8vp09" # alyssa, dotfiles secrets/secrets.nix
GIT=/usr/bin/git

# rage is moving from ~/.cargo/bin to mise; use whichever copy is here.
RAGE=""
for c in "$(command -v rage 2>/dev/null || true)" "$HOME/.cargo/bin/rage" \
         "$("$HOME/.local/bin/mise" which rage 2>/dev/null || true)"; do
  if [ -n "$c" ] && [ -x "$c" ]; then RAGE="$c"; break; fi
done
[ -n "$RAGE" ] || { echo "offsite-ledger: no rage binary found" >&2; exit 1; }

mkdir -p "$STATE"
if [ ! -d "$STATE/repo/.git" ]; then
  $GIT clone -q "$REMOTE" "$STATE/repo"
  $GIT -C "$STATE/repo" config user.name "felixia offsite-ledger"
  $GIT -C "$STATE/repo" config user.email "offsite-ledger@felixia.local"
fi

sig=$($GIT -C "$LEDGER" for-each-ref --format='%(objectname) %(refname)' refs/heads refs/tags | shasum | cut -c1-40)
if [ "$sig" = "$(cat "$STATE/last" 2>/dev/null || true)" ]; then
  echo "offsite-ledger: branches and tags unchanged since the last push; nothing to do"
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
$GIT -C "$LEDGER" bundle create "$tmp/ledger.bundle" --branches --tags 2>/dev/null
$GIT -C "$LEDGER" bundle verify "$tmp/ledger.bundle" >/dev/null 2>&1 \
  || { echo "offsite-ledger: bundle failed to verify" >&2; exit 1; }
"$RAGE" -r "$RECIPIENT" -o "$STATE/repo/ledger.bundle.age" "$tmp/ledger.bundle"

head=$($GIT -C "$LEDGER" rev-parse --short HEAD)
cd "$STATE/repo"
$GIT checkout -q -B main
$GIT add ledger.bundle.age
$GIT commit -q -m "ledger at $head ($(date '+%Y-%m-%d %H:%M'))"
$GIT push -q origin HEAD:refs/heads/main
echo "$sig" > "$STATE/last"
echo "offsite-ledger: pushed an encrypted bundle of the ledger at $head"
