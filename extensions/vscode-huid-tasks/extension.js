// No build step and no dependencies: `vscode` is provided by the extension
// host at runtime, so plain CommonJS is enough.
const vscode = require("vscode");

const GLOB = "tasks/*/TASK.md";
// HUID: YYYYMMDD-HHMMSS in UTC, optionally suffixed. See tasks/README.md.
const HUID = /^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})(?:-[a-zA-Z0-9-]*)?$/;

/** @returns {Date | undefined} */
function parseHuid(id) {
  const m = HUID.exec(id);
  if (!m) return undefined;
  const [, y, mo, d, h, mi, s] = m.map(Number);
  return new Date(Date.UTC(y, mo - 1, d, h, mi, s));
}

/** Parse the header of a TASK.md; only the title and STATUS matter here. */
function parseTask(text) {
  const title = /^#\s+(.+)$/m.exec(text)?.[1].trim();
  const status = /^-\s*STATUS:\s*(\S+)/m.exec(text)?.[1].toUpperCase();
  return { title, status };
}

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
    this._onDidChange.fire();
  }

  getTreeItem(item) {
    return item;
  }

  async getChildren(element) {
    if (element) return [];

    const uris = await vscode.workspace.findFiles(GLOB);
    const tasks = await Promise.all(
      uris.map(async (uri) => {
        const bytes = await vscode.workspace.fs.readFile(uri);
        const { title, status } = parseTask(Buffer.from(bytes).toString("utf8"));
        const id = uri.path.split("/").at(-2);
        return { uri, id, title, status, created: parseHuid(id) };
      }),
    );

    return tasks
      .filter((t) => t.status === "OPEN")
      // HUIDs sort lexically in time order; newest first.
      .sort((a, b) => b.id.localeCompare(a.id))
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

module.exports = { activate, deactivate, parseHuid, parseTask };
