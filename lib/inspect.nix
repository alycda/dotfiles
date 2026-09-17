# inspect (Ataraxy Labs) - entity-level review triage; see the
# entity-level-git agent skill. Upstream's release binary, repointed at
# nixpkgs' openssl.
#
# Why not the obvious routes:
#
# - Not nixpkgs: it does not package inspect (checked against the locked
#   input, 2026-09-16). Its siblings differ - weave IS in nixpkgs, and
#   `nixpkgs#sem` is an unrelated Semaphore CI tool.
#
# - Not the ataraxy-labs/tap Homebrew formula, which cannot install. It pins
#   sha256 3ada87b2... for the v0.1.1 source tarball, committed 2026-04-02
#   15:52Z; upstream then moved the v0.1.1 tag to a later commit at 18:09Z
#   ("Fix release: vendor OpenSSL...") and never refreshed the formula, so
#   the tarball now hashes to 536b218d... and brew's checksum fails. A brew
#   that cannot install makes `brew bundle` exit non-zero inside activation -
#   the failure mode written up in
#   docs/solutions/build-errors/third-party-tap-formula-aborts-darwin-rebuild.md.
#   The formula also build-depends on Homebrew's own rust, against the
#   rustup-only rule.
#
# - Not a source build: the workspace pulls sem-core (and its tree-sitter
#   grammars) from a git rev, which means cargoLock.outputHashes upkeep, and
#   nothing is cached upstream, so every machine would compile it all. Not
#   attempted or timed - rejected on shape. Same call lib/tart.nix made:
#   plain fetchurl of the release asset.
#
# The install_name_tool step is load-bearing, not cosmetic. The macOS asset
# links libssl/libcrypto by absolute path into /opt/homebrew/opt/openssl@3
# (`otool -L`), so unmodified it runs only on a Mac that happens to have
# Homebrew's openssl@3 - it passes its hash and then dies in dyld anywhere
# else, which is exactly the "green build proves nothing" trap from the
# write-up above. Editing the load commands invalidates the code signature,
# and arm64 macOS kills unsigned binaries, hence the re-sign hook.
#
# Darwin/aarch64 only. Upstream ships linux assets too, but a generic-linux
# binary needs autoPatchelf treatment nobody here needs yet; the skill
# degrades to reading the diff where inspect is absent.
#
# No inspect-mcp: upstream publishes no release asset for it (only the brew
# source build produced one). The skill documents the CLI.
#
# Bumping: tags here have moved after release once already, so if fetchurl
# ever reports a hash mismatch, that is upstream re-uploading, not corruption.
# It fails at build time, before activation touches anything - the right
# place for it. Re-check `otool -L` on the new asset before trusting it.
pkgs:
pkgs.stdenv.mkDerivation {
  pname = "inspect";
  version = "0.1.1";

  src = pkgs.fetchurl {
    url = "https://github.com/Ataraxy-Labs/inspect/releases/download/v0.1.1/inspect-macos-aarch64";
    hash = "sha256-5/7Vcir24U3GaCed14VBCfl3hITUixpC6tXSxxuLuQ0=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ pkgs.darwin.autoSignDarwinBinariesHook ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/inspect
    for lib in libssl.3.dylib libcrypto.3.dylib; do
      install_name_tool -change \
        /opt/homebrew/opt/openssl@3/lib/$lib \
        ${pkgs.lib.getLib pkgs.openssl}/lib/$lib \
        $out/bin/inspect
    done
    runHook postInstall
  '';

  meta = {
    description = "Entity-level code review triage for Git (Ataraxy Labs)";
    homepage = "https://github.com/Ataraxy-Labs/inspect";
    license = [
      pkgs.lib.licenses.mit
      pkgs.lib.licenses.asl20
    ];
    platforms = [ "aarch64-darwin" ];
    mainProgram = "inspect";
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
  };
}
