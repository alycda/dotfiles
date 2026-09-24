# lazydiff (Ataraxy-Labs) - terminal UI for reviewing git diffs, built around
# annotating agent-authored changes.
{ lib, pkgs, ... }:

let
  # Note: `lazydiff --version` reports 0.1.0-alpha.16 from this tag - upstream
  # didn't bump the internal string for the alpha.17 release. The pin is right;
  # don't "fix" it by chasing the number the binary prints.
  version = "0.1.0-alpha.17";

  # Prebuilt release assets keyed by nix system. Linux uses the static musl
  # builds, so the binary carries no interpreter or RPATH for nix to fix up.
  #
  # Upstream's install script is deliberately NOT used. Its platform case block
  # only knows linux-x86_64, macos-arm64 and windows-x86_64, so on aarch64
  # Linux it falls through to `error "unsupported OS/Arch: linux/arm64"; exit 1`
  # - even though this very release publishes lazydiff-linux-aarch64.tar.gz and
  # a musl variant. The installer is simply stale relative to its own assets.
  # Fetching them directly both dodges that and makes the install reproducible
  # and offline-cacheable, which piping a script into sh never was.
  assets = {
    x86_64-linux = {
      file = "lazydiff-linux-x86_64-musl";
      sha256 = "7d026d9b1c5dfd9fd1a3a63bc68691a9638c40165a518d4cf2beb6bb3eb2b606";
    };
    aarch64-linux = {
      file = "lazydiff-linux-aarch64-musl";
      sha256 = "d2c2835ba3d97c03f7d2b931c7af1f05ba3f428a458e90e054d35eee2f3ec48a";
    };
    aarch64-darwin = {
      file = "lazydiff-macos-arm64";
      sha256 = "27796f484bf2c6051c08eaea5185d67d0db0dc13278f1a15af3ed7087d98125b";
    };
    x86_64-darwin = {
      file = "lazydiff-macos-x86_64";
      sha256 = "26e4b629575be59099c6df4df3aa4786c5d50f597786b9667f5af89e60e51a1f";
    };
  };

  inherit (pkgs.stdenv.hostPlatform) system;

  asset =
    assets.${system}
      or (throw "lazydiff: upstream publishes no prebuilt binary for ${system}");

  lazydiff = pkgs.stdenvNoCC.mkDerivation {
    pname = "lazydiff";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/Ataraxy-Labs/lazydiff/releases/download/v${version}/${asset.file}.tar.gz";
      inherit (asset) sha256;
    };

    # The tarball is a bare `lazydiff` binary with no wrapping directory, so
    # the default sourceRoot detection has nothing to descend into.
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      install -Dm755 lazydiff "$out/bin/lazydiff"
      runHook postInstall
    '';

    # The Linux builds are statically linked; leave them exactly as shipped
    # rather than letting fixup try to shrink an RPATH that isn't there.
    dontPatchELF = true;
    dontStrip = true;

    meta = {
      description = "Terminal UI for reviewing git diffs, with annotations for agents";
      homepage = "https://github.com/Ataraxy-Labs/lazydiff";
      license = lib.licenses.mit;
      mainProgram = "lazydiff";
      platforms = lib.attrNames assets;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };
in
{
  home.packages = [ lazydiff ];
}
