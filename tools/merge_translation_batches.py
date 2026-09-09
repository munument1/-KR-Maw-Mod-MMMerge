#!/usr/bin/env python3
"""Merge the base MAW Korean translation TSV with reviewable batch files."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

FIELDS = ["source", "translation", "status", "notes"]


def read_tsv(path: Path):
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--base", type=Path, default=Path("localization/translations.tsv"))
    ap.add_argument("--batches", type=Path, default=Path("localization/batches"))
    ap.add_argument("--output", type=Path, default=Path("localization/all_translations.tsv"))
    args = ap.parse_args()

    root = args.root.resolve()
    inputs = [root / args.base]
    batch_dir = root / args.batches
    if batch_dir.exists():
        inputs.extend(sorted(batch_dir.glob("*.tsv")))

    merged: dict[str, dict[str, str]] = {}
    origin: dict[str, str] = {}
    for path in inputs:
        for row in read_tsv(path):
            source = row.get("source", "")
            if not source:
                continue
            normalized = {field: row.get(field, "") for field in FIELDS}
            if source in merged:
                old = merged[source]
                if old.get("translation") != normalized.get("translation") or old.get("status") != normalized.get("status"):
                    raise SystemExit(
                        f"Conflicting translation for {source!r}: {origin[source]} vs {path.relative_to(root)}"
                    )
                # Keep the newer note when the translation decision is identical.
                if normalized.get("notes"):
                    old["notes"] = normalized["notes"]
                continue
            merged[source] = normalized
            origin[source] = str(path.relative_to(root))

    out = root / args.output
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        for source in sorted(merged, key=str.casefold):
            w.writerow(merged[source])

    print(f"Merged {len(merged)} translation decisions from {len(inputs)} file(s) into {out.relative_to(root)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
