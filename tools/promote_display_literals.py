#!/usr/bin/env python3
"""Promote uncertain Lua literals only when they belong to proven display APIs.

This pass is intentionally conservative. It recognizes text written directly to
MMExtension display tables/fields and Skillz display helpers; internal keys and
control values remain unpatchable. For a proven display assignment, every quoted
text fragment on the assignment RHS is display text, including fragments around
a concatenated numeric value.
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


def lua_string_values(line: str) -> set[str]:
    """Decode ordinary quoted Lua strings from a one-line source context."""
    values: set[str] = set()
    i = 0
    while i < len(line):
        if line.startswith("--", i):
            break
        quote = line[i]
        if quote not in ('"', "'"):
            i += 1
            continue
        i += 1
        out: list[str] = []
        while i < len(line):
            ch = line[i]
            if ch == "\\" and i + 1 < len(line):
                nxt = line[i + 1]
                escapes = {
                    "n": "\n", "r": "\r", "t": "\t", "\\": "\\",
                    '"': '"', "'": "'",
                }
                out.append(escapes.get(nxt, "\\" + nxt))
                i += 2
                continue
            if ch == quote:
                i += 1
                values.add("".join(out))
                break
            out.append(ch)
            i += 1
        else:
            break
    return values


def mark(row: dict[str, str], reason: str) -> bool:
    row["patchable"] = "yes"
    row["reason"] = reason
    return True


def promote(row: dict[str, str]) -> bool:
    if row.get("patchable") != "no" or row.get("reason") != "uncertain_context":
        return False
    source = row.get("source", "")
    context = row.get("context", "")
    if not source:
        return False

    literals = lua_string_values(context)
    if source not in literals:
        return False

    # All quoted fragments on the RHS of known player-visible text tables are
    # display text. Decoding literals first also handles sources containing
    # escaped newlines/tabs such as "Damage\\n\\n..." correctly.
    if re.search(
        r"Game\.(?:GlobalTxt|PlaceMonTxt|NPCText|ClassNames)\s*\[[^\]]+\](?:\.[A-Za-z_][A-Za-z0-9_]*)?\s*=",
        context,
    ):
        return mark(row, "proven_game_display_assignment")

    # Spell text fields are player-facing: Name, Description and mastery text.
    if re.search(
        r"Game\.SpellsTxt\s*\[[^\]]+\](?:\.[A-Za-z_][A-Za-z0-9_]*)?\s*=",
        context,
    ):
        return mark(row, "proven_game_display_assignment")

    # NPC names are displayed in dialogue and multiplayer UI.
    if re.search(r"Game\.NPC\s*\[[^\]]+\]\.Name\s*=", context):
        return mark(row, "proven_npc_display_name")

    # Skillz.setName/Skillz.setDesc feed the skills UI directly. Because the
    # source must already be one of the decoded quoted literals on this call's
    # line, no text-value regex is needed here.
    if re.search(r"\bSkillz\.setName\s*\(", context):
        return mark(row, "proven_skill_display_name")
    if re.search(r"\bSkillz\.setDesc\s*\(", context):
        return mark(row, "proven_skill_display_description")

    # These four MMExtension tables are the text shown for Novice/Expert/Master/
    # Grandmaster skill mastery effects. Quoted fragments on their assignment
    # RHS are therefore safe player-facing localization targets.
    if re.search(
        r"Game\.SkillDes(?:Normal|Expert|Master|GM)\s*\[[^\]]+\]\s*=",
        context,
    ):
        return mark(row, "proven_skill_mastery_description")

    # Item names/descriptions are shown in inventory/tooltips. Allow either the
    # canonical Game.ItemsTxt table or a local alias for NotIdentifiedName.
    if re.search(
        r"Game\.ItemsTxt\s*\[[^\]]+\]\.(?:Name|NotIdentifiedName|Description)\s*=",
        context,
    ):
        return mark(row, "proven_item_display_text")
    if re.search(
        r"[A-Za-z_][A-Za-z0-9_]*\s*\[[^\]]+\]\.NotIdentifiedName\s*=",
        context,
    ):
        return mark(row, "proven_item_display_name")

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
