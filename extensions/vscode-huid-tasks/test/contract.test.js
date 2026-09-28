// Contract tests: the extension against its manifest, the repo's tasks, and
// the global `just task` recipe (tools/just) that creates them. If any of these
// drift apart, the view silently shows the wrong thing.
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { GLOB, parseHuid, parseTask } = require("../tasks");

const ext = path.join(__dirname, "..");
const repo = path.join(ext, "..", "..");
const manifest = JSON.parse(fs.readFileSync(path.join(ext, "package.json"), "utf8"));
const source = fs.readFileSync(path.join(ext, manifest.main), "utf8");

test("activates on the same glob the view lists", () => {
  assert.ok(manifest.activationEvents.includes(`workspaceContains:${GLOB}`));
});

test("every contributed view and command is registered in code", () => {
  for (const view of Object.values(manifest.contributes.views).flat()) {
    assert.match(source, new RegExp(`registerTreeDataProvider\\(\\s*"${view.id}"`), view.id);
  }
  for (const { command } of manifest.contributes.commands) {
    assert.match(source, new RegExp(`registerCommand\\(\\s*"${command.replace(".", "\\.")}"`), command);
  }
});

test("menus only name contributed commands", () => {
  const known = new Set(manifest.contributes.commands.map((c) => c.command));
  for (const entries of Object.values(manifest.contributes.menus)) {
    for (const { command } of entries) assert.ok(known.has(command), command);
  }
});

test("the package ships every local module the extension requires", () => {
  // vsce packages only what "files" lists.
  for (const [, mod] of source.matchAll(/require\("\.\/([^"]+)"\)/g)) {
    const file = mod.endsWith(".js") ? mod : `${mod}.js`;
    assert.ok(manifest.files.includes(file), `${file} is missing from "files"`);
  }
});

test("every task in the repo parses", () => {
  const dir = path.join(repo, "tasks");
  for (const id of fs.readdirSync(dir)) {
    const md = path.join(dir, id, "TASK.md");
    if (!fs.existsSync(md)) continue;
    assert.ok(parseHuid(id), `not a HUID: ${id}`);
    const { title, status } = parseTask(fs.readFileSync(md, "utf8"));
    assert.ok(title, `no title: ${id}`);
    assert.ok(["OPEN", "CLOSED"].includes(status), `bad STATUS in ${id}: ${status}`);
  }
});

const hasJust = spawnSync("just", ["--version"]).status === 0;

test("reads back what `just task` writes", { skip: !hasJust && "just is not installed" }, () => {
  // As `just -g task` runs it: the global justfile, from a scratch dir, with
  // tasks/scripts on PATH as mise links them, and a scratch HOME so no
  // local.just joins in.
  const work = fs.mkdtempSync(path.join(os.tmpdir(), "huid-"));
  fs.mkdirSync(path.join(work, "tasks"));
  const justfile = path.join(repo, "tools", "just", "justfile");
  const env = {
    ...process.env,
    HOME: work,
    PATH: `${path.join(repo, "tasks", "scripts")}${path.delimiter}${process.env.PATH}`,
  };
  const run = spawnSync(
    "just",
    ["--justfile", justfile, "--working-directory", work, "task", "Contract test"],
    { cwd: work, env, encoding: "utf8" },
  );
  assert.equal(run.status, 0, run.stderr);
  const created = run.stdout.trim();
  const id = path.basename(path.dirname(created));
  const { title, status } = parseTask(fs.readFileSync(path.join(work, created), "utf8"));
  assert.equal(title, "Contract test");
  assert.equal(status, "OPEN");
  assert.ok(Math.abs(parseHuid(id) - Date.now()) < 60_000, `HUID ${id} isn't the current time`);
});
