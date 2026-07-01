#!/usr/bin/env python3
"""
Step 3 - Download Materials (no LLM)

Reads _docs/research/downloads.yaml, downloads every status: pending entry into
_inspiration/, updates the yaml atomically as each completes. Per-kind dispatch
to curl / git clone / wget; per-domain rate limiting; exponential backoff on
failure; idempotent re-runs.

Usage:
    python3 scripts/download.py [--project-root PATH] [--workers N]
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import urlparse

try:
    import yaml
except ImportError:
    sys.exit("pyyaml not installed. Install: pip install pyyaml")

try:
    import fcntl
    HAS_FCNTL = True
except ImportError:
    HAS_FCNTL = False  # Windows fallback

# Per-domain seconds-between-requests. 0 = no inter-request delay.
DOMAIN_LIMITS = {
    "arxiv.org": 3.0,    # arxiv robots.txt
    "github.com": 0.0,   # gated by token, not interval
}
DEFAULT_LIMIT = 1.0

_state_lock = threading.Lock()
_last_request_time: dict[str, float] = {}
_yaml_lock = threading.Lock()


def respect_rate_limit(url: str) -> None:
    domain = urlparse(url).netloc.lower()
    limit = DOMAIN_LIMITS.get(domain, DEFAULT_LIMIT)
    if limit <= 0:
        return
    with _state_lock:
        elapsed = time.time() - _last_request_time.get(domain, 0)
        wait = limit - elapsed
        if wait > 0:
            time.sleep(wait)
        _last_request_time[domain] = time.time()


def _slug(s: str) -> str:
    return s.strip("/").replace("/", "-").replace(":", "").replace("?", "-")[:120] or "x"


def download_paper(url: str, project_root: Path) -> str:
    out_dir = project_root / "_inspiration" / "papers"
    out_dir.mkdir(parents=True, exist_ok=True)
    parsed = urlparse(url)
    if "arxiv.org" in parsed.netloc:
        arxiv_id = parsed.path.rsplit("/", 1)[-1].removesuffix(".pdf")
        pdf_url = f"https://arxiv.org/pdf/{arxiv_id}.pdf"
        path = out_dir / f"{arxiv_id}.pdf"
    else:
        pdf_url = url
        path = out_dir / f"{_slug(parsed.netloc + parsed.path)}.pdf"
    if path.exists() and path.stat().st_size > 0:
        return str(path.relative_to(project_root))
    respect_rate_limit(pdf_url)
    subprocess.run(
        ["curl", "-fsSL", "--max-time", "180", "-o", str(path), pdf_url],
        check=True, capture_output=True,
    )
    return str(path.relative_to(project_root))


def download_repo(url: str, project_root: Path) -> str:
    parsed = urlparse(url)
    parts = parsed.path.strip("/").split("/")
    if len(parts) < 2:
        raise ValueError(f"Not a repo URL: {url}")
    owner, repo = parts[0], parts[1].removesuffix(".git")
    target = project_root / "_inspiration" / owner / repo
    if target.exists():
        return str(target.relative_to(project_root))
    target.parent.mkdir(parents=True, exist_ok=True)
    respect_rate_limit(url)
    clone_url = f"https://github.com/{owner}/{repo}.git" if "github.com" in parsed.netloc else url
    subprocess.run(
        ["git", "clone", "--depth=1", clone_url, str(target)],
        check=True, capture_output=True,
    )
    return str(target.relative_to(project_root))


def download_article(url: str, project_root: Path) -> str:
    parsed = urlparse(url)
    out_dir = project_root / "_inspiration" / "articles" / _slug(parsed.netloc + parsed.path)
    out_dir.mkdir(parents=True, exist_ok=True)
    raw = out_dir / "raw.html"
    if not raw.exists() or raw.stat().st_size == 0:
        respect_rate_limit(url)
        subprocess.run(
            ["curl", "-fsSL", "--max-time", "60",
             "-A", "Mozilla/5.0 (researcher-skill)", "-o", str(raw), url],
            check=True, capture_output=True,
        )
    md = out_dir / "article.md"
    if not md.exists():
        # pandoc is best-effort; skip silently if missing
        try:
            subprocess.run(
                ["pandoc", "-f", "html", "-t", "markdown", "-o", str(md), str(raw)],
                check=True, capture_output=True,
            )
        except (FileNotFoundError, subprocess.CalledProcessError):
            pass
    return str(out_dir.relative_to(project_root))


def download_docs(url: str, project_root: Path) -> str:
    parsed = urlparse(url)
    target = project_root / "_inspiration" / "docs" / _slug(parsed.netloc)
    target.mkdir(parents=True, exist_ok=True)
    respect_rate_limit(url)
    subprocess.run(
        ["wget", "--recursive", "--level=2", "--convert-links",
         "--no-parent", "--quiet", "--timeout=60",
         "--domains", parsed.netloc,
         "--directory-prefix", str(target),
         url],
        check=True, capture_output=True,
    )
    return str(target.relative_to(project_root))


def download_other(url: str, project_root: Path) -> str:
    parsed = urlparse(url)
    out_dir = project_root / "_inspiration" / "other"
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / _slug(parsed.netloc + parsed.path)
    if target.exists() and target.stat().st_size > 0:
        return str(target.relative_to(project_root))
    respect_rate_limit(url)
    subprocess.run(
        ["curl", "-fsSL", "--max-time", "60", "-o", str(target), url],
        check=True, capture_output=True,
    )
    return str(target.relative_to(project_root))


HANDLERS = {
    "paper": download_paper,
    "repo": download_repo,
    "article": download_article,
    "docs": download_docs,
    "other": download_other,
}


def download_one(entry: dict, project_root: Path, max_retries: int = 3):
    url = entry["url"]
    kind = entry.get("kind", "other")
    handler = HANDLERS.get(kind, download_other)
    last_err = None
    for attempt in range(max_retries):
        try:
            path = handler(url, project_root)
            return (url, "done", path, None)
        except subprocess.CalledProcessError as e:
            stderr = (e.stderr or b"").decode(errors="replace")[:300]
            last_err = f"exit {e.returncode}: {stderr}"
        except Exception as e:
            last_err = f"{type(e).__name__}: {e}"
        if attempt < max_retries - 1:
            time.sleep(2 ** attempt)
    return (url, "failed", None, last_err)


def update_yaml(yaml_path: Path, url: str, status: str, path: str | None, notes: str | None) -> None:
    with _yaml_lock:
        if HAS_FCNTL:
            with open(yaml_path, "r+") as f:
                fcntl.flock(f.fileno(), fcntl.LOCK_EX)
                try:
                    f.seek(0)
                    data = yaml.safe_load(f.read()) or {"version": 1, "entries": []}
                    _apply(data, url, status, path, notes)
                    f.seek(0)
                    f.truncate()
                    yaml.safe_dump(data, f, sort_keys=False)
                finally:
                    fcntl.flock(f.fileno(), fcntl.LOCK_UN)
        else:
            data = yaml.safe_load(yaml_path.read_text()) or {"version": 1, "entries": []}
            _apply(data, url, status, path, notes)
            yaml_path.write_text(yaml.safe_dump(data, sort_keys=False))


def _apply(data: dict, url: str, status: str, path: str | None, notes: str | None) -> None:
    for entry in data.get("entries", []):
        if entry.get("url") == url:
            entry["status"] = status
            if path is not None:
                entry["path"] = path
            if notes is not None:
                entry["notes"] = notes
            return


def ensure_gitignore(project_root: Path) -> None:
    """Create _inspiration/ as a self-ignoring directory via a nested .gitignore stub.

    The nested stub contains `*` and `!.gitignore`, which ignores everything in
    the directory while keeping the directory itself (via its stub) trackable.
    Idempotent — does nothing if the stub already exists.
    """
    inspiration_dir = project_root / "_inspiration"
    inspiration_dir.mkdir(parents=True, exist_ok=True)
    nested = inspiration_dir / ".gitignore"
    if not nested.exists():
        nested.write_text("*\n!.gitignore\n")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    p.add_argument("--project-root", type=Path, default=Path.cwd())
    p.add_argument("--workers", type=int, default=5)
    p.add_argument("--yaml", type=Path, default=None,
                   help="Path to downloads.yaml (default: <project-root>/_docs/research/downloads.yaml)")
    args = p.parse_args()

    project_root = args.project_root.resolve()
    yaml_path = args.yaml or (project_root / "docs" / "research" / "downloads.yaml")
    if not yaml_path.exists():
        print(f"Not found: {yaml_path}", file=sys.stderr)
        return 2

    ensure_gitignore(project_root)

    data = yaml.safe_load(yaml_path.read_text()) or {"entries": []}
    pending = [e for e in data.get("entries", []) if e.get("status") == "pending"]
    print(f"Step 3: {len(pending)} pending, {args.workers} workers, root={project_root}")
    if not pending:
        return 0

    failed: list[tuple[str, str]] = []
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = {ex.submit(download_one, e, project_root): e for e in pending}
        for fut in as_completed(futs):
            url, status, path, err = fut.result()
            notes = f"download error: {err[:200]}" if err else None
            update_yaml(yaml_path, url, status, path, notes)
            if status == "failed":
                failed.append((url, err or "unknown"))
                print(f"  FAIL {url}: {(err or '')[:120]}", file=sys.stderr)
            else:
                print(f"  OK   {url} -> {path}")

    if failed:
        print(f"\n{len(failed)} failed. Triage manually (paywalled? deleted? auth required?).", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
