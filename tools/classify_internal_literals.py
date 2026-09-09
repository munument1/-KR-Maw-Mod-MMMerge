#!/usr/bin/env python3
"""Exclude untranslated sources that occur only in proven engine/control contexts.

This keeps the audit catalog exhaustive while removing internal event keys,
comparison literals, table keys, audited structural table strings, and strings
that only occur inside Lua comments from the human translation backlog. If a
source has even one uncertain or player-facing occurrence, it remains
reviewable.
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

INTERNAL_REASONS = {
    "table_schema_structural",
    "engine_event_key_context",
    "comparison_control_literal",
    "index_key_literal",
    "answer_parser_literal",
    "internal_table_key_literal",
    "internal_lookup_literal",
    "reviewed_internal_api_literal",
    "lua_comment_literal",
}
NOTE = "Internal engine/control/comment literal only; not player-facing localization."


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
    reasons_by_source: dict[str, set[str]] = defaultdict(set)
    for row in occurrences:
        source = row.get("source", "")
        if source:
            reasons_by_source[source].add(row.get("reason", ""))

    internal_only = {
        source for source, reasons in reasons_by_source.items()
        if reasons and reasons.issubset(INTERNAL_REASONS)
    }

    newly_excluded = 0
    for row in catalog:
        source = row.get("source", "")
        if source not in internal_only:
            continue
        if row.get("status") == "translated" and row.get("translation"):
            continue
        if row.get("status") != "excluded":
            newly_excluded += 1
        row["status"] = "excluded"
        if not row.get("notes"):
            row["notes"] = NOTE

    write_tsv(catalog_path, CATALOG_FIELDS, catalog)

    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    counts = Counter(row.get("status", "") for row in catalog)
    report["status"] = dict(sorted(counts.items()))
    report["internal_only_unique_sources"] = len(internal_only)
    report["internal_only_newly_excluded"] = newly_excluded
    report["internal_literal_policy"] = "Sources occurring only in proven engine/control/comment contexts are excluded; mixed-context sources remain reviewable."
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({
        "internal_only_unique_sources": len(internal_only),
        "newly_excluded": newly_excluded,
        "status": dict(sorted(counts.items())),
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
