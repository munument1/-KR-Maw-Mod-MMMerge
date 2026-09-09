#!/usr/bin/env python3
"""Promote MAW 4.5 map-item names, affix text, and help text.

The map item (item 290) builds ``mapAffixes`` inside
``events.BuildItemInformationBox`` and appends selected entries directly to
``t.Description``. The same block writes the displayed map name and help text.
Only those lines in that function are promoted.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path

FIELDS = ["id", "category", "source", "file", "line", "patchable", "reason", "context"]
REL = "Scripts/General/zzMaw-Maps.lua"


def read_rows(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_rows(path: Path, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def discover_lines(root: Path) -> set[tuple[str, int]]:
    path = root / REL
    if not path.exists():
        return set()
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    safe: set[tuple[str, int]] = set()
    in_box = False
    in_affixes = False

    for lineno, line in enumerate(lines, 1):
        stripped = line.strip()
        if not in_box:
            if re.match(r"function\s+events\.BuildItemInformationBox\s*\(", stripped):
                in_box = True
            continue

        if not in_affixes and re.match(r"mapAffixes\s*=\s*\{", stripped):
            in_affixes = True
            continue

        if in_affixes:
            if stripped == "}":
                in_affixes = False
                continue
            if stripped and not stripped.startswith("--"):
                safe.add((REL, lineno))
            continue

        # The map item block writes these player-facing fields directly.
        if re.search(r"\bt\.(?:Name|Description)\s*=", line):
            safe.add((REL, lineno))

        # Stop at the next top-level function after the information-box handler.
        if re.match(r"function\s+", stripped) and "BuildItemInformationBox" not in stripped:
            break

    return safe


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--occurrences", type=Path, default=Path("localization/occurrences.tsv"))
    ap.add_argument("--report", type=Path, default=Path("localization/report.json"))
    args = ap.parse_args()

    root = args.root.resolve()
    occ_path = root / args.occurrences
    report_path = root / args.report
    rows = read_rows(occ_path)
    safe = discover_lines(root)

    promoted = 0
    for row in rows:
        if row.get("patchable") != "no" or row.get("reason") != "uncertain_context":
            continue
        try:
            key = (row.get("file", ""), int(row.get("line", "0")))
        except ValueError:
            continue
        if key in safe:
            row["patchable"] = "yes"
            row["reason"] = "proven_map_item_tooltip"
            promoted += 1

    write_rows(occ_path, rows)
    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    report["patchability_reasons"] = dict(sorted(Counter(r.get("reason", "") for r in rows).items()))
    report["proven_map_item_tooltip_lines"] = len(safe)
    report["proven_map_item_tooltip_promotions"] = promoted
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({
        "safe_lines": len(safe),
        "promoted_occurrences": promoted,
        "patchable_occurrences": sum(r.get("patchable") == "yes" for r in rows),
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
