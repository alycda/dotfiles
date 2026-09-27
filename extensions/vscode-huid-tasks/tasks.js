// The HUID task logic, kept free of the `vscode` module so plain Node can load
// and test it (test/). extension.js adapts it to VS Code's tree view.

const GLOB = "tasks/*/TASK.md";
// HUID: YYYYMMDD-HHMMSS in UTC, optionally suffixed. See tasks/README.md.
const HUID = /^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})(?:-[a-zA-Z0-9-]*)?$/;

/** @returns {Date | undefined} */
function parseHuid(id) {
  const m = HUID.exec(id);
  if (!m) return undefined;
  const [, y, mo, d, h, mi, s] = m.map(Number);
  const date = new Date(Date.UTC(y, mo - 1, d, h, mi, s));
  // Date.UTC rolls an out-of-range field over (month 13 becomes next year's
  // January), so a HUID is a real time only if every field survives.
  const real =
    date.getUTCFullYear() === y &&
    date.getUTCMonth() === mo - 1 &&
    date.getUTCDate() === d &&
    date.getUTCHours() === h &&
    date.getUTCMinutes() === mi &&
    date.getUTCSeconds() === s;
  return real ? date : undefined;
}

/**
 * Parse the header of a TASK.md; only the title and STATUS matter here.
 * STATUS is returned as written: tasks/README.md allows only OPEN or CLOSED,
 * so `open` is not OPEN.
 */
function parseTask(text) {
  const title = /^#\s+(.+)$/m.exec(text)?.[1].trim();
  const status = /^-\s*STATUS:\s*(\S+)/m.exec(text)?.[1];
  return { title, status };
}

/**
 * The tasks the view lists: the OPEN ones, newest first. Each input is a
 * TASK.md's directory name (its HUID) and text; any other fields, such as a
 * URI, are passed through.
 * @template {{ id: string, text: string }} F
 * @param {F[]} files
 * @returns {(Omit<F, "text"> & { title?: string, status?: string, created?: Date })[]}
 */
function openTasks(files) {
  return (
    files
      .map(({ text, ...rest }) => ({ ...rest, ...parseTask(text), created: parseHuid(rest.id) }))
      .filter((t) => t.status === "OPEN")
      // HUIDs sort lexically in time order; newest first.
      .sort((a, b) => b.id.localeCompare(a.id))
  );
}

module.exports = { GLOB, parseHuid, parseTask, openTasks };
