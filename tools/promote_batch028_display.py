#!/usr/bin/env python3
"""Promote display-only mastery labels reviewed in localization batch 028."""
from __future__ import annotations

import argparse
import csv
import json
from collections import Counter
from pathlib import Path

FIELDS = ["id", "category", "source", "file", "line", "patchable", "reason", "context"]
DISPLAY = {"Grandmaster", "Novice"}


def read_rows(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_rows(path: Path, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


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

    promoted = 0
    for row in rows:
        if (
            row.get("patchable") == "no"
            and row.get("reason") == "uncertain_context"
            and row.get("file") == "Scripts/General/zzMaw-Spells.lua"
            and row.get("source") in DISPLAY
            and 'local mastery={"Novice","Expert","Master","Grandmaster"}' in row.get("context", "")
        ):
            row["patchable"] = "yes"
            row["reason"] = "reviewed_batch028_mastery_display"
            promoted += 1

    write_rows(occ_path, rows)
    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    report["patchability_reasons"] = dict(sorted(Counter(r.get("reason", "") for r in rows).items()))
    report["reviewed_batch028_display_promotions"] = promoted
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"promoted_occurrences": promoted}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
