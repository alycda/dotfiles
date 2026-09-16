// Thin LSP client. All deck knowledge lives in the server, so this file only
// has to find the binary and hand VS Code a client.
//
// The binary path is resolved build-time-first on purpose. VS Code launched
// from Finder or the Dock inherits launchd's PATH, not a login shell's, so a
// Nix-installed binary in ~/.nix-profile/bin is frequently invisible to it -
// the classic "works in the terminal, not in the editor" failure. The Nix
// module substitutes an absolute store path into SERVER_PATH below, which
// sidesteps PATH entirely; the placeholder is only reached when the extension
// is used outside Nix.
const { workspace } = require('vscode');
const { LanguageClient, TransportKind } = require('vscode-languageclient/node');

// Replaced by home-manager/modules/tools/presenterm.nix at build time.
const SERVER_PATH = '@presenterm_lsp@';

let client;

function resolveServer() {
  const configured = workspace.getConfiguration('presenterm').get('server.path');
  if (configured) return configured;
  if (SERVER_PATH && !SERVER_PATH.startsWith('@')) return SERVER_PATH;
  return process.env.PRESENTERM_LSP_PATH || 'presenterm-lsp';
}

function activate(context) {
  const command = resolveServer();
  const serverOptions = {
    run: { command, transport: TransportKind.stdio },
    debug: { command, transport: TransportKind.stdio },
  };

  const clientOptions = {
    // Attached to all markdown: the server itself decides whether a buffer is
    // a deck and stays silent otherwise, so there is one activation rule
    // across VS Code, Helix and crush rather than three filename conventions.
    documentSelector: [{ scheme: 'file', language: 'markdown' }],
    initializationOptions: {
      alwaysActivate: workspace.getConfiguration('presenterm').get('alwaysActivate') || false,
    },
    synchronize: {
      // Editing an included deck or dropping in a missing image should clear
      // the parent's diagnostics without a manual edit.
      fileEvents: workspace.createFileSystemWatcher('**/*.{md,png,jpg,jpeg,gif,webp,svg}'),
    },
  };

  client = new LanguageClient('presenterm', 'presenterm', serverOptions, clientOptions);
  context.subscriptions.push(client);
  return client.start();
}

function deactivate() {
  return client ? client.stop() : undefined;
}

module.exports = { activate, deactivate };
