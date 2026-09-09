#!/usr/bin/env python3
"""Inventory text resources extracted from MAW's Data/zMaw.T.lod.

The actual extraction is performed by mmarch in GitHub Actions. This script
keeps the generated source inventory deterministic and records enough metadata
for the localization pipeline to decide which embedded tables must be rebuilt
into the Korean overlay archive.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

ENGLISH_RE = re.compile(r"[A-Za-z]{3,}")
EXPECTED_TRANSLATION_TABLES = {
    "class.txt",
    "items.txt",
    "mapstats.txt",
    "monsters.txt",
    "placemon.txt",
    "potion.txt",
    "potnotes.txt",
    "rnditems.txt",
    "spcitems.txt",
}


def decode_text(data: bytes) -> tuple[str, str]:
    for encoding in ("utf-8-sig", "cp1252", "latin-1"):
        try:
            return data.decode(encoding), encoding
        except UnicodeDecodeError:
            continue
    return data.decode("latin-1", errors="replace"), "latin-1-replace"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source-dir", type=Path, default=Path("localization/zmaw_lod_source"))
    ap.add_argument("--manifest", type=Path, default=Path("localization/zmaw_lod_manifest.json"))
    ap.add_argument("--archive-sha", default="f250f60d68982ce6e7df105554c47323bb105f0e")
    args = ap.parse_args()

    source_dir = args.source_dir.resolve()
    manifest_path = args.manifest.resolve()
    files = []

    if not source_dir.exists():
        raise SystemExit(f"source directory does not exist: {source_dir}")

    for path in sorted(p for p in source_dir.rglob("*") if p.is_file()):
        data = path.read_bytes()
        text, encoding = decode_text(data)
        rel = path.relative_to(source_dir).as_posix()
        lines = text.splitlines()
        english_lines = sum(bool(ENGLISH_RE.search(line)) for line in lines)
        files.append({
            "name": rel,
            "name_lower": path.name.casefold(),
            "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "encoding": encoding,
            "lines": len(lines),
            "lines_with_english": english_lines,
            "expected_translation_table": path.name.casefold() in EXPECTED_TRANSLATION_TABLES,
        })

    found_names = {Path(row["name"]).name.casefold() for row in files}
    missing_expected = sorted(EXPECTED_TRANSLATION_TABLES - found_names)
    unexpected_text = sorted(found_names - EXPECTED_TRANSLATION_TABLES)

    manifest = {
        "archive": "Data/zMaw.T.lod",
        "archive_blob_sha": args.archive_sha,
        "archive_type": "mm8loclod",
        "text_resource_count": len(files),
        "expected_translation_tables_found": len(EXPECTED_TRANSLATION_TABLES) - len(missing_expected),
        "missing_expected_translation_tables": missing_expected,
        "additional_text_resources": unexpected_text,
        "files": files,
        "policy": "Generated audit source only. Korean zMaw.T.lod must be rebuilt from the pinned MAW 4.5 archive after translating reviewed embedded text resources.",
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "text_resource_count": len(files),
        "expected_found": manifest["expected_translation_tables_found"],
        "missing_expected": missing_expected,
        "additional_text_resources": unexpected_text,
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
