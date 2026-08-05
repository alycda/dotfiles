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
  supabase-cli
  taskbook
  tmux
  vhs # charmbracelet
]
