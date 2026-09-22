# weave (Ataraxy Labs) - entity-level semantic merge driver; see the
# entity-level-git agent skill. nixpkgs' derivation, pinned forward onto a
# fork branch.
#
# Two pins in one, and they have different lifetimes. Read both before
# touching this file.
#
# PIN 1 (the version, longer-lived): nixpkgs packages weave, which is why home.nix takes it
# from there rather than the ataraxy-labs tap (see lib/inspect.nix for that
# tap's failure mode). But nixpkgs tracks 0.3.6, tagged 2026-06-05, while
# upstream shipped 0.5.4 on 2026-09-01 - two minor versions and ~3 months
# behind. Verified against `pkgs/by-name/we/weave/package.nix` on nixpkgs
# master, 2026-09-21, not just our locked input: this is nixpkgs being
# behind, not a stale flake input, so `nix flake update` does not fix it.
#
# Why override rather than vendor the whole derivation: nixpkgs' build is
# correct - the three bins (weave, weave-driver, weave-mcp), pkg-config +
# openssl, and a versionCheckHook that runs `weave --version` and so
# catches a bad pin at build time rather than at first use. Only the
# version and source are wrong. Same call lib/tart.nix made.
#
# Why cargoDeps is rebuilt explicitly: buildRustPackage turns `cargoHash`
# into a fixed-output `cargoDeps` derivation at *eval* time, so it is not
# reachable through overrideAttrs' attribute set. Overriding `src` alone
# would leave 0.3.6's vendored lockfile bolted onto 0.5.4's tree, which
# fails opaquely inside the cargo build. fetchCargoVendor against the new
# src is the supported way to re-vendor.
#
# Bumping: change `version`, set both hashes to lib.fakeHash, build, and
# take the two hashes nix reports. Upstream has moved a release tag after
# publishing before (see lib/inspect.nix), so a hash mismatch here is more
# likely a re-upload than corruption - it fails at build time, before
# activation touches anything.
#
# Drop this file entirely, and restore plain `weave` in home.nix and
# work.nix, once nixpkgs' nix-update-script catches up past 0.5.4.
#
# Note for the entity-level-git skill: its weave command list was verified
# against 0.3.6. 0.5.x is a two-minor jump, and this project has renamed
# CLI surface across versions before (older READMEs call the CLI
# `weave-cli` and document a `setup --global` that no longer exists), so
# re-verify `weave --help` against the skill after this lands.
#
# PIN 2 (the fork, shorter-lived): src is alycda/weave's ARB branch, not the
# upstream v0.5.4 tag. Upstream does not route `.arb` - Flutter localization
# bundles, which are JSON under another extension - to the JSON plugin, so
# they line-merge. Measured on the stock 0.5.4 build with byte-identical
# content in both files:
#
#     app_en.json — auto-resolved   unchanged: 1, added-ours: 1, added-theirs: 1
#     app_en.arb  — CONFLICTS: 1 (line-level fallback)
#
# A localization bundle is precisely the file two parallel agents both append
# a message to, so that fallback costs a conflict on a routine merge.
# alycda/weave#1 aliases `.arb` onto the JSON plugin and routes every registry
# construction in the workspace through `weave_core::create_registry()`, so
# `weave setup` cannot claim an extension the driver then disowns.
#
# Pinned to the commit rather than the branch name deliberately: a branch ref
# moves, and the next amend to that PR would leave this hash describing a tree
# that no longer exists at that ref. Bump `rev` and both hashes together.
#
# Revert to the upstream tag - `owner = "ataraxy-labs"`, `tag = "v${version}"`
# - once the ARB change lands in Ataraxy-Labs/weave. `version` stays "0.5.4"
# because that is what the fork's crates still declare and what
# versionCheckHook greps `weave --version` for; the fork is 0.5.4 plus that
# one patch, not a new release.
pkgs:
let
  version = "0.5.4";
  # alycda/weave#1 @ claude/gallant-archimedes-jtwpt4
  rev = "6443c7b4202f1da5013507a37058f6db91e50ff6";
  src = pkgs.fetchFromGitHub {
    owner = "alycda";
    repo = "weave";
    inherit rev;
    hash = "sha256-Zukg5KMwhYuDUXtTSxQfWPNa7qGlMge6Hlqt/MOKWDM=";
  };
in
pkgs.weave.overrideAttrs (old: {
  inherit version src;
  cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
    inherit src;
    hash = "sha256-vRaSmAxbJlEoa2R5lN9X2mQZbzd13Icq4NBROx7FjsE=";
  };
  # 0.5.x added crates/weave-driver/tests/public_properties.rs, which shells
  # out to `git` to build a conflicted merge and then abort it. The nix build
  # sandbox has no git on PATH, so it panics with ENOENT on the first
  # Command::new("git") - a missing test dependency, not a weave bug.
  # nixpkgs' 0.3.6 derivation predates that test and so never needed this.
  # Upstream nixpkgs will need the same line when it bumps past 0.4.
  nativeCheckInputs = (old.nativeCheckInputs or [ ]) ++ [ pkgs.git ];
})
