#!/usr/bin/env python3
"""Export player-facing columns from MAW POTION/POTNOTES tables.

The first four columns are ID, Name, Description and Effect. All later columns
are recipe/control matrix data and are deliberately excluded from localization.
POTION.TXT and POTNOTES.TXT intentionally differ for many rows, so both sets of
display fields are exported side by side for independent review.
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

from build_korean_zmaw_lod_stage import TsvDocument, decode_field, find_casefold, read_source_text


def display_rows(path: Path) -> dict[int, tuple[str, str, str]]:
    doc = TsvDocument(read_source_text(path))
    out: dict[int, tuple[str, str, str]] = {}
    for row in doc.rows:
        if len(row.fields) < 4:
            continue
        raw_id = decode_field(row.fields[0]).strip()
        if not raw_id.isdigit():
            continue
        out[int(raw_id)] = tuple(decode_field(row.fields[i]) for i in (1, 2, 3))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source-dir", type=Path, default=Path("localization/zmaw_lod_source"))
    ap.add_argument("--output", type=Path, default=Path("localization/zmaw_potion_display.tsv"))
    ap.add_argument("--report", type=Path, default=Path("localization/zmaw_potion_display_report.json"))
    args = ap.parse_args()

    source_dir = args.source_dir.resolve()
    potion = display_rows(find_casefold(source_dir, "POTION.TXT"))
    notes = display_rows(find_casefold(source_dir, "POTNOTES.TXT"))

    all_ids = sorted(set(potion) | set(notes))
    mismatches = []
    rows = []
    for record_id in all_ids:
        p = potion.get(record_id) or ("", "", "")
        n = notes.get(record_id) or ("", "", "")
        same = p == n
        if not same:
            mismatches.append(record_id)
        rows.append({
            "id": record_id,
            "potion_name": p[0],
            "potion_description": p[1],
            "potion_effect": p[2],
            "potnotes_name": n[0],
            "potnotes_description": n[1],
            "potnotes_effect": n[2],
            "display_fields_match": "yes" if same else "no",
        })

    args.output.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "id",
        "potion_name", "potion_description", "potion_effect",
        "potnotes_name", "potnotes_description", "potnotes_effect",
        "display_fields_match",
    ]
    with args.output.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    report = {
        "potion_rows": len(potion),
        "potnotes_rows": len(notes),
        "union_rows": len(all_ids),
        "display_field_mismatches": len(mismatches),
        "mismatch_ids": mismatches,
        "policy": "POTION and POTNOTES display fields are reviewed independently; recipe/control matrix columns remain excluded from localization.",
    }
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
