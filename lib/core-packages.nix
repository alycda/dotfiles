# Core packages shared across devShells and home-manager profiles
# This ensures consistency between ephemeral shells and persistent environments
pkgs: with pkgs; [
  asciinema
  bat
  codecrafters-cli
  # curl + file: ubiquitous CLI primitives; also the runtime deps the
  # here.now agent-skill's publish.sh shells out to (alongside jq).
  curl
  file
  eza
  ripgrep
  jujutsu
  just
  jq
  gh
  # postgresql
  # Python 3 for agent-plugin tooling: compound-engineering's bundled
  # validators and session-history scripts are stdlib-only python3 and
  # silently degrade to manual checks without an interpreter on PATH.
  python3
  rage
  ragenix
  # GNU sed. The attribute is `gnused`, not `sed` - the latter is undefined and
  # fails evaluation, not just the build. Genuinely missing here rather than
  # assumed present: `coreutils-full` is in the base image's nix-env profile,
  # but sed is its own GNU package, so nothing else supplies it (and nothing
  # else collides with it either).
  gnused
  supabase-cli
  taskbook
  tmux
  vhs # charmbracelet
]
