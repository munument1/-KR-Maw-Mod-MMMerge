#!/usr/bin/env python3
"""Promote uncertain Lua literals only when they belong to proven display APIs.

This pass is intentionally conservative. It recognizes text written directly to
MMExtension display tables/fields and Skillz display helpers; internal keys and
control values remain unpatchable. It also follows a short, single-variable data
flow when a string variable is passed directly to a proven skill-description
sink before that variable is reassigned.

MAW 4.5's ``checktext`` helper is also a proven item-tooltip producer: every
entry in its ``bonus2txt`` table is returned from ``checktext`` and then written
to ``t.Description``. Only that named table inside that named function is
promoted; other generic tables remain untouched.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path

FIELDS = ["id", "category", "source", "file", "line", "patchable", "reason", "context"]
ASSIGN_RE = re.compile(r"^\s*(?:local\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=")


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


def display_sink_uses_var(line: str, var: str) -> bool:
    q = re.escape(var)
    if re.search(rf"\bSkillz\.setDesc\s*\([^)]*,\s*{q}\s*\)", line):
        return True
    if re.search(
        rf"Game\.SkillDes(?:Normal|Expert|Master|GM)\s*\[[^\]]+\]\s*=.*\b{q}\b",
        line,
    ):
        return True
    return False


def discover_display_variable_lines(root: Path) -> set[tuple[str, int]]:
    """Find simple string assignments consumed soon by a proven display sink.

    We only look forward 12 physical lines. If the same variable is reassigned
    first, the candidate is rejected. This deliberately misses complex dataflow
    rather than risking translation of internal/control strings.
    """
    safe: set[tuple[str, int]] = set()
    scripts = root / "Scripts"
    if not scripts.exists():
        return safe

    for path in sorted(scripts.rglob("*.lua")):
        rel = str(path.relative_to(root)).replace("\\", "/")
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for i, line in enumerate(lines):
            m = ASSIGN_RE.match(line)
            if not m or not lua_string_values(line):
                continue
            var = m.group(1)
            reassignment = re.compile(rf"^\s*(?:local\s+)?{re.escape(var)}\s*=")
            for j in range(i + 1, min(len(lines), i + 13)):
                if reassignment.match(lines[j]):
                    break
                if display_sink_uses_var(lines[j], var):
                    safe.add((rel, i + 1))
                    break
    return safe


def discover_item_enchant_description_lines(root: Path) -> set[tuple[str, int]]:
    """Return lines belonging to MAW 4.5's proven ``bonus2txt`` tooltip table.

    ``checktext(MaxCharges, bonus2, it)`` returns ``bonus2txt[bonus2]`` and its
    callers append that value to ``t.Description``. We intentionally scope this
    recognizer to the one known file/function/table instead of promoting generic
    indexed string tables.
    """
    rel = "Scripts/General/zzMaw-Items.lua"
    path = root / rel
    if not path.exists():
        return set()

    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return set()

    safe: set[tuple[str, int]] = set()
    in_checktext = False
    in_bonus_table = False

    for i, line in enumerate(lines, 1):
        stripped = line.strip()

        if not in_checktext:
            if re.match(r"function\s+checktext\s*\(", stripped):
                in_checktext = True
            continue

        if not in_bonus_table:
            if re.match(r"bonus2txt\s*=\s*\{", stripped):
                in_bonus_table = True
            elif re.match(r"(?:local\s+)?function\s+", stripped):
                break
            continue

        if stripped == "}":
            break
        if lua_string_values(line):
            safe.add((rel, i))

    return safe


def mark(row: dict[str, str], reason: str) -> bool:
    row["patchable"] = "yes"
    row["reason"] = reason
    return True


def promote(
    row: dict[str, str],
    variable_display_lines: set[tuple[str, int]],
    item_enchant_lines: set[tuple[str, int]],
) -> bool:
    if row.get("patchable") != "no" or row.get("reason") != "uncertain_context":
        return False
    source = row.get("source", "")
    context = row.get("context", "")
    if not source:
        return False

    literals = lua_string_values(context)
    if source not in literals:
        return False

    if re.search(
        r"Game\.(?:GlobalTxt|PlaceMonTxt|NPCText|ClassNames)\s*\[[^\]]+\](?:\.[A-Za-z_][A-Za-z0-9_]*)?\s*=",
        context,
    ):
        return mark(row, "proven_game_display_assignment")

    if re.search(
        r"Game\.SpellsTxt\s*\[[^\]]+\](?:\.[A-Za-z_][A-Za-z0-9_]*)?\s*=",
        context,
    ):
        return mark(row, "proven_game_display_assignment")

    # Special-enchant BonusStat is the item description text used by the
    # information box when MAW's custom checktext() does not override it.
    if re.search(r"Game\.SpcItemsTxt\s*\[[^\]]+\]\.BonusStat\s*=", context):
        return mark(row, "proven_special_item_bonus_description")

    if re.search(r"Game\.NPC\s*\[[^\]]+\]\.Name\s*=", context):
        return mark(row, "proven_npc_display_name")

    if re.search(r"\bSkillz\.setName\s*\(", context):
        return mark(row, "proven_skill_display_name")
    if re.search(r"\bSkillz\.setDesc\s*\(", context):
        return mark(row, "proven_skill_display_description")

    if re.search(
        r"Game\.SkillDes(?:Normal|Expert|Master|GM)\s*\[[^\]]+\]\s*=",
        context,
    ):
        return mark(row, "proven_skill_mastery_description")

    try:
        key = (row.get("file", ""), int(row.get("line", "0")))
    except ValueError:
        key = ("", 0)
    if key in variable_display_lines:
        return mark(row, "proven_display_variable_flow")
    if key in item_enchant_lines:
        return mark(row, "proven_item_enchant_description")

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
    variable_display_lines = discover_display_variable_lines(root)
    item_enchant_lines = discover_item_enchant_description_lines(root)

    promoted = 0
    for row in rows:
        promoted += int(promote(row, variable_display_lines, item_enchant_lines))
    write_rows(occ_path, rows)

    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    report["patchability_reasons"] = dict(sorted(Counter(r.get("reason", "") for r in rows).items()))
    report["proven_display_promotions"] = promoted
    report["proven_display_variable_lines"] = len(variable_display_lines)
    report["proven_item_enchant_description_lines"] = len(item_enchant_lines)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({
        "promoted_occurrences": promoted,
        "patchable_occurrences": sum(r.get("patchable") == "yes" for r in rows),
        "display_variable_lines": len(variable_display_lines),
        "item_enchant_description_lines": len(item_enchant_lines),
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
