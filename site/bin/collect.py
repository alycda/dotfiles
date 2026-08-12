#!/usr/bin/env python3
"""Collect md-ish sources from docs/ into a Zola content tree.

Authoring happens in `docs/`: plain markdown with YAML frontmatter, readable
in the repo and by agents without a site build in the loop. Zola wants TOML
frontmatter under `+++`, its own section layout, and taxonomies declared in a
specific shape. Rather than reformat the sources to suit the generator, this
script translates them on the way in — `site/content/` is a build artifact,
never edited by hand, never committed.

It also renders CONCEPTS.md into `site/data/concepts.toml`, which is what
backs the [E01]-style entity references in essays.

Usage: python3 site/bin/collect.py [repo_root]
"""

from __future__ import annotations

import datetime as dt
import re
import shutil
import sys
from pathlib import Path

import yaml

# Frontmatter keys Zola owns natively; everything else is passed through to
# [extra] so templates can reach it without the collector needing to know what
# any given document type puts there.
ZOLA_KEYS = {
    "title", "description", "date", "updated", "slug", "draft", "weight",
    "aliases", "template", "path", "authors", "in_search_index",
    # section-only
    "sort_by", "page_template", "paginate_by", "transparent", "render",
    "generate_feeds", "insert_anchor_links",
}
TAXONOMY_KEYS = {"tags", "category"}
# Essays borrow the "filed under" phrasing from the design this site cribs;
# it lands in the same tag index as everything else.
TAXONOMY_ALIASES = {"filed_under": "tags"}


def toml_value(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, (dt.datetime, dt.date)):
        return value.isoformat()
    if isinstance(value, (list, tuple)):
        return "[" + ", ".join(toml_value(v) for v in value) + "]"
    if isinstance(value, dict):
        return "{" + ", ".join(f"{k} = {toml_value(v)}" for k, v in value.items()) + "}"
    text = str(value)
    if "\n" in text:
        escaped = text.replace("\\", "\\\\").replace('"""', '\\"\\"\\"')
        return f'"""\n{escaped}"""'
    escaped = text.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def split_frontmatter(text: str) -> tuple[dict, str]:
    if not text.startswith("---"):
        return {}, text
    parts = re.split(r"^---\s*$", text, maxsplit=2, flags=re.MULTILINE)
    if len(parts) < 3:
        return {}, text
    return yaml.safe_load(parts[1]) or {}, parts[2].lstrip("\n")


def to_zola_frontmatter(meta: dict, fallback_title: str) -> str:
    top: dict = {}
    taxonomies: dict[str, list] = {}
    extra: dict = {}

    for key, value in meta.items():
        if value is None or value == [] or value == "":
            continue
        target = TAXONOMY_ALIASES.get(key, key)
        if target in TAXONOMY_KEYS:
            values = value if isinstance(value, list) else [value]
            taxonomies.setdefault(target, []).extend(str(v) for v in values)
        elif key in ZOLA_KEYS:
            top[key] = value
        else:
            extra[key] = value

    top.setdefault("title", fallback_title)

    lines = [f"{k} = {toml_value(v)}" for k, v in top.items()]
    if taxonomies:
        lines.append("")
        lines.append("[taxonomies]")
        lines += [f"{k} = {toml_value(v)}" for k, v in sorted(taxonomies.items())]
    if extra:
        lines.append("")
        lines.append("[extra]")
        lines += [f"{k} = {toml_value(v)}" for k, v in extra.items()]
    return "+++\n" + "\n".join(lines) + "\n+++\n\n"


def humanize(stem: str) -> str:
    return stem.replace("-", " ").replace("_", " ").capitalize()


def strip_leading_h1(body: str, title: str) -> str:
    """Drop a body-leading `# Heading` that restates the frontmatter title.

    In-repo, a solution doc wants a visible H1 — it is read as a file. On the
    site the template already renders the title, so the same H1 would appear
    twice.
    """
    match = re.match(r"^#\s+(.+?)\s*\n+", body)
    if match and match.group(1).strip().lower() == (title or "").strip().lower():
        return body[match.end():]
    return body


