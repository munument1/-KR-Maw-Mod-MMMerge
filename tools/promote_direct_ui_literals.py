#!/usr/bin/env python3
"""Promote conservative, directly proven MAW 4.5 UI text flows.

This pass only handles contexts where the player-visible sink is explicit or a
very small alias has been verified in the pinned 4.5 source. It deliberately
avoids generic table keys and debug/error strings.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path

FIELDS = ["id", "category", "source", "file", "line", "patchable", "reason", "context"]

# These local ``txt`` strings in zzMaw-Items.lua are immediately appended to
# BuildItemInformationBox(t).Description in the same short control flow.
PROVEN_ITEM_LOCAL_TEXT = {
    "\n\nItem Bonus Power: ",
    "\n\nLevel Required: ",
    "\n\nScale with player level, up to level 550.",
    "\n\nScale with player level, up to level 900.",
    "\n\nArtifact Level: ",
}


def read_rows(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_rows(path: Path, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def lua_string_values(text: str) -> set[str]:
    """Decode ordinary single/double quoted Lua strings from source context."""
    values: set[str] = set()
    i = 0
    while i < len(text):
        if text.startswith("--", i):
            # Comments only terminate the current physical line.
            nl = text.find("\n", i)
            if nl < 0:
                break
            i = nl + 1
            continue
        quote = text[i]
        if quote not in ('"', "'"):
            i += 1
            continue
        i += 1
        out: list[str] = []
        while i < len(text):
            ch = text[i]
            if ch == "\\" and i + 1 < len(text):
                nxt = text[i + 1]
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
    file = row.get("file", "")
    if not source or source not in lua_string_values(context):
        return False

    # MMExtension Message() is a player-visible message box. Require the first
    # argument to begin with a literal so lookup keys such as Message(TXT["..."])
    # are not accidentally translated.
    if re.search(r"(?<![.\w])Message\s*\(\s*['\"]", context, re.S):
        return mark(row, "proven_message_literal")

    # Explicit custom tooltip API, again only when its first argument is literal.
    if re.search(r"\bCustomUI\.DisplayTooltip\s*\(\s*['\"]", context, re.S):
        return mark(row, "proven_customui_tooltip")

    # Character/stat help text written directly to the tooltip text field.
    if file == "Scripts/General/zzMaw-Stats.lua" and re.search(r"\bt\.Text\s*=", context):
        return mark(row, "proven_stat_tooltip_text")

    # Alchemy's BuildItemInformationBox handlers write these strings directly to
    # the item description field.
    if file == "Scripts/General/zzAlchemy.lua" and re.search(r"\bt\.Description\s*=", context):
        return mark(row, "proven_alchemy_direct_description")

    # Item Notes are displayed by the engine in item information. The explicit
    # Game.ItemsTxt form is unambiguous.
    if re.search(r"Game\.ItemsTxt\s*\[[^\]]+\]\.Notes\s*=", context):
        return mark(row, "proven_item_notes")

    # In these two pinned source blocks ``local txt = Game.ItemsTxt`` is the
    # verified alias. Only display-bearing fields are accepted; Picture and
    # control data are intentionally ignored.
    if file in {"Scripts/General/zzAlchemy.lua", "Scripts/General/zzMaw-Spells.lua"} and re.search(
        r"\btxt\s*\[[^\]]+\]\.(?:Name|NotIdentifiedName|Notes|Description)\s*=", context
    ):
        return mark(row, "proven_itemtxt_alias_display")

    # In zzMaw-Spells.lua these assignments occur in blocks where
    # ``local sp = Game.SpellsTxt[id]``. Name and Description are game UI fields.
    if file == "Scripts/General/zzMaw-Spells.lua" and re.search(r"\bsp\.(?:Name|Description)\s*=", context):
        return mark(row, "proven_spelltxt_alias_display")

    if file == "Scripts/General/zzMaw-Items.lua" and source in PROVEN_ITEM_LOCAL_TEXT:
        return mark(row, "proven_item_local_description_flow")

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
    report["proven_direct_ui_promotions"] = promoted
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({
        "promoted_occurrences": promoted,
        "patchable_occurrences": sum(r.get("patchable") == "yes" for r in rows),
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
