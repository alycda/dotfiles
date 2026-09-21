# clock-rs ships everywhere via lib/core-packages.nix
[group('personal')]
clock:
    clock-rs --fmt="%A, %Y-%m-%d" -t

# render markdown from cwd or a given file (glow ships via core-packages)
[group('personal')]
md *args:
    glow {{args}}

# encrypt to Alyssa's age public key (stdin->stdout, or pass rage args)
[group('personal')]
encrypt *args:
    rage -e -r age1mxz3lqtpxg35s2cct2gex76l66wrw9xpv5v8tk340gqxsdzxh5msq8vp09 {{args}}

ip:
    curl -s https://ipinfo.io/json

# create a user-defined docker network if it doesn't exist yet (safe to re-run)
[group('personal')]
docker-net name='claude-net':
    @docker network inspect {{name}} >/dev/null 2>&1 || docker network create {{name}}

# Covers the age identity, ssh, keychain, unmanaged tool state, and git bundles
# for local-only history. Reads from the canonical ~/dotfiles checkout, the same
# assumption tools/mise makes.
#
# back up everything the flake cannot rebuild, before a macOS major upgrade
[group('personal')]
macos-backup dest:
    #!/usr/bin/env bash
    set -euo pipefail
    script="$HOME/dotfiles/tools/backup/pre-upgrade-backup.sh"
    if [ ! -x "$script" ]; then
      echo "not found: $script" >&2
      echo "the canonical checkout is ~/dotfiles; run it from your checkout directly" >&2
      exit 1
    fi
    "$script" {{dest}}
