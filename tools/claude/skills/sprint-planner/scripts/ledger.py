#!/usr/bin/env python3
"""Sprint ledger CRUD.

The ledger lives at docs/sprints/ledger.yaml relative to the repo root and
tracks each sprint's id, title, status, and timestamps. Statuses:
planned | in-progress | done | abandoned.

The on-disk format is a deliberately narrow subset of YAML (a top-level
``sprints:`` list of flat string-valued records). We parse and emit it by
hand so this script has zero third-party dependencies.
"""
from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
from pathlib import Path

STATUSES = ["planned", "in-progress", "done", "abandoned"]
SPRINT_RE = re.compile(r"^SPRINT-(\d{4})$")
FIELDS = ("id", "title", "status", "executor", "branch", "worktree", "created", "updated")
EXECUTORS = ["opus", "gpt-5.5", "gemini"]


def project_root() -> Path:
    # Anchor on the project that owns this skill: the dir containing
    # ``.claude/skills/sprint-planner``. The skill script lives at
    # <project>/.claude/skills/sprint-planner/scripts/ledger.py, so the
    # project root is four parents up.
    return Path(__file__).resolve().parents[4]


def ledger_path() -> Path:
    return project_root() / "docs" / "sprints" / "ledger.yaml"


def _yaml_escape(value: str) -> str:
    # Quote anything that could confuse the narrow parser; otherwise leave bare.
    if value == "" or any(c in value for c in ":#\"'\n") or value.strip() != value:
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return value


