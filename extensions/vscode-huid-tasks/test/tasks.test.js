// Unit tests for tasks.js, the extension's pure logic, against the spec in
// tasks/README.md. Plain `node --test`: no dependencies, no VS Code.
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { parseHuid, parseTask, openTasks } = require("../tasks");

test("parseHuid reads a HUID as a UTC time", () => {
  assert.equal(parseHuid("20260927-231835").toISOString(), "2026-09-27T23:18:35.000Z");
});

test("parseHuid accepts a suffix", () => {
  assert.equal(parseHuid("20260927-231835-claude").toISOString(), "2026-09-27T23:18:35.000Z");
});

test("parseHuid rejects what isn't a HUID", () => {
  for (const id of ["2026-09-27", "20260927", "20260927-2318", "x20260927-231835", "20260927-231835_x"]) {
    assert.equal(parseHuid(id), undefined, id);
  }
});

test("parseHuid rejects a timestamp that isn't a real time", () => {
  // Month 13, day 45, hour 25: Date.UTC would roll these over into 2027.
  for (const id of ["20261345-250000", "20260230-120000", "20260927-236000"]) {
    assert.equal(parseHuid(id), undefined, id);
  }
});

test("parseTask reads the title and STATUS", () => {
  assert.deepEqual(parseTask("# Write tests\n\n- STATUS: OPEN\n- TAGS:\n"), {
    title: "Write tests",
    status: "OPEN",
  });
});

test("parseTask handles CRLF line endings", () => {
  assert.deepEqual(parseTask("# Write tests\r\n\r\n- STATUS: CLOSED\r\n"), {
    title: "Write tests",
    status: "CLOSED",
  });
});

test("parseTask leaves a missing title undefined", () => {
  assert.equal(parseTask("- STATUS: OPEN\n").title, undefined);
});

test("STATUS is OPEN or CLOSED exactly, as tasks/README.md specifies", () => {
  // The bats spec check rejects `open`; the view must not list it either.
  assert.deepEqual(openTasks([{ id: "20260101-000000", text: "# T\n- STATUS: open\n" }]), []);
});

test("openTasks lists only OPEN tasks, newest first", () => {
  const listed = openTasks([
    { id: "20260101-000000", text: "# Old\n- STATUS: OPEN\n" },
    { id: "20260301-000000", text: "# Done\n- STATUS: CLOSED\n" },
    { id: "20260201-000000-claude", text: "# Suffixed\n- STATUS: OPEN\n" },
    { id: "20260201-000000", text: "# Same second\n- STATUS: OPEN\n" },
  ]);
  assert.deepEqual(
    listed.map((t) => t.id),
    ["20260201-000000-claude", "20260201-000000", "20260101-000000"],
  );
});

test("openTasks passes other fields through and dates each task", () => {
  const [t] = openTasks([{ id: "20260101-000000", text: "# T\n- STATUS: OPEN\n", uri: "u" }]);
  assert.equal(t.uri, "u");
  assert.equal(t.title, "T");
  assert.equal(t.created.toISOString(), "2026-01-01T00:00:00.000Z");
});
