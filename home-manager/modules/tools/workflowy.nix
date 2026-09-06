# workflowy - Workflowy outlines from the command line: CRUD, full-text and
# regex search, bulk replace, content transforms, and usage reports (where the
# content lives, what has gone stale, which nodes are mirrored most).
#
# Not in nixpkgs: neither `pkgs/by-name/wo/workflowy` nor `.../workflowy-cli`
# exists on master or at the pinned rev, so it is built here from upstream's
# tagged source rather than through upstream's own Homebrew tap, which would
# put it outside the generation. Not to be confused with the `workflowy` cask
# both darwin machines already install (darwin/modules/homebrew*.nix) - that is
# the GUI app. The two profiles importing this module are those same two
# machines, so the CLI lands beside the app it drives.
#
# THE CLI, NOT THE MCP SERVER IT ALSO SHIPS. `workflowy mcp` is a subcommand of
# this same binary, so installing the CLI already installs the server and
# nothing here forecloses it. It is just not registered by default: an MCP
# server spends context on its tool schemas in *every* request whether or not
# the session touches Workflowy, which is the argument that moved HackMD the
# other way (from an MCP server to a CLI - see ./hackmd.nix, and work.just's
# chat-casper recipe for what a fat tool roster does to local models). Register
# it per-project in the sessions that actually want it:
#
#   claude mcp add --transport=stdio workflowy -- workflowy mcp              # read tools only
#   claude mcp add --transport=stdio workflowy -- workflowy mcp --expose=all # + write tools
#
# The read/write split is upstream's, and `--write-root-id` sandboxes writes to
# one subtree - worth knowing before handing an agent `--expose=all`.
#
# IMPORTED BY THE DESKTOP PROFILES, NOT common.nix - the same split, and for
# the same reason, as ./ide/vscode.nix. common.nix is inherited by the `dev`
# devcontainer, and the Dockerfile runs `nix build ...activationPackage` inside
# the image with no garbage collection afterwards (Dockerfile:117). Since this
# package is in no binary cache, that build realises the whole Go toolchain -
# ~250MB, measured - and every byte of it is then frozen into both the arm64
# and x86 images, for an 11MB binary, on exactly the disk-constrained 2012 MBP
# whose mid-build disk overflow is what put vscode.nix in the profiles. The
# container gains nothing in return: no profile sets `workflowy.apiKeyFile`, so
# every invocation in there fails on a missing key anyway. This is the first
# thing in the tree to build from Go source; nothing in common.nix,
# lib/core-packages.nix or lib/charm-nur.nix pulls that toolchain in today.
#
# It would otherwise be safe for common.nix under the rule hackmd-cli
# established - a CLI reaching the devcontainer must not be able to hit an
# interactive prompt headlessly, because agents call it where nobody ever ran
# `login`. workflowy passes that test: with no key it warns, falls back to
# `--method=backup`, and exits 1 when there is no backup file either (verified
# against v0.9.0 with an empty $HOME and stdin closed). It has two prompts, not
# one - `replace --interactive` and `transform --interactive` (transform.go:381)
# - and both are opt-in per invocation and treat a stdin read error as a skip,
# so neither can hang. Note that on `transform` the short form of that flag is
# `-i`, which on `search` and `replace` means `--ignore-case`: same letter, and
# on `transform` it is the one that stops to ask.
#
# BUILT FROM SOURCE, unlike crush (lib/charm-nur.nix), which is consumed as
# GoReleaser binaries. Upstream tags release archives here too, and they would
# work: Go's own linker ad-hoc code-signs every darwin/arm64 binary it links
# (`NeedCodeSign() = IsDarwin() && IsARM64()`, cmd/link/internal/ld/lib.go:301,
# reaching cmd/internal/codesign), so a GoReleaser tarball is signed enough to
# execute on Apple Silicon without anyone running `codesign`. The reasons to
# build anyway are smaller and duller: one pair of hashes covers all three
# supported systems where fetchurl needs one per platform, and the thing being
# pinned is auditable source rather than someone's CI output. Nothing
# substitutes from cache.nixos.org either way (this package is not in nixpkgs).
# The cost is the Go compiler in the build closure - transient and collectable
# on a real machine, permanent in a Docker layer, which is what the profile
# split above is about.
#
# To bump: change `version`, set `hash` and `vendorHash` to lib.fakeHash in
# turn, and read the real values out of the two mismatch errors. Upstream tags
# as v<version>, so the tag follows the version automatically.
{ config, lib, pkgs, ... }:
let
  cfg = config.workflowy;

  workflowy = pkgs.buildGoModule (finalAttrs: {
    pname = "workflowy";
    version = "0.9.0";

    src = pkgs.fetchFromGitHub {
      owner = "mholzen";
      repo = "workflowy";
      tag = "v${finalAttrs.version}";
      hash = "sha256-fsSkwPEmVbPssLHYB/OkyIkoHSODVlWQV7sOxli660w=";
    };

    vendorHash = "sha256-Fvy8I+InxR0KPjM22knLlSZBi+xempOHJm+Sdo0wmRs=";

    # The module root also holds pkg/ and a bookmarklet; only cmd/workflowy
    # produces a binary, and naming it keeps the build from walking the rest.
    subPackages = [ "cmd/workflowy" ];

    # Upstream's own release ldflags (.goreleaser.yaml), minus -X main.commit
    # and -X main.date: a store path is already an exact build identity, and
    # baking a timestamp in would make the derivation lie about being
    # reproducible. `workflowy version` therefore reports the version with
    # "commit: none / built: unknown", which is honest for a source build.
    ldflags = [
      "-s"
      "-w"
      "-X main.version=${finalAttrs.version}"
    ];

    meta = {
      description = "CLI and MCP server for Workflowy: CRUD, regex search and replace, usage reports";
      homepage = "https://github.com/mholzen/workflowy";
      license = lib.licenses.mit;
      mainProgram = "workflowy";
    };
  });
