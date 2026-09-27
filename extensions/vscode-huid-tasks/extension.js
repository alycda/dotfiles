// No build step and no dependencies: `vscode` is provided by the extension
// host at runtime, so plain CommonJS is enough.
const vscode = require("vscode");

const { GLOB, openTasks } = require("./tasks");

const formatter = new Intl.DateTimeFormat(undefined, {
  dateStyle: "medium",
  timeStyle: "short",
});

class TaskProvider {
  constructor() {
    this._onDidChange = new vscode.EventEmitter();
    this.onDidChangeTreeData = this._onDidChange.event;
  }

  refresh() {
    // undefined means "the whole tree"; the 1.74 typings require the argument.
    this._onDidChange.fire(undefined);
  }

  getTreeItem(item) {
    return item;
  }

  async getChildren(element) {
    if (element) return [];

    const uris = await vscode.workspace.findFiles(GLOB);
    const files = await Promise.all(
      uris.map(async (uri) => ({
        uri,
        id: uri.path.split("/").at(-2),
        text: Buffer.from(await vscode.workspace.fs.readFile(uri)).toString("utf8"),
      })),
    );

    return openTasks(files)
      .map((t) => {
        const item = new vscode.TreeItem(t.title || t.id);
        // Tree rows are single-line; `description` is the greyed, smaller
        // text VS Code renders after the label.
        item.description = t.created ? formatter.format(t.created) : t.id;
        item.tooltip = new vscode.MarkdownString(
          `**${t.title || t.id}**\n\n\`${t.id}\`` +
            (t.created ? ` — ${t.created.toISOString()}` : ""),
        );
        item.resourceUri = t.uri;
        item.iconPath = new vscode.ThemeIcon("circle-large-outline");
        item.command = {
          command: "vscode.open",
          title: "Open Task",
          arguments: [t.uri],
        };
        return item;
      });
  }
}

function activate(context) {
  const provider = new TaskProvider();
  const refresh = () => provider.refresh();

  const watcher = vscode.workspace.createFileSystemWatcher(GLOB);
  watcher.onDidCreate(refresh);
  watcher.onDidChange(refresh);
  watcher.onDidDelete(refresh);

  context.subscriptions.push(
    watcher,
    vscode.window.registerTreeDataProvider("huidTasks", provider),
    vscode.commands.registerCommand("huidTasks.refresh", refresh),
  );
}

function deactivate() {}

module.exports = { activate, deactivate };
