#!/usr/bin/env python3
"""Exclude reviewed translated sources that are not active runtime localization.

These sources were translated during earlier review passes but every MAW 4.5
occurrence is either inside a Lua block comment or is a control/lookup key.
Keeping them as ``translated`` makes the overlay builder emit misleading
"translated source has no patchable occurrence" warnings.  This pass is
intentionally explicit and fails if any reviewed source later gains a
patchable occurrence, so a future upstream change cannot silently hide real UI.
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

REVIEWED_NONRUNTIME = {
    "\nLevel Recommended:\n": "Inactive Lua block-comment code; dungeon recommendation feature disabled in MAW 4.5.",
    " will not be sorted with C": "Inactive Lua block-comment code; old inventory-lock hotkey implementation disabled.",
    "Ascended ": "Inactive Lua block-comment code; old ascended-name recolor implementation disabled.",
    "Emerald Island": "Map progression/bolster lookup key in this MAW file, not display copy.",
    "Inventory number ": "Inactive Lua block-comment code; old inventory-lock hotkey implementation disabled.",
    "Reserve a flat amount of mana\nInvisibility works on the minds of nearby creatures, making them unable to notice the party unless spoken to or attacked.  Any attack you make, regardless of whether or not it hits or misses, will break this spell. This spell can't be cast while hostile monsters are nearby.\nThis effect remains active until deactivated, attacking or lose consciousness. While active and no monster is in the nearbies, it gets casted automatically.": "Inactive Lua block-comment code; invisibility description override disabled.",
    "This skill is already as good as it will ever get": "Inactive Lua block-comment code; old shared-skill cap handler disabled.",
    "This spell is as good as it will ever get!": "Inactive Lua block-comment code; old spell-book rework disabled.",
}


def read_tsv(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_tsv(path: Path, fields, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--catalog", type=Path, default=Path("localization/catalog.tsv"))
    ap.add_argument("--occurrences", type=Path, default=Path("localization/occurrences.tsv"))
    ap.add_argument("--report", type=Path, default=Path("localization/report.json"))
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    root = args.root.resolve()
    catalog_path = root / args.catalog
    occ_path = root / args.occurrences
    report_path = root / args.report

    catalog = read_tsv(catalog_path)
    occurrences = read_tsv(occ_path)
    occ_by_source = defaultdict(list)
    for row in occurrences:
        occ_by_source[row.get("source", "")].append(row)

    errors = []
    changed = 0
    found = set()
    for row in catalog:
        source = row.get("source", "")
        if source not in REVIEWED_NONRUNTIME:
            continue
        found.add(source)
        occs = occ_by_source.get(source, [])
        patchable = [o for o in occs if o.get("patchable") == "yes"]
        if patchable:
            errors.append({
                "source": source,
                "error": "reviewed non-runtime source gained a patchable occurrence",
                "occurrences": [{"file": o.get("file"), "line": o.get("line"), "reason": o.get("reason")} for o in patchable],
            })
            continue
        if row.get("status") != "excluded":
            changed += 1
        row["status"] = "excluded"
        row["notes"] = REVIEWED_NONRUNTIME[source]

    missing = sorted(set(REVIEWED_NONRUNTIME) - found, key=str.casefold)
    for source in missing:
        errors.append({"source": source, "error": "reviewed source no longer exists in catalog"})

    write_tsv(catalog_path, CATALOG_FIELDS, catalog)

    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    report["status"] = dict(sorted(Counter(r.get("status", "") for r in catalog).items()))
    report["reviewed_nonruntime_exclusions"] = len(found)
    report["reviewed_nonruntime_validation_errors"] = errors
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    result = {
        "reviewed_sources": len(REVIEWED_NONRUNTIME),
        "found": len(found),
        "newly_excluded": changed,
        "errors": errors,
        "status": report["status"],
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 2 if args.check and errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
