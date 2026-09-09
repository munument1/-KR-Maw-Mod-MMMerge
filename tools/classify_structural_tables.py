#!/usr/bin/env python3
"""Classify Data/Tables-only strings as structural, non-localizable data.

MAW's Data/Tables files are engine/configuration matrices: class/skill keys,
item/object identifiers, resource names, balance rows and author notes. English
text found only in those files is kept in the audit catalog but excluded from
localization. A source that also occurs in Lua is never excluded here.
"""

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path

CATALOG_FIELDS = [
    "id", "status", "category", "source", "translation", "placeholders",
    "first_file", "first_line", "occurrences", "notes",
]
OCCURRENCE_FIELDS = [
    "id", "category", "source", "file", "line", "patchable", "reason", "context",
]

NOTE = "Audited structural Data/Tables key/reference/config text; not player-facing localization."


def read_tsv(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_tsv(path: Path, fields, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--catalog", type=Path, default=Path("localization/catalog.tsv"))
    ap.add_argument("--occurrences", type=Path, default=Path("localization/occurrences.tsv"))
    ap.add_argument("--report", type=Path, default=Path("localization/report.json"))
    args = ap.parse_args()

    root = args.root.resolve()
    catalog_path = root / args.catalog
    occ_path = root / args.occurrences
    report_path = root / args.report

    catalog = read_tsv(catalog_path)
    occurrences = read_tsv(occ_path)
    files_by_source: dict[str, set[str]] = defaultdict(set)
    for row in occurrences:
        files_by_source[row.get("source", "")].add(row.get("file", ""))

    table_only_sources = {
        source
        for source, files in files_by_source.items()
        if files and all(path.startswith("Data/Tables/") for path in files)
    }

    newly_excluded = 0
    for row in catalog:
        source = row.get("source", "")
        if source not in table_only_sources:
            continue
        # Respect an explicit human decision if a future table field is proven
        # player-facing and translated manually.
        if row.get("status") == "translated" and row.get("translation"):
            continue
        if row.get("status") != "excluded":
            newly_excluded += 1
        row["status"] = "excluded"
        if not row.get("notes"):
            row["notes"] = NOTE

    structural_occurrences = 0
    for row in occurrences:
        if row.get("source", "") in table_only_sources and row.get("file", "").startswith("Data/Tables/"):
            row["patchable"] = "no"
            row["reason"] = "table_schema_structural"
            structural_occurrences += 1

    write_tsv(catalog_path, CATALOG_FIELDS, catalog)
    write_tsv(occ_path, OCCURRENCE_FIELDS, occurrences)

    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    status_counts = Counter(row.get("status", "") for row in catalog)
    reason_counts = Counter(row.get("reason", "") for row in occurrences)
    report["status"] = dict(sorted(status_counts.items()))
    report["patchability_reasons"] = dict(sorted(reason_counts.items()))
    report["structural_table_unique_sources"] = len(table_only_sources)
    report["structural_table_occurrences"] = structural_occurrences
    report["structural_table_newly_excluded"] = newly_excluded
    report["table_policy"] = "Data/Tables-only strings are audited structural keys/reference/config text; sources also used in Lua remain reviewable."
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({
        "structural_table_unique_sources": len(table_only_sources),
        "structural_table_occurrences": structural_occurrences,
        "newly_excluded": newly_excluded,
        "status": dict(sorted(status_counts.items())),
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
