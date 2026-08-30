# workflowy - Workflowy outlines from the command line: CRUD, full-text and
# regex search, bulk replace, content transforms, and usage reports (where the
# content lives, what has gone stale, which nodes are mirrored most).
#
# Not in nixpkgs: neither `pkgs/by-name/wo/workflowy` nor `.../workflowy-cli`
# exists on master or at the pinned rev, so it is built here from upstream's
# tagged source. Homebrew and Scoop are upstream's own channels and neither is
# a fit - a Homebrew formula would install it outside the generation on exactly
# one machine class, and nothing would carry it into the Linux devcontainer.
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
# SAFE FOR common.nix, per the rule this repo learned from hackmd-cli: a CLI
# that reaches the devcontainer must not be able to hit an interactive
# credential prompt headlessly, because agents call it on machines where nobody
# ever ran `login`. workflowy never prompts for one. With no key it warns, falls
# back to `--method=backup`, and exits 1 when there is no backup file either -
# verified against v0.9.0 with an empty $HOME and stdin closed. The only prompt
# in the binary is `replace --interactive`, which is opt-in per invocation.
#
# BUILT FROM SOURCE, unlike crush (lib/charm-nur.nix), which upstream ships as
# GoReleaser binaries. Upstream tags release archives here too, but they are
# unsigned, and an unsigned arm64 binary does not execute on Apple Silicon at
# all - so a fetchurl of the darwin archive would trade a Go toolchain at build
# time for a codesigning problem at runtime. buildGoModule also covers all
# three supported systems from one pair of hashes instead of one per platform.
# Nothing substitutes from cache.nixos.org either way (this package is not in
# nixpkgs), so the cost is the Go compiler in the *build* closure - build-time
# only, and collectable - not 11MB of runtime closure per machine.
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
