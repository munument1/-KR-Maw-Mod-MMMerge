#!/usr/bin/env python3
"""Promote uncertain Lua literals only when they belong to proven display APIs.

This pass is intentionally conservative. It recognizes text written directly to
MMExtension display tables/fields and Skillz.setName; internal keys and control
values remain unpatchable. For a proven display assignment, every quoted text
fragment on the assignment RHS is display text, including fragments around a
concatenated numeric value.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path

FIELDS = ["id", "category", "source", "file", "line", "patchable", "reason", "context"]


def read_rows(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_rows(path: Path, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def promote(row: dict[str, str]) -> bool:
    if row.get("patchable") != "no" or row.get("reason") != "uncertain_context":
        return False
    source = row.get("source", "")
    context = row.get("context", "")
    if not source:
        return False
    q = re.escape(source)

    # All quoted fragments on the RHS of these known player-visible display
    # assignments are display text. This also catches suffixes in expressions
    # like "Deals ... " .. value .. "% of melee damage".
    if re.search(
        rf"Game\.(?:GlobalTxt|PlaceMonTxt|SpellsTxt)\s*\[[^\]]+\](?:\.[A-Za-z_][A-Za-z0-9_]*)?\s*=.*['\"]{q}['\"]",
        context,
    ):
        row["patchable"] = "yes"
        row["reason"] = "proven_game_display_assignment"
        return True

    # Skillz.setName(id, "Name") updates the skill name shown by the UI.
    if re.search(rf"\bSkillz\.setName\s*\([^,]+,\s*['\"]{q}['\"]", context):
        row["patchable"] = "yes"
        row["reason"] = "proven_skill_display_name"
        return True

    # Item NotIdentifiedName is directly shown before identification. Allow
    # either Game.ItemsTxt[...] or a local alias such as txt[...].
    if re.search(rf"(?:Game\.ItemsTxt\s*\[[^\]]+\]|[A-Za-z_][A-Za-z0-9_]*\s*\[[^\]]+\])\.NotIdentifiedName\s*=.*['\"]{q}['\"]", context):
        row["patchable"] = "yes"
        row["reason"] = "proven_item_display_name"
        return True

    return False


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
        promoted += int(promote(row))
    write_rows(occ_path, rows)

    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    report["patchability_reasons"] = dict(sorted(Counter(r.get("reason", "") for r in rows).items()))
    report["proven_display_promotions"] = promoted
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({
        "promoted_occurrences": promoted,
        "patchable_occurrences": sum(r.get("patchable") == "yes" for r in rows),
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
