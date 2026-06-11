#!/bin/sh
# Activate the baked home-manager generation when the home profile is absent
# (first start, or a fresh/reset devhome volume) or when the image carries a
# newer generation than the one the volume was activated with.

CURRENT=$(readlink -f /root/.local/state/nix/profiles/home-manager 2>/dev/null)
BAKED=$(readlink -f /opt/hm-activation)

if [ ! -e /root/.nix-profile ] || [ "$CURRENT" != "$BAKED" ]; then
  echo ">> activating home-manager generation (alyssa@dev-x86)"

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
