#!/bin/sh
# Activate the baked home-manager generation when the home profile is absent
# (first start, or a fresh/reset devhome volume) or when the image carries a
# newer generation than the one the volume was activated with.

CURRENT=$(readlink -f /root/.local/state/nix/profiles/home-manager 2>/dev/null)
BAKED=$(readlink -f /opt/hm-activation)

# Keep Claude's user-level memory current. /root/.claude is its own volume
# (claude-home) so auth/.credentials.json survives devhome resets - but that
# volume shadows the CLAUDE.md baked into the image, so refresh it from the
# flake source on every start. Only touches CLAUDE.md, never the credentials.
# The doc is per-architecture: the x86 one describes the frozen 2012 MBP, the
# arm64 one a modern Apple Silicon host.
case "$(uname -m)" in
  aarch64) claude_md=CLAUDE-arm64.md ;;
  *)       claude_md=CLAUDE.md ;;
esac
mkdir -p /root/.claude
cp -f "/opt/dotfiles/docker/$claude_md" /root/.claude/CLAUDE.md 2>/dev/null || true

if [ ! -e /root/.nix-profile ] || [ "$CURRENT" != "$BAKED" ]; then
  echo ">> activating home-manager generation ($(cat /opt/hm-profile 2>/dev/null || echo unknown))"

  # The nixos/nix base image seeds root's profile with git-minimal (so nix can
  # fetch git flakes). home-manager installs its own full git into that same
  # profile, and the two collide on share/git-core/templates/info/exclude when
  # the generation is assembled - blocking activation. We fetch the flake via
  # `path:` (no git needed), so drop the base git-minimal first; the rest of
  # the base profile (bash, openssh, curl, ...) is preserved and merges fine.
  nix-env -e git-minimal 2>/dev/null || true

  export HOME_MANAGER_BACKUP_EXT=backup
  if ! /opt/hm-activation/activate; then
    echo ">> activation failed."
    echo ">> if the error mentions age/agenix, the ragenix identity is missing:"
    echo ">>   docker cp ~/.age/personal-key.txt <container>:/root/.age/personal-key.txt"
    echo ">> then exit and start the container again."
  fi
fi

exec "$@"
