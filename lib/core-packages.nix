# Core packages shared across devShells and home-manager profiles
# This ensures consistency between ephemeral shells and persistent environments
pkgs: with pkgs; [
  asciinema
  gawk
  bat
  clock-rs # `just -g clock` runs on every machine class, not just the ditto mac
  codecrafters-cli
  # charmbracelet's terminal agent CLI, from Charm's own Nix repo rather than
  # nixpkgs: nixpkgs' copy is hand-bumped and sat three releases behind with
  # no open PR, so `nix flake update` could not reach a newer one. The whole
  # argument, and why this is scoped instead of overlaid at top level, is in
  # lib/charm-nur.nix. Still UNFREE (FSL-1.1-MIT): needs allowUnfree wherever
  # this list is evaluated (mkHome and darwin already set it; flake.nix
  # devShells sets it for this). No longer built from source, though - Charm
  # ships release binaries, which is what cache.nixos.org could never do for
  # an unfree package.
  charm-nur.crush
  # curl + file: ubiquitous CLI primitives; also the runtime deps the
  # here.now agent-skill's publish.sh shells out to (alongside jq).
  curl
  file
  glow # https://github.com/charmbracelet/glow
  eza
  ripgrep
  jujutsu
  just
  jq
  gh
  nodejs
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
  # charmbracelet's local key-value store — the macOS analogue to the iOS
  # Cheatsheet app. Deliberately a third thing next to the two stores that
  # already exist here: `cheat` and the global justfile hold *runnable*
  # command memory, agenix/NordPass hold *secrets*, and skate holds the short
  # dumb strings that are neither — an age recipient key, which flake target a
  # machine class wants, the SSH line for a box touched twice a year. Namespace
  # them (`skate set <key> @personal`) to mirror the home-manager profile split.
  #
  # From nixpkgs rather than pkgs.charm-nur: the NUR exists here for packages
  # nixpkgs lags on, which is the whole argument in lib/charm-nur.nix for
  # crush. skate is not one — upstream's latest is v1.0.1 (2025-03-06) and
  # nixpkgs and the NUR both carry exactly 1.0.1. Same call as glow and vhs.
  #
  # Two caveats worth knowing before trusting it with anything: nixpkgs still
  # describes it as a "multi-machine syncable" store, which stopped being true
  # when Charm Cloud sunset — it is local-only now, so no phone<->laptop sync.
  # And it is plaintext BadgerDB on disk: not a vault, same caveat as
  # Cheatsheet itself. Secrets stay in agenix.
  skate
  supabase-cli
  taskbook
  tmux
  vhs # charmbracelet
]
