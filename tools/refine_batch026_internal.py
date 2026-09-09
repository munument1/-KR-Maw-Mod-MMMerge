#!/usr/bin/env python3
"""Classify obvious non-localizable literals reviewed in batch 026.

This pass only moves uncertain occurrences to proven internal reasons. It never
promotes text to patchable status.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path

FIELDS = ["id", "category", "source", "file", "line", "patchable", "reason", "context"]
KNOWN_ENCODED_UI_HEX = {"446561746820436f756e743a20"}  # "Death Count: " needs dedicated localization.


def read_rows(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_rows(path: Path, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def mark(row: dict[str, str], reason: str = "reviewed_internal_api_literal") -> bool:
    row["reason"] = reason
    return True


def refine(row: dict[str, str]) -> bool:
    if row.get("patchable") != "no" or row.get("reason") != "uncertain_context":
        return False
    source = row.get("source", "")
    file = row.get("file", "")
    context = row.get("context", "")
    if not source:
        return False

    # Files whose remaining uncertain literals are diagnostics, hook metadata,
    # struct field names or debug synchronization text rather than game copy.
    if file in {
        "Scripts/General/zzBossSync.lua",
        "Scripts/Structs/After/RemoveSkillValueLimits.lua",
        "Scripts/Structs/extraEditableDescriptions.lua",
    }:
        return mark(row)

    # Logs, hooks, assembly patches, parser/runtime plumbing.
    if re.search(r"(?:^|[^A-Za-z0-9_])(?:_G\.|MF\.)?Log\s*\(", context):
        return mark(row)
    if any(token in context for token in (
        "asmpatch(", "asmhook(", "HookManager{", "SimplePlayerHook(",
        "debug.findupvalue(", "rawget(_G", "call(offsets.FindFileInLod",
        "mem.copy(", "pcall(require", "os.execute(",
    )):
        return mark(row)

    # Formula/property/schema identifiers.
    if "ProcessFormula(" in context or "GetProp(" in context or "local MonTxtDumpFields" in context:
        return mark(row, "internal_lookup_literal")
    if "Warning =" in context or "Warning = Warning" in context:
        return mark(row)

    # String prefixes used only to assemble table/quest keys.
    q = re.escape(source)
    if re.search(rf"\[\s*['\"]{q}['\"]\s*\.\.", context):
        return mark(row, "internal_table_key_literal")
    if file == "Scripts/Global/Quest_SavingGoobers.lua" and source in {"Attune", "NotAttune", "Intro"}:
        return mark(row, "internal_table_key_literal")
    if file == "Scripts/General/NPCMercenaries.lua" and source == "Merc":
        return mark(row, "internal_table_key_literal")

    # Event selectors/control tokens missed by the first conservative rules.
    if "evt." in context and source in {"Current", "Inventory", "All"}:
        return mark(row, "engine_event_key_context")
    if file == "Scripts/General/zzMaw-Maps.lua" and source == "resetting":
        return mark(row, "comparison_control_literal")
    if source == "damage" and "calcFireAuraDamage(" in context:
        return mark(row, "comparison_control_literal")

    # Monster skill lists are lookup/control data. Other occurrences of the same
    # names remain reviewable, so possible player-facing boss names are retained.
    if "SkillList={" in context:
        return mark(row, "internal_lookup_literal")

    # Resource IDs and UI element identifiers.
    if file == "Scripts/General/zzMaw-Maps.lua" and re.fullmatch(r"6Flower\d+", source):
        return mark(row)
    if re.search(r"\b(?:Icon|IconUp|IconDown|IUpSrc|IDwSrc|Key)\s*=", context):
        return mark(row)
    if source.startswith("SG_") and re.search(r"\bName\s*=", context):
        return mark(row)

    # Save/network/file paths and protocol tokens.
    if any(token in context for token in (
        "AutosaveFilePath", "DataFilePath", "SAVE_VERSION_TOKEN", "local folder =",
        "DataType =", "sender =", "FindFileInLod",
    )):
        return mark(row)
    if "__find_cond_idx" in context:
        return mark(row, "internal_lookup_literal")

    # Pseudo-spawn diagnostics are developer failure reports.
    if file == "Scripts/General/pseudoSpawnpoint.lua" and ("failReasons" in context or "reason:" in context):
        return mark(row)

    # Adaptive monster parser tokens, not visible labels.
    if file == "Scripts/General/AdaptiveMonstersStats.lua" and (
        "string.find(Words" in context or re.search(r"\bstr\s*=\s*['\"]return", context)
    ):
        return mark(row)

    # Long hex literals decoded by _H are implementation strings. Keep the one
    # known encoded player-facing label pending a dedicated encoded-text pass.
    if re.fullmatch(r"[0-9A-Fa-f]{8,}", source) and source not in KNOWN_ENCODED_UI_HEX:
        if "_H" in context:
            return mark(row)
    if re.fullmatch(r"\[0x[0-9A-Fa-f]+\]", source):
        return mark(row)

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
    changed = sum(int(refine(r)) for r in rows)
    write_rows(occ_path, rows)

    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    report["patchability_reasons"] = dict(sorted(Counter(r.get("reason", "") for r in rows).items()))
    report["reviewed_batch026_internal_refinements"] = changed
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "refined_occurrences": changed,
        "remaining_uncertain_occurrences": sum(r.get("reason") == "uncertain_context" for r in rows),
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
