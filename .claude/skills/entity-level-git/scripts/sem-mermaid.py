#!/usr/bin/env python3
"""Render `sem impact` as a Mermaid flowchart, drawing only edges sem reported.

    sem-mermaid.py [--max-nodes N] [-C DIR] -- <sem impact arguments>
    sem-mermaid.py -- Greeter --file src/greeter.ts --depth 1

Nodes come from `sem impact --json` (the entity, its dependencies, and every
transitively affected entity). Edges come from `sem graph --json`, filtered
to that node set: impact's JSON gives each entity's depth but not which
entity it was reached through, so drawing depth-2 arrows from impact alone
would mean guessing them. Possible callers that sem could not resolve are
drawn dotted, because an unresolved caller is still a caller to check.

Refuses to draw (exit 2) when the graph has no edges - an empty graph
rendered as a diagram reads as "nothing depends on this" - and (exit 3) when
the node count exceeds --max-nodes, rather than silently dropping nodes.
Read-only: runs `sem impact --json` and `sem graph --json`, nothing else.
"""

import argparse
import json
import subprocess
import sys


def sem(args, cwd):
    out = subprocess.run(["sem", *args], cwd=cwd, capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f"sem {' '.join(args)} failed ({out.returncode}):\n{out.stderr.strip()}")
    return json.loads(out.stdout)


# Extensions that can call each other; anything else is its own family.
FAMILIES = [{"ts", "tsx", "mts", "cts", "js", "jsx", "mjs", "cjs"},
            {"c", "h", "cc", "cpp", "cxx", "hh", "hpp", "hxx"}]


def family(path):
    ext = path.rsplit(".", 1)[-1]
    return next((frozenset(f) for f in FAMILIES if ext in f), ext)


def label(e):
    name = e.get("name") or e.get("entity")
    line = (e.get("lines") or [e.get("start_line")])[0]
    return f'{e.get("type", "?")} {name}<br/>{e["file"]}:{line}'.replace('"', "#quot;")


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--max-nodes", type=int, default=20)
    p.add_argument("-C", dest="cwd", default=None, help="repository to run sem in")
    p.add_argument("impact_args", nargs=argparse.REMAINDER)
    a = p.parse_args()
    impact_args = [x for x in a.impact_args if x != "--"]
    if not impact_args:
        p.error("pass the entity to sem impact after --")

    graph = sem(["graph", "--json"], a.cwd)
    imp = sem(["impact", *impact_args, "--json"], a.cwd)
    target = imp["entity"]

    # Entity ids are "<path>::<kind>::<name>". Count edges in the target's
    # language, not the repo: a mixed repo can have edges in TS and none in
    # the language you asked about, and that language's diagram would lie.
    lang = family(target["file"])
    lang_edges = sum(1 for e in graph.get("edges", [])
                     if family(e["fromEntity"].split("::", 1)[0]) == lang)
    if not lang_edges:
        print(f"sem graph has 0 edges from {target['file']}'s language: no dependency "
              "data, so a diagram would be a false 'nothing depends on this'. "
              "Not drawing. Fall back to `rg` for callers.", file=sys.stderr)
        sys.exit(2)

    nodes = {target["entityId"]: target}
    for e in imp.get("dependencies", []) + imp.get("impact", {}).get("entities", []):
        nodes.setdefault(e["entityId"], e)
    # sem's possible-caller list matches by name across languages (verified on
    # 0.27.0: a TS method lists a Dart caller). A call cannot cross languages,
    # so keep those sharing the target's file extension and say what was cut.
    every_possible = imp.get("possibleCallers", [])
    possible = [pc for pc in every_possible if family(pc["file"]) == lang]
    dropped = len(every_possible) - len(possible)
    if len(nodes) + len(possible) > a.max_nodes:
        print(f"{len(nodes)} entities + {len(possible)} possible callers exceed "
              f"--max-nodes {a.max_nodes}; lower --depth or raise the cap.", file=sys.stderr)
        sys.exit(3)

    ids = {eid: f"n{i}" for i, eid in enumerate(nodes)}
    tests = {t["entityId"] for t in imp.get("tests", [])}
    deps = {d["entityId"] for d in imp.get("dependencies", [])}

    out = ["flowchart LR",
           "  %% sem impact + sem graph; solid edges resolved, dotted unresolved"]
    for eid, e in nodes.items():
        out.append(f'  {ids[eid]}["{label(e)}"]')
    for edge in graph["edges"]:
        f, t = edge["fromEntity"], edge["toEntity"]
        if f in ids and t in ids and f != t:
            arrow = "-->" if edge.get("refType") == "calls" else f'-- {edge.get("refType")} -->'
            out.append(f"  {ids[f]} {arrow} {ids[t]}")
    for i, pc in enumerate(possible):
        pid = f"p{i}"
        out.append(f'  {pid}["{label(pc)}"]:::possible')
        out.append(f"  {pid} -. unresolved .-> {ids[target['entityId']]}")

    out.append(f"  class {ids[target['entityId']]} target")
    for group, cls in ((tests, "test"), (deps, "dep")):
        members = [ids[x] for x in group if x in ids]
        if members:
            out.append(f"  class {','.join(members)} {cls}")
    out += ["  classDef target stroke-width:3px",
            "  classDef test stroke-dasharray:2 2",
            "  classDef dep opacity:0.7",
            "  classDef possible stroke-dasharray:5 5,opacity:0.7"]
    if not imp.get("callersComplete", True):
        why = "; ".join(r["detail"] for r in imp.get("incompleteBecause", []))
        out.insert(2, f"  %% INCOMPLETE caller set: {why}")
    if dropped:
        out.insert(2, f"  %% {dropped} possible caller(s) in other languages omitted")
    if imp.get("noTestReaches"):
        out.insert(2, "  %% no test reaches the target through resolved callers")
    print("\n".join(out))


if __name__ == "__main__":
    main()
