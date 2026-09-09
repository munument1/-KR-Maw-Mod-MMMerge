#!/usr/bin/env python3
"""Export a compact review queue containing only patchable MAW strings."""

from __future__ import annotations

import argparse
import csv
from collections import Counter, defaultdict
from pathlib import Path

FIELDS = [
    "source", "translation", "status", "category", "patchable_occurrences",
    "reasons", "files", "sample_context",
]


def read_tsv(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--catalog", type=Path, default=Path("localization/catalog.tsv"))
    ap.add_argument("--occurrences", type=Path, default=Path("localization/occurrences.tsv"))
    ap.add_argument("--output", type=Path, default=Path("localization/patchable_candidates.tsv"))
    args = ap.parse_args()

    root = args.root.resolve()
    catalog = {row["source"]: row for row in read_tsv(root / args.catalog)}
    groups = defaultdict(list)
    for row in read_tsv(root / args.occurrences):
        if row.get("patchable") == "yes":
            groups[row["source"]].append(row)

    rows = []
    for source, occs in groups.items():
        cat = catalog.get(source, {})
        reasons = Counter(o.get("reason", "") for o in occs)
        files = sorted({o.get("file", "") for o in occs if o.get("file")})
        rows.append({
            "source": source,
            "translation": cat.get("translation", ""),
            "status": cat.get("status", "untranslated"),
            "category": cat.get("category", ""),
            "patchable_occurrences": len(occs),
            "reasons": "; ".join(f"{k}:{v}" for k, v in sorted(reasons.items())),
            "files": "; ".join(files),
            "sample_context": occs[0].get("context", ""),
        })

    rows.sort(key=lambda r: (r["status"] == "translated", r["category"], r["source"].casefold()))
    out = root / args.output
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    print(f"patchable unique sources: {len(rows)}")
    print(f"untranslated patchable sources: {sum(1 for r in rows if r['status'] != 'translated')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
