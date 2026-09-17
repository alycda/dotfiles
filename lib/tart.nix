# tart, pinned to the newest release that runs on macOS 15.
#
# Two separate constraints meet here.
#
# It comes from nixpkgs rather than the `cirruslabs/cli` Homebrew tap because
# that tap's GoReleaser-generated `tart.rb` declares `depends_on :macos` twice
# (once bare, once as `macos: :ventura`). Homebrew 6.0 *disabled* that
# combination, so `brew bundle` aborts while loading the formula and takes the
# entire `darwin-rebuild switch` with it. It is not a stale checkout - the tap's
# origin/main carries the same file, and issues #14-#19 there have been open or
# closed-unmerged since. A third-party tap that can hard-fail activation does not
# belong on the critical path when nixpkgs packages the same release tarball.
#
# The version is pinned because nixpkgs tracks tart HEAD, and tart 2.35.0 flipped
# `@rpath/libswiftCompatibilitySpan.dylib` from a *weak* import to a strong one.
# That shim only exists in /usr/lib/swift on macOS 26; on macOS 15 dyld hard-fails
# at launch ("Library not loaded"), so 2.35.0 and 2.36.0 are unrunnable here even
# though they build fine. 2.34.0 is the last weak-linked release. Verified by
# `otool -L` across 2.32.1-2.36.0 on macOS 15.7.4, 2026-09-06.
#
# Drop this pin (use plain `pkgs.tart`) once every machine is on macOS 26.
#
# Softnet is deliberately not enabled: `tart run --net-softnet` needs a setuid
# helper nix cannot install, and nothing here uses isolated VM networking - tart
# exists to verify a switch on a clean macOS image, which runs on default NAT.
pkgs:
pkgs.tart.overrideAttrs (_: {
  version = "2.34.0";
  src = pkgs.fetchurl {
    url = "https://github.com/openai/tart/releases/download/2.34.0/tart.tar.gz";
    hash = "sha256-yfFgn0lFJY7w7id91E3JcA1vBpeJoR5Dvn81sKZLMTU=";
  };
})
