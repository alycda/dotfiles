# presenterm - terminal slideshows from markdown - plus the in-tree language
# server that makes a deck verifiable before you stand in front of a room with
# it.
#
# WHY A LANGUAGE SERVER AND NOT A LINT SCRIPT. presenterm has no headless
# validation mode. `--validate-overflows` needs a real terminal to measure
# against, and every other path renders: on a broken deck presenterm does not
# exit with a diagnostic, it opens its TUI and displays the error in-app,
# waiting for the file to change (verified against upstream 0.16.1 - a build
# error under `script -qec` hangs until killed). So "is this deck valid?" had
# no answer outside an interactive terminal at all. One engine now answers it
# in three editors and in CI:
#
#   presenterm-lsp                  LSP over stdio (helix, VS Code, crush)
#   presenterm-lsp --check FILE...  exit 1 on any error (just, CI, hooks)
#
# The other reason it is a server and not a linter: presenterm stops at the
# *first* build error, so a typo on slide 2 hides everything after it. The
# analysis walks the whole document and reports all of them at once.
#
# ACTIVATION IS BY CONTENT, NOT BY FILENAME. Every editor here attaches the
# server to plain `markdown`, and the server decides per buffer whether the
# document is a deck (front matter, or a comment that parses as a real
# presenterm command). The alternative - a `*.presenterm.md` convention, or a
# separate helix language with a filename glob - would mean three different
# activation rules to keep in sync and a rename for every existing deck,
# including RustConf2026/slides.md. A prose markdown file containing a stray
# `<!-- pasue -->` is explicitly *not* treated as evidence of a deck; see the
# comment on that branch in tools/presenterm-lsp/src/analysis.rs.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.presenterm;

  presenterm-lsp = pkgs.callPackage ../../../lib/presenterm-lsp.nix { };

  extensionSource = ../../../tools/presenterm-lsp/editors/vscode;
  extensionId = "alycda.presenterm-lsp";

  # Same importNpmLock reasoning as ./hackmd.nix: the lockfile is the pin and
  # there is no npmDepsHash to regenerate. The tree here is 8 packages
  # (vscode-languageclient and its three transitive deps plus semver/minimatch),
  # so none of hackmd's override surgery is needed - if a future bump balloons
  # that, this comment is the place to say why.
  nodeModules = pkgs.importNpmLock.buildNodeModules {
    npmRoot = extensionSource;
    inherit (pkgs) nodejs;
  };

  # VS Code launched from Finder or the Dock inherits launchd's PATH, not a
  # login shell's, so `~/.nix-profile/bin` is routinely invisible to it. Baking
  # the absolute store path into the extension is what keeps this from being
  # the usual "works in my terminal" bug report; `presenterm.server.path`
  # remains available as an escape hatch.
  vscodeExtension = pkgs.runCommand "vscode-extension-presenterm-lsp" { } ''
    dir="$out/share/vscode/extensions/${extensionId}"
    mkdir -p "$dir"
    cp ${extensionSource}/package.json "$dir/package.json"
    substitute ${extensionSource}/extension.js "$dir/extension.js" \
      --replace-fail '@presenterm_lsp@' '${lib.getExe presenterm-lsp}'
    ln -s ${nodeModules}/node_modules "$dir/node_modules"
  '';
in
{
  options.presenterm = {
    vscode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = config.programs.vscode.enable or false;
        defaultText = lib.literalExpression "config.programs.vscode.enable";
        description = ''
          Install the bundled VS Code extension. Defaults to following
          `programs.vscode.enable`, so a profile that does not ship VS Code
          does not drag in the nodejs closure for an extension nothing loads.
        '';
      };

      extensionsDir = lib.mkOption {
        type = lib.types.str;
        default = ".vscode/extensions";
        example = ".vscode-insiders/extensions";
        description = ''
          Home-relative VS Code extensions directory. home-manager's vscode
          module leaves this directory mutable by default
          (`programs.vscode.mutableExtensionsDir`, default true) and links each
          extension into it individually, so adding one more entry here uses
          the same mechanism rather than fighting it. Setting that option to
          false makes home-manager own the whole directory, at which point this
          link would collide - use `programs.vscode.profiles.<name>.extensions`
          instead if you ever do that.
        '';
      };
    };
  };

  config = {
    home = {
      packages = [
        pkgs.presenterm
        presenterm-lsp
      ];

      file = lib.mkIf cfg.vscode.enable {
        "${cfg.vscode.extensionsDir}/${extensionId}".source =
          "${vscodeExtension}/share/vscode/extensions/${extensionId}";
      };
    };
  };
}
