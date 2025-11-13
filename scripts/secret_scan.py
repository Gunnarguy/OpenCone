#!/usr/bin/env python3
"""Simple repository secret scanner tuned for OpenCone release gate.

Scans text files for high-risk token patterns (OpenAI keys, Pinecone keys, and
Bearer tokens). Exits with a non-zero status if any matches are discovered so it
can run in CI or as a preflight step before submission.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Iterable, Tuple

# Directories that are safe to skip during scans. Extend this list if additional
# vendor bundles or build artifacts are added to the repository.
_DEFAULT_IGNORES = {
    ".git",
    ".github",
    "DerivedData",
    "build",
    "node_modules",
    "Pods",
    "scripts/__pycache__",
}

# Regular expressions for common token formats we never want to ship in source.
_PATTERNS: Tuple[Tuple[str, re.Pattern[str]], ...] = (
    ("OpenAI secret", re.compile(r"sk-[A-Za-z0-9]{20,}")),
    ("OpenAI project token", re.compile(r"proj-[A-Za-z0-9]{20,}")),
    ("Pinecone server key", re.compile(r"pcsk_[A-Za-z0-9]{20,}")),
    ("Generic bearer token", re.compile(r"bearer\s+[A-Za-z0-9-_]{20,}", re.IGNORECASE)),
)


def iter_candidate_files(root: Path, extra_ignores: Iterable[str]) -> Iterable[Path]:
    """Yield text-ish files from the repository, skipping ignored directories."""

    ignore_prefixes = set(_DEFAULT_IGNORES)
    ignore_prefixes.update(extra_ignores)

    for path in root.rglob("*"):
        if not path.is_file():
            continue

        relative = path.relative_to(root)
        if any(part in ignore_prefixes for part in relative.parts):
            continue

        # Skip large binaries to keep the scan lightweight; textual secrets
        # should not reside in >2 MB assets.
        try:
            if path.stat().st_size > 2 * 1024 * 1024:
                continue
        except OSError:
            continue

        yield path


def scan_file(path: Path) -> Iterable[Tuple[str, str]]:
    """Return (pattern_name, line) matches for the provided file."""

    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []

    matches = []
    for label, regex in _PATTERNS:
        for match in regex.finditer(text):
            snippet = match.group(0)
            matches.append((label, snippet))
    return matches


def main() -> int:
    parser = argparse.ArgumentParser(description="Scan repository for embedded secrets.")
    parser.add_argument(
        "path",
        nargs="?",
        default=".",
        help="Root directory to scan. Defaults to current working directory.",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help="Relative directory name to ignore (can be provided multiple times).",
    )
    args = parser.parse_args()

    root = Path(args.path).resolve()
    if not root.exists():
        print(f"error: path '{root}' does not exist", file=sys.stderr)
        return 2

    findings = []
    for candidate in iter_candidate_files(root, args.exclude):
        for label, snippet in scan_file(candidate):
            findings.append((candidate, label, snippet))

    if findings:
        print("Detected potential secrets:", file=sys.stderr)
        for candidate, label, snippet in findings:
            print(f"  {candidate}: {label} -> {snippet[:60]}", file=sys.stderr)
        print("\nRemove these values or move them to secure storage before proceeding.", file=sys.stderr)
        return 1

    print("✅ No secret patterns detected.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
