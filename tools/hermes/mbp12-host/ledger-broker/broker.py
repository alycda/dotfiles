#!/usr/bin/env python3
"""ledger-broker — minimal MCP server (streamable HTTP, JSON responses) that
exposes exactly five fixed ledger verbs to the boxed Hermes agent.

This is the privilege boundary: the boxed agent has no host shell, so the
only mutations it can request are these verbs, each backed by an existing
gated script. Input validation here, bean-check + git rails in the scripts.

Binds 127.0.0.1:8643; requires Authorization: Bearer <token> (token file
alongside this script, chmod 600). Stdlib only — runs on Catalina python3.
"""
import json
import os
import re
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOME = "/Users/alyssa"
BIN = f"{HOME}/ledger-ingest"
LEDGER = f"{HOME}/ledger"
INBOX = f"{HOME}/Library/Mobile Documents/com~apple~CloudDocs/3282/import"
TOKEN_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "token")
TOKEN = open(TOKEN_PATH).read().strip()
NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._ -]{0,100}$")

TOOLS = [
    {"name": "ledger_status",
     "description": "Ledger status: bean-check result, pending drafts, inbox contents, recent ingest activity, git log.",
     "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False}},
    {"name": "ledger_check",
     "description": "Run bean-check on the live ledger (the ONLY valid way to verify ledger math).",
     "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False}},
    {"name": "ledger_ingest",
     "description": "Start the inbox ingest pipeline in the background (copy new PDFs, classify, auto-draft, gate, notify). Returns immediately — results arrive via Signal notify and ledger_status.",
     "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False}},
    {"name": "ledger_draft",
     "description": "Start a background bookkeeper draft for one staged PDF (basename, e.g. '2026-07-31.pdf'). Returns immediately; the draft lands as import/<file>.draft.beancount (check ledger_status).",
     "inputSchema": {"type": "object", "properties": {"file": {"type": "string"}},
                     "required": ["file"], "additionalProperties": False}},
    {"name": "ledger_read_import",
     "description": "Read a staged text file from import/: extracted statement text (*.txt), drafts (*.draft.beancount), or class sidecars. Read-only; PDFs themselves are not served — read the .txt extract.",
     "inputSchema": {"type": "object", "properties": {"file": {"type": "string"}},
                     "required": ["file"], "additionalProperties": False}},
    {"name": "ledger_approve",
     "description": "Approve a clean draft by PDF basename: executes its PLAN (file the PDF, book the entries), bean-checks, commits or reverts. Refuses REVIEW_NEEDED drafts.",
     "inputSchema": {"type": "object", "properties": {"name": {"type": "string"}},
                     "required": ["name"], "additionalProperties": False}},
]


def run(cmd, timeout=900):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        out = (p.stdout or "") + (("\n[stderr]\n" + p.stderr) if p.stderr.strip() else "")
        return out.strip()[-8000:] or "(no output)", p.returncode != 0
    except subprocess.TimeoutExpired:
        return "ERROR: command timed out", True


def valid_name(n):
    return bool(NAME_RE.match(n)) and ".." not in n and "/" not in n


def spawn(cmd, logname):
    log = open(f"{BIN}/{logname}", "ab")
    subprocess.Popen(cmd, stdout=log, stderr=log, start_new_session=True)


def call_tool(name, args):
    if name == "ledger_status":
        return run([f"{BIN}/status.sh"])
    if name == "ledger_check":
        return run([f"{BIN}/check-main.sh"])
    if name == "ledger_ingest":
        spawn([f"{BIN}/ingest.sh"], "ingest.log")
        return ("ingest started in background — new arrivals will classify/draft; "
                "watch for the Signal notification, then ledger_status."), False
    if name == "ledger_draft":
        f = args.get("file", "")
        if not valid_name(f):
            return "ERROR: invalid file name", True
        if not (os.path.isfile(f"{LEDGER}/import/{f}") or os.path.isfile(f"{INBOX}/{f}")):
            return "ERROR: no such file in import/ or inbox", True
        cls = "manual"
        try:
            cls = open(f"{INBOX}/.{f}.class").read().strip() or "manual"
        except OSError:
            pass
        spawn([f"{BIN}/draft.sh", f, cls], "ingest.log")
        return (f"draft started in background for {f} (class: {cls}) — takes a few "
                "minutes; result lands as import/{}.draft.beancount (ledger_status)".format(f)), False
    if name == "ledger_read_import":
        f = args.get("file", "")
        if not valid_name(f):
            return "ERROR: invalid file name", True
        if not (f.endswith(".txt") or f.endswith(".draft.beancount")
                or f.endswith(".class") or f.endswith(".md")):
            return "ERROR: only .txt / .draft.beancount / .class / .md are readable", True
        path = f"{LEDGER}/import/{f}"
        if not os.path.isfile(path):
            return f"ERROR: no such file: import/{f}", True
        try:
            return open(path, errors="replace").read()[:16000] or "(empty file)", False
        except OSError as e:
            return f"ERROR: {e}", True
    if name == "ledger_approve":
        n = args.get("name", "")
        if not valid_name(n):
            return "ERROR: invalid name", True
        return run([f"{BIN}/approve.sh", n])
    return f"ERROR: unknown tool {name}", True


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send(self, code, payload=None):
        body = b"" if payload is None else json.dumps(payload).encode()
        self.send_response(code)
        if body:
            self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_GET(self):  # no SSE stream offered; clients fall back to POST-only
        self._send(405)

    def do_POST(self):
        if self.headers.get("Authorization", "") != f"Bearer {TOKEN}":
            self._send(401)
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            msg = json.loads(self.rfile.read(length))
        except Exception:
            self._send(400)
            return
        mid = msg.get("id")
        method = msg.get("method", "")
        if method.startswith("notifications/"):
            self._send(202)
            return
        if method == "initialize":
            proto = (msg.get("params") or {}).get("protocolVersion", "2025-03-26")
            self._send(200, {"jsonrpc": "2.0", "id": mid, "result": {
                "protocolVersion": proto,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": "ledger-broker", "version": "1.0.0"}}})
            return
        if method == "ping":
            self._send(200, {"jsonrpc": "2.0", "id": mid, "result": {}})
            return
        if method == "tools/list":
            self._send(200, {"jsonrpc": "2.0", "id": mid, "result": {"tools": TOOLS}})
            return
        if method == "tools/call":
            params = msg.get("params") or {}
            out, is_err = call_tool(params.get("name", ""), params.get("arguments") or {})
            self._send(200, {"jsonrpc": "2.0", "id": mid, "result": {
                "content": [{"type": "text", "text": out}], "isError": is_err}})
            return
        self._send(200, {"jsonrpc": "2.0", "id": mid,
                         "error": {"code": -32601, "message": f"method not found: {method}"}})

    def log_message(self, fmt, *a):
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % a))


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 8643), Handler).serve_forever()
