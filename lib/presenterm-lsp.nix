# presenterm-lsp - the in-tree language server for presenterm decks.
#
# Source lives at tools/presenterm-lsp/ rather than in a separate repo because
# it is small, it is pinned to a specific presenterm version's comment grammar,
# and the thing that keeps it honest (tools/presenterm-lsp/src/command.rs being
# diffable against upstream) only works if the two move together in one commit.
#
# WHY buildRustPackage IS SAFE HERE AND WAS NOT IN PR #19. That PR tried to
# package `envelope` from an external source tree, which needs a `cargoHash`
# over the vendored dependency FOD - obtainable only by building and copying
# the hash out of the mismatch error, which is why it ended up committing a
# lib.fakeHash placeholder that could never build. This crate's Cargo.lock is
# in-tree, so `cargoLock.lockFile` fetches each dependency by the checksum
# already recorded there. Same reasoning as the importNpmLock choice in
# ./../home-manager/modules/tools/hackmd.nix: the lockfile is the pin, and
# there is no second hash to keep in sync.
#
# `cargo test` runs as the derivation's checkPhase, so the ~35 unit tests
# (including the cases copied verbatim from presenterm's own test suite) gate
# every rebuild rather than only CI.
{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "presenterm-lsp";
  version = "0.1.0";

  # A fileset rather than the bare directory: `target/` and the vscode
  # extension's `node_modules/` would otherwise land in the store path and
  # invalidate it on every local `cargo build`.
  src = lib.fileset.toSource {
    root = ../tools/presenterm-lsp;
    fileset = lib.fileset.unions [
      ../tools/presenterm-lsp/Cargo.toml
      ../tools/presenterm-lsp/Cargo.lock
      ../tools/presenterm-lsp/rustfmt.toml
      ../tools/presenterm-lsp/src
      # tests/ must be in the source or the fixture-deck integration tests
      # silently do not exist at build time: cargo does not fail on a missing
      # tests/ directory, it just runs nothing, and checkPhase would go green
      # having verified only the unit tests.
      ../tools/presenterm-lsp/tests
    ];
  };

  cargoLock.lockFile = ../tools/presenterm-lsp/Cargo.lock;

  meta = {
    description = "Language server and checker for presenterm decks";
    longDescription = ''
      Diagnostics, completion, hover and a slide outline for presenterm
      presentations. Also runs headlessly as `presenterm-lsp --check FILE`,
      which presenterm itself has no equivalent of - its only validation flag,
      --validate-overflows, needs a real terminal to measure against.
    '';
    homepage = "https://github.com/alycda/dotfiles";
    license = lib.licenses.bsd2;
    mainProgram = "presenterm-lsp";
  };
}