def _yaml_unescape(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        inner = value[1:-1]
        if value[0] == '"':
            inner = inner.replace('\\"', '"').replace("\\\\", "\\")
        return inner
    return value


def load() -> dict:
    p = ledger_path()
    if not p.exists():
        return {"sprints": []}
    sprints: list[dict] = []
    current: dict | None = None
    for raw in p.read_text().splitlines():
        line = raw.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        if line == "sprints:" or line == "sprints: []":
            continue
        stripped = line.lstrip()
        if stripped.startswith("- "):
            if current is not None:
                sprints.append(current)
            current = {}
            stripped = stripped[2:]
            if ":" in stripped:
                k, _, v = stripped.partition(":")
                current[k.strip()] = _yaml_unescape(v)
            continue
        if current is None:
            continue
        if ":" in stripped:
            k, _, v = stripped.partition(":")
            current[k.strip()] = _yaml_unescape(v)
    if current is not None:
        sprints.append(current)
    return {"sprints": sprints}


def save(data: dict) -> None:
    p = ledger_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    lines = ["sprints:"]
    if not data["sprints"]:
        lines = ["sprints: []"]
    else:
        for s in data["sprints"]:
            first = True
            for k in FIELDS:
                if k not in s:
                    continue
                prefix = "  - " if first else "    "
                lines.append(f"{prefix}{k}: {_yaml_escape(str(s[k]))}")
                first = False
    p.write_text("\n".join(lines) + "\n")


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def next_id(data: dict) -> str:
    max_n = 0
    for s in data["sprints"]:
        m = SPRINT_RE.match(s.get("id", ""))
        if m:
            max_n = max(max_n, int(m.group(1)))
    return f"SPRINT-{max_n + 1:04d}"


def find(data: dict, sprint_id: str) -> dict | None:
    for s in data["sprints"]:
        if s.get("id") == sprint_id:
            return s
    return None


def cmd_add(args) -> int:
    data = load()
    sid = args.id or next_id(data)
    if find(data, sid):
        sys.stderr.write(f"{sid} already exists\n")
        return 1
    record = {
        "id": sid,
        "title": args.title,
        "status": "planned",
        "created": now(),
        "updated": now(),
    }
    if args.branch:
        record["branch"] = args.branch
    if args.worktree:
        record["worktree"] = args.worktree
    data["sprints"].append(record)
    save(data)
    print(sid)
    return 0


def cmd_list(args) -> int:
    data = load()
    rows = data["sprints"]
    if args.status:
        rows = [s for s in rows if s.get("status") == args.status]
    if not rows:
        return 0
    width = max(len(s.get("id", "")) for s in rows)
    for s in rows:
        print(f"{s.get('id',''):<{width}}  {s.get('status',''):<12}  {s.get('title','')}")
    return 0


def cmd_get(args) -> int:
    data = load()
    s = find(data, args.id)
    if not s:
        sys.stderr.write(f"{args.id} not found\n")
        return 1
    for k in FIELDS:
        if k in s:
            print(f"{k}: {s[k]}")
    return 0


def cmd_set_status(args) -> int:
    data = load()
    s = find(data, args.id)
    if not s:
        sys.stderr.write(f"{args.id} not found\n")
        return 1
    s["status"] = args.status
    s["updated"] = now()
    save(data)
    return 0


def cmd_set_executor(args) -> int:
    data = load()
    s = find(data, args.id)
    if not s:
        sys.stderr.write(f"{args.id} not found\n")
        return 1
    if args.executor == "":
        s.pop("executor", None)
    else:
        s["executor"] = args.executor
    s["updated"] = now()
    save(data)
    return 0


def cmd_set_branch(args) -> int:
    data = load()
    s = find(data, args.id)
    if not s:
        sys.stderr.write(f"{args.id} not found\n")
        return 1
    if args.branch == "":
        s.pop("branch", None)
    else:
        s["branch"] = args.branch
    s["updated"] = now()
    save(data)
    return 0


def cmd_set_worktree(args) -> int:
    data = load()
    s = find(data, args.id)
    if not s:
        sys.stderr.write(f"{args.id} not found\n")
        return 1
    if args.worktree == "":
        s.pop("worktree", None)
    else:
        s["worktree"] = args.worktree
    s["updated"] = now()
    save(data)
    return 0


def cmd_set_title(args) -> int:
    data = load()
    s = find(data, args.id)
    if not s:
        sys.stderr.write(f"{args.id} not found\n")
        return 1
    s["title"] = args.title
    s["updated"] = now()
    save(data)
    return 0


def cmd_remove(args) -> int:
    data = load()
    before = len(data["sprints"])
    data["sprints"] = [s for s in data["sprints"] if s.get("id") != args.id]
    if len(data["sprints"]) == before:
        sys.stderr.write(f"{args.id} not found\n")
        return 1
    save(data)
    return 0


def cmd_next_id(_args) -> int:
    print(next_id(load()))
    return 0


def main() -> int:
    p = argparse.ArgumentParser(prog="ledger")
    sub = p.add_subparsers(dest="cmd", required=True)

    a = sub.add_parser("add", help="register a new sprint (status=planned)")
    a.add_argument("title")
    a.add_argument("--id", help="override auto-assigned id")
    a.add_argument("--branch", default=None, help="branch name (typically Linear-formatted)")
    a.add_argument("--worktree", default=None, help="worktree path (relative or absolute)")
    a.set_defaults(func=cmd_add)

    l = sub.add_parser("list")
    l.add_argument("--status", choices=STATUSES)
    l.set_defaults(func=cmd_list)

    g = sub.add_parser("get")
    g.add_argument("id")
    g.set_defaults(func=cmd_get)

    s = sub.add_parser("set-status")
    s.add_argument("id")
    s.add_argument("status", choices=STATUSES)
    s.set_defaults(func=cmd_set_status)

    e = sub.add_parser("set-executor", help="record which model is implementing the sprint")
    e.add_argument("id")
    e.add_argument("executor", help=f"one of {EXECUTORS}, or '' to clear")
    e.set_defaults(func=cmd_set_executor)

    b = sub.add_parser("set-branch", help="record the branch where the sprint runs")
    b.add_argument("id")
    b.add_argument("branch", help="branch name, or '' to clear")
    b.set_defaults(func=cmd_set_branch)

    w = sub.add_parser("set-worktree", help="record the worktree path where the sprint runs")
    w.add_argument("id")
    w.add_argument("worktree", help="worktree path (relative or absolute), or '' to clear")
    w.set_defaults(func=cmd_set_worktree)

    t = sub.add_parser("set-title")
    t.add_argument("id")
    t.add_argument("title")
    t.set_defaults(func=cmd_set_title)

    r = sub.add_parser("remove")
    r.add_argument("id")
    r.set_defaults(func=cmd_remove)

    n = sub.add_parser("next-id", help="print what the next sprint id would be")
    n.set_defaults(func=cmd_next_id)

    args = p.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
