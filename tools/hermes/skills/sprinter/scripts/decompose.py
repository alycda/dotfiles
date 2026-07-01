#!/usr/bin/env python3
"""Sprint manifest decomposer.

Takes a Linear parent ticket payload (JSON) on stdin and produces a sprint
manifest (YAML) on stdout. The manifest is then human-reviewed before
sprinter creates kanban tasks.

The MCP-fetching step happens in the agent's session — this script only
handles the local decomposition logic, so it can be tested in isolation
and reasoned about without an LLM in the loop.

Input shape (JSON on stdin):
    {
      "parent": {
        "id": "PROJ-3481",
        "url": "https://linear.app/example/issue/PROJ-3481",
        "title": "...",
        "workspace": "ditto",
        "state": "in-progress",
        "estimate": null,
        "labels": [...]
      },
      "subissues": [
        {
          "id": "PROJ-3482",
          "title": "...",
          "estimate": 2,
          "labels": ["area:jvm"],
          "blockedBy": ["PROJ-3488"],
          "blocks": []
        },
        ...
      ]
    }

Output: a YAML manifest matching templates/sprint-manifest.example.yaml.

Conservative by default — when in doubt, surface as an `asks_to_user` entry
rather than guessing.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from typing import Any

# --- SDK target detection ---------------------------------------------------

SDK_PATTERNS: list[tuple[re.Pattern, str]] = [
    (re.compile(r"\b(flutter|flutter-sdk)\b", re.I), "flutter"),
    (re.compile(r"\b(kotlin|jvm|android|kmp)\b", re.I), "jvm"),
    (re.compile(r"\b(swift|ios|macos|cocoapods)\b", re.I), "swift"),
    (re.compile(r"\b(dart)\b", re.I), "dart"),
    (re.compile(r"\b(node|wasm|webassembly|js[/_-]wasm|javascript)\b", re.I), "js"),
    (re.compile(r"\b(golang|\bgo[/_-]sdk)\b", re.I), "go"),
    (re.compile(r"\b(python|pyditto)\b", re.I), "python"),
    (re.compile(r"\b(rust core|ditto-core|libdittoffi|rust-sdk)\b", re.I), "rust-core"),
    (re.compile(r"\b(c\+\+|cpp)\b", re.I), "cpp"),
    (re.compile(r"\b(kitchen[\s-]?sink|c[\s-]?api|c[\s-]?ffi)\b", re.I), "c"),
]

LABEL_TO_SDK: dict[str, str] = {
    "area:flutter": "flutter",
    "area:jvm": "jvm",
    "area:swift": "swift",
    "area:dart": "dart",
    "area:js": "js",
    "area:wasm": "js",
    "area:go": "go",
    "area:python": "python",
    "area:rust": "rust-core",
    "area:cpp": "cpp",
    "area:c": "c",
    "area:ffi": "c",
    "sdk-flutter": "flutter",
    "sdk-jvm": "jvm",
    "sdk-swift": "swift",
    "sdk-js": "js",
    "sdk-go": "go",
    "sdk-python": "python",
}


def detect_sdk_targets(title: str, labels: list[str]) -> list[str]:
    targets: list[str] = []
    for label in labels:
        sdk = LABEL_TO_SDK.get(label.lower())
        if sdk and sdk not in targets:
            targets.append(sdk)
    if not targets:
        for pattern, sdk in SDK_PATTERNS:
            if pattern.search(title) and sdk not in targets:
                targets.append(sdk)
    return targets


# --- Slug generation --------------------------------------------------------

def slugify(text: str, max_len: int = 50) -> str:
    s = re.sub(r"[^a-zA-Z0-9\s-]", "", text.lower())
    s = re.sub(r"\s+", "-", s.strip())
    s = re.sub(r"-+", "-", s)
    return s[:max_len].rstrip("-")


# --- Decomposition core -----------------------------------------------------

STANDALONE_THRESHOLD = 3
SMALL_TICKET_MAX = 2


def decompose(payload: dict[str, Any], options: dict[str, Any]) -> dict[str, Any]:
    parent = payload["parent"]
    subissues: list[dict[str, Any]] = payload.get("subissues") or []

    log: list[dict[str, str]] = []
    asks: list[str] = []

    # Degenerate: no subissues
    if not subissues:
        log.append({
            "level": "info",
            "message": "Parent has no subissues. Generating single-sprint manifest from the parent itself.",
        })
        sprints = [_single_sprint_from_parent(parent)]
        return _build_manifest(parent, sprints, log, asks, options)

    # Categorize each subissue
    standalone: list[dict[str, Any]] = []
    small: list[dict[str, Any]] = []
    unsized: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []

    for sub in subissues:
        state = (sub.get("state") or "").lower()
        if state in ("cancelled", "duplicate"):
            skipped.append(sub)
            log.append({
                "level": "info",
                "message": f"Skipping {sub['id']}: state={state}",
            })
            continue
        est = sub.get("estimate")
        if est is None or est == 0:
            unsized.append(sub)
        elif est <= SMALL_TICKET_MAX:
            small.append(sub)
        else:
            standalone.append(sub)

    # Handle unsized
    if unsized:
        if options.get("auto_skip_unestimated"):
            for sub in unsized:
                skipped.append(sub)
                log.append({
                    "level": "info",
                    "message": f"Auto-skipping {sub['id']}: no estimate (--auto-skip-unestimated).",
                })
            unsized = []
        else:
            asks.append(
                f"{len(unsized)} subissue(s) lack estimates: "
                + ", ".join(s["id"] for s in unsized)
                + ". Estimate, skip, or treat as standalone?"
            )
            for sub in unsized:
                # Default behavior: promote to standalone, flagged
                standalone.append(sub)
                log.append({
                    "level": "warning",
                    "message": f"{sub['id']}: no estimate, defaulted to standalone pending user input.",
                })

    sprints: list[dict[str, Any]] = []

    # Standalone sprints
    for sub in standalone:
        sprints.append(_standalone_sprint(sub))

    # Batch small subissues
    if small:
        batches = _batch_small_subissues(small)
        for batch in batches:
            sprints.append(_batched_sprint(batch))
        log.append({
            "level": "info",
            "message": f"Batched {len(small)} small subissue(s) into {len(batches)} sprint(s).",
        })

    # Resolve cross-sprint blocked_by from Linear graph
    sprints = _resolve_dependencies(sprints, subissues, log)

    return _build_manifest(parent, sprints, log, asks, options)


def _single_sprint_from_parent(parent: dict[str, Any]) -> dict[str, Any]:
    return {
        "sprint_slug": slugify(parent["title"]),
        "title": parent["title"],
        "tickets": [parent["id"]],
        "estimate_total": parent.get("estimate") or 0,
        "sdk_targets": detect_sdk_targets(parent["title"], parent.get("labels") or []),
        "cross_sdk": False,
        "blocked_by": [],
        "notes": "Single-sprint manifest from parent ticket (no subissues).",
    }


def _standalone_sprint(sub: dict[str, Any]) -> dict[str, Any]:
    sdks = detect_sdk_targets(sub["title"], sub.get("labels") or [])
    return {
        "sprint_slug": slugify(sub["title"]),
        "title": sub["title"],
        "tickets": [sub["id"]],
        "estimate_total": sub.get("estimate") or 0,
        "sdk_targets": sdks,
        "cross_sdk": len(sdks) > 1,
        "blocked_by": [],     # filled in by _resolve_dependencies
        "_source_ids": [sub["id"]],
        "notes": f"Standalone sprint (estimate {sub.get('estimate')}).",
    }


def _batch_small_subissues(small: list[dict[str, Any]]) -> list[list[dict[str, Any]]]:
    """Group small subissues into a single batch by default.

    The user's stated preference: 1-2 story-pointed tickets are typically
    handled across multiple SDKs in a single sprint rather than stacked or
    parallel sprints. So default to one batch containing all small tickets;
    the user can split during manifest review if they want.
    """
    if not small:
        return []
    return [small]


def _batched_sprint(batch: list[dict[str, Any]]) -> dict[str, Any]:
    all_sdks: list[str] = []
    for sub in batch:
        for sdk in detect_sdk_targets(sub["title"], sub.get("labels") or []):
            if sdk not in all_sdks:
                all_sdks.append(sdk)

    estimate = sum(sub.get("estimate") or 0 for sub in batch)

    title = _suggest_batch_title(batch, all_sdks)

    return {
        "sprint_slug": slugify(title),
        "title": title,
        "tickets": [sub["id"] for sub in batch],
        "estimate_total": estimate,
        "sdk_targets": all_sdks,
        "cross_sdk": len(all_sdks) > 1,
        "blocked_by": [],     # filled in by _resolve_dependencies
        "_source_ids": [sub["id"] for sub in batch],
        "notes": f"Batched sprint ({len(batch)} tickets, total estimate {estimate}).",
    }


def _suggest_batch_title(batch: list[dict[str, Any]], sdks: list[str]) -> str:
    """Suggest a human-readable batch title.

    Heuristic: find a contiguous multi-word phrase shared across all titles,
    excluding common stopwords and SDK names. If found, use that. Otherwise
    fall back to a generic name — user is going to rename during manifest
    review anyway.
    """
    titles = [sub["title"] for sub in batch]
    if not titles or len(titles) < 2:
        # Single-ticket batch — just use the ticket's title
        return titles[0] if titles else "small-tickets-batch"

    # Strip SDK-name tokens from each title before looking for common phrases
    sdk_tokens = {
        "jvm", "kotlin", "android", "swift", "ios", "macos", "dart", "flutter",
        "js", "node", "wasm", "javascript", "go", "golang", "python", "pyditto",
        "rust", "cpp", "c++", "c",
    }
    stopwords = {"the", "a", "an", "for", "in", "on", "of", "and", "or", "to", "across"}

    def cleaned_tokens(title: str) -> list[str]:
        return [
            t for t in re.findall(r"\w+", title.lower())
            if t not in sdk_tokens and t not in stopwords
        ]

    token_lists = [cleaned_tokens(t) for t in titles]
    if not all(token_lists):
        return "small-tickets-batch"

    # Find the longest contiguous token sequence shared across all titles
    first = token_lists[0]
    best: list[str] = []
    for start in range(len(first)):
        for end in range(start + 1, len(first) + 1):
            candidate = first[start:end]
            if all(_contains_sequence(other, candidate) for other in token_lists[1:]):
                if len(candidate) > len(best):
                    best = candidate

    if best:
        phrase = "-".join(best)
        if sdks:
            return f"{phrase}-across-sdks"
        return f"{phrase}-batch"
    return "small-tickets-batch"


def _contains_sequence(haystack: list[str], needle: list[str]) -> bool:
    if not needle:
        return True
    for i in range(len(haystack) - len(needle) + 1):
        if haystack[i:i + len(needle)] == needle:
            return True
    return False


def _resolve_dependencies(
    sprints: list[dict[str, Any]],
    subissues: list[dict[str, Any]],
    log: list[dict[str, str]],
) -> list[dict[str, Any]]:
    # Build lookup: ticket_id -> sprint_slug
    ticket_to_sprint: dict[str, str] = {}
    for sp in sprints:
        for tid in sp.get("_source_ids", sp.get("tickets", [])):
            ticket_to_sprint[tid] = sp["sprint_slug"]

    sub_by_id = {s["id"]: s for s in subissues}
    external_deps: list[dict[str, str]] = []

    for sp in sprints:
        blocked_by_slugs: list[str] = []
        for tid in sp.get("_source_ids", sp.get("tickets", [])):
            sub = sub_by_id.get(tid)
            if not sub:
                continue
            for upstream in sub.get("blockedBy") or []:
                upstream_slug = ticket_to_sprint.get(upstream)
                if upstream_slug and upstream_slug != sp["sprint_slug"]:
                    if upstream_slug not in blocked_by_slugs:
                        blocked_by_slugs.append(upstream_slug)
                elif not upstream_slug:
                    external_deps.append({
                        "downstream_ticket": tid,
                        "external_blocker": upstream,
                    })
                    log.append({
                        "level": "warning",
                        "message": f"{tid} blockedBy {upstream}, which is outside this manifest's tree. External dep — surfaced separately.",
                    })
        if blocked_by_slugs:
            sp["blocked_by"] = [{"sprint_slug": s} for s in blocked_by_slugs]
            log.append({
                "level": "info",
                "message": f"Sprint {sp['sprint_slug']} blocked_by: {', '.join(blocked_by_slugs)}",
            })

    # Strip the internal field from output
    for sp in sprints:
        sp.pop("_source_ids", None)

    # Cycle detection
    if _has_cycle(sprints):
        log.append({
            "level": "error",
            "message": "Cycle detected in sprint dependency graph. Manifest cannot be honored as-is — user must resolve before approval.",
        })

    return sprints


def _has_cycle(sprints: list[dict[str, Any]]) -> bool:
    graph: dict[str, list[str]] = {sp["sprint_slug"]: [] for sp in sprints}
    for sp in sprints:
        for dep in sp.get("blocked_by", []):
            graph[sp["sprint_slug"]].append(dep["sprint_slug"])

    WHITE, GRAY, BLACK = 0, 1, 2
    color: dict[str, int] = {n: WHITE for n in graph}

    def visit(n: str) -> bool:
        color[n] = GRAY
        for nbr in graph.get(n, []):
            c = color.get(nbr, WHITE)
            if c == GRAY:
                return True
            if c == WHITE and visit(nbr):
                return True
        color[n] = BLACK
        return False

    for n in graph:
        if color[n] == WHITE:
            if visit(n):
                return True
    return False


def _build_manifest(
    parent: dict[str, Any],
    sprints: list[dict[str, Any]],
    log: list[dict[str, str]],
    asks: list[str],
    options: dict[str, Any],
) -> dict[str, Any]:
    return {
        "version": 1,
        "sprinter_run_id": options.get("run_id", _generate_run_id()),
        "created": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "parent": {
            "id": parent["id"],
            "url": parent.get("url", ""),
            "title": parent.get("title", ""),
            "workspace": parent.get("workspace", ""),
            "state": parent.get("state", ""),
        },
        "sprints": sprints,
        "decomposition_log": log,
        "external_dependencies": [],   # filled if we collected any
        "asks_to_user": asks,
        "assignment_policy": {
            "default": {
                "plan_assignee": "default",
                "exec_assignee": "default",
                "retro_assignee": "default",
            }
        },
    }


def _generate_run_id() -> str:
    ts = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
    return f"sprinter-run-{ts}"


# --- YAML emission (no third-party deps) ------------------------------------

def emit_yaml(manifest: dict[str, Any]) -> str:
    # Hand-written YAML emitter: same approach as ledger.py — narrow subset,
    # zero deps.
    lines: list[str] = []
    lines.append(f"version: {manifest['version']}")
    lines.append(f"sprinter_run_id: {manifest['sprinter_run_id']}")
    lines.append(f"created: {manifest['created']}")
    lines.append("")
    lines.append("parent:")
    p = manifest["parent"]
    for k in ["id", "url", "title", "workspace", "state"]:
        lines.append(f"  {k}: {_yaml_value(p.get(k, ''))}")
    lines.append("")
    lines.append("sprints:")
    for sp in manifest["sprints"]:
        lines.append("")
        lines.append(f"  - sprint_slug: {sp['sprint_slug']}")
        lines.append(f"    title: {_yaml_value(sp['title'])}")
        lines.append("    tickets:")
        for t in sp["tickets"]:
            lines.append(f"      - {t}")
        lines.append(f"    estimate_total: {sp['estimate_total']}")
        lines.append(f"    sdk_targets: [{', '.join(sp['sdk_targets'])}]")
        lines.append(f"    cross_sdk: {str(sp['cross_sdk']).lower()}")
        if sp.get("blocked_by"):
            lines.append("    blocked_by:")
            for dep in sp["blocked_by"]:
                lines.append(f"      - sprint_slug: {dep['sprint_slug']}")
        else:
            lines.append("    blocked_by: []")
        if sp.get("notes"):
            lines.append(f"    notes: {_yaml_value(sp['notes'])}")
    lines.append("")
    if manifest.get("decomposition_log"):
        lines.append("decomposition_log:")
        for entry in manifest["decomposition_log"]:
            lines.append(f"  - level: {entry['level']}")
            lines.append(f"    message: {_yaml_value(entry['message'])}")
        lines.append("")
    if manifest.get("external_dependencies"):
        lines.append("external_dependencies:")
        for ext in manifest["external_dependencies"]:
            lines.append(f"  - downstream_ticket: {ext['downstream_ticket']}")
            lines.append(f"    external_blocker: {ext['external_blocker']}")
        lines.append("")
    else:
        lines.append("external_dependencies: []")
        lines.append("")
    if manifest.get("asks_to_user"):
        lines.append("asks_to_user:")
        for ask in manifest["asks_to_user"]:
            lines.append(f"  - {_yaml_value(ask)}")
        lines.append("")
    else:
        lines.append("asks_to_user: []")
        lines.append("")
    lines.append("assignment_policy:")
    lines.append("  default:")
    for k, v in manifest["assignment_policy"]["default"].items():
        lines.append(f"    {k}: {v}")
    return "\n".join(lines) + "\n"


def _yaml_value(value: Any) -> str:
    s = str(value)
    if s == "" or any(c in s for c in ":#'\"\n") or s.strip() != s:
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return s


# --- CLI --------------------------------------------------------------------

def main() -> int:
    p = argparse.ArgumentParser(
        prog="decompose",
        description="Decompose a Linear parent ticket payload into a sprint manifest.",
    )
    p.add_argument(
        "--auto-skip-unestimated",
        action="store_true",
        help="Skip subissues without estimates rather than asking the user.",
    )
    p.add_argument(
        "--run-id",
        help="Override the sprinter_run_id. Default: sprinter-run-<utc-iso>.",
    )
    p.add_argument(
        "--input",
        help="Read JSON payload from a file instead of stdin.",
    )
    args = p.parse_args()

    if args.input:
        with open(args.input) as f:
            payload = json.load(f)
    else:
        payload = json.load(sys.stdin)

    options = {
        "auto_skip_unestimated": args.auto_skip_unestimated,
        "run_id": args.run_id or _generate_run_id(),
    }
    manifest = decompose(payload, options)
    sys.stdout.write(emit_yaml(manifest))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
