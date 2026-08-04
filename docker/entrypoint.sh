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

  # The nixos/nix base image seeds root's profile with packages that collide
  # with home-manager's own when the generation is assembled, blocking
  # activation: git-minimal vs full git (share/git-core/.../info/exclude), and
  # on newer/arm64 base images man-db vs home-manager's man (bin/accessdb).
  # We fetch the flake via `path:` (no git needed) and HM provides man, so
  # drop the base copies first; the rest of the base profile (openssh, curl,
  # ...) is preserved and merges fine.
  #
  # bash is deliberately NOT in this list even though it collides too. It is
  # root's login shell in /etc/passwd and what /bin/sh resolves through, so
  # removing it here would be pulling the rug out from under this very script.
  # That collision is declined on the home-manager side instead
  # (`programs.bash.package = null` in home-manager/profiles/dev.nix). Rule of
  # thumb: strip here only when home-manager's version is genuinely required.
  for pkg in git-minimal man-db; do
    nix-env -e "$pkg" 2>/dev/null || true
  done

  export HOME_MANAGER_BACKUP_EXT=backup
  if ! /opt/hm-activation/activate; then
    echo ">> activation failed."
    echo ">> if the error mentions age/agenix, the ragenix identity is missing:"
    echo ">>   docker cp ~/.age/personal-key.txt <container>:/root/.age/personal-key.txt"
    echo ">> then exit and start the container again."
  fi
fi

exec "$@"
