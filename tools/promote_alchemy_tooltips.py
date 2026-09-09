#!/usr/bin/env python3
"""Promote MAW 4.5 alchemy potion descriptions and recipes to safe tooltip text.

In ``zzAlchemy.lua``, ``potionText[t.Item.Number]`` is assigned directly to
``t.Description`` and ``potionRecipeText[t.Item.Number]`` is appended directly
to it by ``events.BuildItemInformationBox``. Only literals inside those two
named tables are promoted.
"""

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter
from pathlib import Path

FIELDS = ["id", "category", "source", "file", "line", "patchable", "reason", "context"]
REL = "Scripts/General/zzAlchemy.lua"
TABLES = {"potionText", "potionRecipeText"}


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
    active: str | None = None

    for lineno, line in enumerate(lines, 1):
        stripped = line.strip()
        if active is None:
            for name in TABLES:
                if stripped.startswith(name + "={") or stripped.startswith(name + " = {"):
                    active = name
                    break
            continue

        if stripped == "}":
            active = None
            continue
        if stripped and not stripped.startswith("--"):
            safe.add((REL, lineno))

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
            row["reason"] = "proven_alchemy_item_tooltip"
            promoted += 1

    write_rows(occ_path, rows)
    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    report["patchability_reasons"] = dict(sorted(Counter(r.get("reason", "") for r in rows).items()))
    report["proven_alchemy_tooltip_lines"] = len(safe)
    report["proven_alchemy_tooltip_promotions"] = promoted
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({
        "table_lines": len(safe),
        "promoted_occurrences": promoted,
        "patchable_occurrences": sum(r.get("patchable") == "yes" for r in rows),
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
