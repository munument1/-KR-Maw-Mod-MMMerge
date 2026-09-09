#!/usr/bin/env python3
"""Export the player-facing columns from MAW POTION/POTNOTES tables.

The first four columns are ID, Name, Description and Effect.  All later
columns are recipe/control matrix data and are deliberately excluded from the
localization queue.  The exporter also verifies that POTION.TXT and
POTNOTES.TXT agree on those display fields before we translate them.
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
        p = potion.get(record_id)
        n = notes.get(record_id)
        same = p == n
        if not same:
            mismatches.append({"id": record_id, "potion": p, "potnotes": n})
        chosen = p or n or ("", "", "")
        rows.append({
            "id": record_id,
            "name": chosen[0],
            "description": chosen[1],
            "effect": chosen[2],
            "tables_match": "yes" if same else "no",
        })

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["id", "name", "description", "effect", "tables_match"],
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)

    report = {
        "potion_rows": len(potion),
        "potnotes_rows": len(notes),
        "union_rows": len(all_ids),
        "display_field_mismatches": len(mismatches),
        "mismatches": mismatches,
        "policy": "Only ID/Name/Description/Effect are audited here; recipe/control matrix columns are excluded from localization.",
    }
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 2 if mismatches else 0


if __name__ == "__main__":
    raise SystemExit(main())