in
{
  # Where the API key comes from. Upstream resolves it in this order
  # (pkg/workflowy/workflowy.go, ResolveAPIKey): an explicit --api-key-file
  # that differs from the default, then $WORKFLOWY_API_KEY, then
  # ~/.workflowy/api.key. This option only fills in that last slot, so an
  # exported WORKFLOWY_API_KEY still wins and nothing is taken away.
  #
  # A path to link, not a key to inline: the target is symlinked out of the
  # Nix store, so the secret is never world-readable in /nix/store. There is
  # deliberately no agenix secret wired up here yet - unlike hackmd.nix, which
  # inherited its ciphertexts from an earlier PR, no workflowy-api-key.age
  # exists to point at. Minting one later is the natural next step and needs
  # no change to this file:
  #
  #   rage -a -e -r <recipient> -o secrets/personal/workflowy-api-key.age
  #   # declare it in secrets/secrets.nix, then in a profile:
  #   age.secrets.workflowy-api-key.file = ../../secrets/personal/workflowy-api-key.age;
  #   workflowy.apiKeyFile = config.age.secrets.workflowy-api-key.path;
  #
  # Until then, `mkdir -p ~/.workflowy && pbpaste > ~/.workflowy/api.key`
  # (key from https://workflowy.com/api-key/) is what upstream expects, and
  # leaving this null keeps home-manager's hands off that file.
  options.workflowy.apiKeyFile = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = lib.literalExpression "config.age.secrets.workflowy-api-key.path";
    description = ''
      Absolute path to a file holding the Workflowy API key, symlinked to
      `~/.workflowy/api.key` (upstream's default location) out of the Nix
      store. When null, `~/.workflowy/api.key` is left unmanaged.
    '';
  };

  config.home = {
    packages = [ workflowy ];

    file.".workflowy/api.key" = lib.mkIf (cfg.apiKeyFile != null) {
      source = config.lib.file.mkOutOfStoreSymlink cfg.apiKeyFile;
    };
  };
}
