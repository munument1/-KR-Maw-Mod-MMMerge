#!/usr/bin/env python3
"""Export every active untranslated MAW source as one physical TSV line.

The ordinary catalog is valid TSV and therefore may contain quoted multiline
cells.  That is useful for machines but awkward for chunked human review.  This
queue escapes backslashes, tabs and newlines so GitHub line ranges map 1:1 to
translation candidates.
"""

from __future__ import annotations

import argparse
import csv
from collections import Counter, defaultdict
from pathlib import Path

FIELDS = [
    "source_escaped",
    "category",
    "occurrences",
    "patchable_occurrences",
    "uncertain_occurrences",
    "reasons",
    "files",
    "sample_context_escaped",
]


def read_tsv(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def escape_cell(value: str) -> str:
    return (
        (value or "")
        .replace("\\", "\\\\")
        .replace("\r", "\\r")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--catalog", type=Path, default=Path("localization/catalog.tsv"))
    ap.add_argument("--occurrences", type=Path, default=Path("localization/occurrences.tsv"))
    ap.add_argument("--output", type=Path, default=Path("localization/untranslated_queue.tsv"))
    args = ap.parse_args()

    root = args.root.resolve()
    catalog_rows = read_tsv(root / args.catalog)
    occurrence_groups = defaultdict(list)
    for row in read_tsv(root / args.occurrences):
        occurrence_groups[row.get("source", "")].append(row)

    rows = []
    for cat in catalog_rows:
        if cat.get("status") != "untranslated":
            continue
        source = cat.get("source", "")
        occs = occurrence_groups.get(source, [])
        reasons = Counter(o.get("reason", "") for o in occs if o.get("reason"))
        files = sorted({o.get("file", "") for o in occs if o.get("file")})
        patchable = sum(1 for o in occs if o.get("patchable") == "yes")
        uncertain = sum(1 for o in occs if o.get("reason") == "uncertain_context")
        context = occs[0].get("context", "") if occs else cat.get("context", "")
        rows.append({
            "source_escaped": escape_cell(source),
            "category": cat.get("category", ""),
            "occurrences": len(occs),
            "patchable_occurrences": patchable,
            "uncertain_occurrences": uncertain,
            "reasons": "; ".join(f"{k}:{v}" for k, v in sorted(reasons.items())),
            "files": "; ".join(files),
            "sample_context_escaped": escape_cell(context),
        })

    rows.sort(
        key=lambda r: (
            0 if int(r["patchable_occurrences"]) else 1,
            0 if int(r["uncertain_occurrences"]) else 1,
            r["category"],
            r["source_escaped"].casefold(),
        )
    )

    out = root / args.output
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8", newline="") as f:
        f.write("\t".join(FIELDS) + "\n")
        for row in rows:
            values = [str(row.get(field, "")) for field in FIELDS]
            # All free-text fields are pre-escaped, so every record is exactly
            # one physical line and cannot inject TSV separators/newlines.
            values = [v.replace("\t", "\\t").replace("\r", "\\r").replace("\n", "\\n") for v in values]
            f.write("\t".join(values) + "\n")

    print(f"one-line untranslated queue: {len(rows)}")
    print(f"patchable untranslated: {sum(1 for r in rows if int(r['patchable_occurrences']))}")
    print(f"uncertain untranslated: {sum(1 for r in rows if int(r['uncertain_occurrences']))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