def collect_page(src: Path, dest: Path, extra_meta: dict | None = None) -> None:
    meta, body = split_frontmatter(src.read_text(encoding="utf-8"))
    for key, value in (extra_meta or {}).items():
        meta.setdefault(key, value)
    body = strip_leading_h1(body, meta.get("title", ""))
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(to_zola_frontmatter(meta, humanize(src.stem)) + body, encoding="utf-8")


def parse_concepts(path: Path) -> list[dict]:
    """Read CONCEPTS.md into an ordered entity list.

    `## Heading` is a group, `### Heading` is an entity, and the prose beneath
    an entity is its definition. Groups with no `### ` entries contribute
    nothing, which is how the "Flagged ambiguities" section stays out of the
    index without needing to be special-cased.
    """
    if not path.exists():
        return []

    concepts: list[dict] = []
    group = ""
    current: dict | None = None

    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            group = line[3:].strip()
            current = None
        elif line.startswith("### "):
            current = {
                "id": f"E{len(concepts) + 1:02d}",
                "name": line[4:].strip(),
                "group": group,
                "slug": re.sub(r"[^a-z0-9]+", "-", line[4:].strip().lower()).strip("-"),
                "lines": [],
            }
            concepts.append(current)
        elif current is not None:
            current["lines"].append(line)

    for concept in concepts:
        concept["definition"] = " ".join(concept.pop("lines")).strip()
    return [c for c in concepts if c["definition"]]


def write_concepts(concepts: list[dict], dest: Path) -> None:
    blocks = []
    for concept in concepts:
        fields = "\n".join(f"{k} = {toml_value(v)}" for k, v in concept.items())
        blocks.append("[[concepts]]\n" + fields)
    dest.parent.mkdir(parents=True, exist_ok=True)
    header = "# Generated from CONCEPTS.md by site/bin/collect.py — do not edit.\n\n"
    dest.write_text(header + "\n\n".join(blocks) + "\n", encoding="utf-8")


def main(root: Path) -> int:
    docs = root / "docs"
    content = root / "site" / "content"

    if content.exists():
        shutil.rmtree(content)
    content.mkdir(parents=True)

    count = 0

    # Essays: mirrored one-for-one, nesting preserved.
    essays = docs / "essays"
    if essays.exists():
        for src in sorted(essays.rglob("*.md")):
            collect_page(src, content / "essays" / src.relative_to(essays))
            count += 1

    # Solutions: flattened. On disk they nest one level deep by category
    # (docs/solutions/build-errors/foo.md) because that is a useful way to
    # browse a repo. Zola would read that directory as a subsection needing
    # its own _index.md, so the nesting is replayed as a `category` taxonomy
    # value instead and every solution lands in one flat, sortable list.
    solutions = docs / "solutions"
    if solutions.exists():
        for src in sorted(solutions.rglob("*.md")):
            if src.name == "_index.md":
                collect_page(src, content / "solutions" / "_index.md")
                continue
            rel = src.relative_to(solutions)
            category = rel.parts[0] if len(rel.parts) > 1 else None
            collect_page(
                src,
                content / "solutions" / src.name,
                extra_meta={"category": category} if category else None,
            )
            count += 1

    concepts = parse_concepts(root / "CONCEPTS.md")
    write_concepts(concepts, root / "site" / "data" / "concepts.toml")

    index = content / "concepts" / "_index.md"
    index.parent.mkdir(parents=True, exist_ok=True)
    index.write_text(
        '+++\ntitle = "Concepts"\ntemplate = "concepts.html"\nsort_by = "none"\n'
        'description = "Shared vocabulary — the entities essays refer to by number."\n+++\n',
        encoding="utf-8",
    )

    print(f"collected {count} page(s), {len(concepts)} concept(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()))
