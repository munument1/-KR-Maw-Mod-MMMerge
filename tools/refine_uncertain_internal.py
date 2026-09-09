#!/usr/bin/env python3
"""Refine uncertain Lua occurrences that are clearly internal syntax or APIs.

This pass is deliberately one-way: it only proves more occurrences are
non-localizable. It does not promote display candidates to patchable status.
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


def refine(row: dict[str, str]) -> bool:
    if row.get("patchable") != "no" or row.get("reason") != "uncertain_context":
        return False
    source = row.get("source", "")
    context = row.get("context", "")
    if not source:
        return False
    q = re.escape(source)

    # Literal table/index keys: t["Damage"], ["Map Name"] = value, etc.
    if re.search(rf"\[\s*['\"]{q}['\"]\s*\]", context):
        row["reason"] = "internal_table_key_literal"
        return True

    # Equality/inequality comparisons are control/data values, not labels.
    if re.search(rf"(?:==|~=)\s*['\"]{q}['\"]", context) or re.search(rf"['\"]{q}['\"]\s*(?:==|~=)", context):
        row["reason"] = "comparison_control_literal"
        return True

    # Common table.find lookups use string tokens/keys.
    if re.search(rf"\btable\.find\s*\([^\n]*['\"]{q}['\"]", context):
        row["reason"] = "internal_lookup_literal"
        return True

    # Event names are dispatch keys, not player-facing labels.
    if re.search(rf"\bevents\.(?:call|Call|cocall|cocalls|AddFirst|Remove)\s*\(\s*['\"]{q}['\"]", context):
        row["reason"] = "reviewed_internal_api_literal"
        return True

    # Network/debug logging is diagnostic output rather than game localization.
    if re.search(r"(?:Multiplayer\.utils\.)?LogEvent\s*\(", context):
        row["reason"] = "reviewed_internal_api_literal"
        return True

    # Assembly patches and low-level hook snippets are executable/internal text.
    if any(token in context for token in (
        "mem.asmpatch", "mem.asmhook", "hooks.asmpatch", "hooks.asmhook",
    )):
        row["reason"] = "reviewed_internal_api_literal"
        return True

    # Map/network state keys.
    if any(token in context for token in (
        "mawmapvarsend(", "Multiplayer.broadcast_mapdata(", "SendToHost(",
    )):
        row["reason"] = "reviewed_internal_api_literal"
        return True

    # Resource identifiers: bitmap/movie/sky/picture names are not display text.
    if any(token in context for token in (
        "LoadBitmap(", "SetSkyTexture(", "evt.ShowMovie", ".Picture=", ".Picture =",
        "Monster1Pic=", "Monster2Pic=", "Monster3Pic=", "booksPic=", "booksPicGM=",
    )):
        row["reason"] = "reviewed_internal_api_literal"
        return True

    # Runtime diagnostics, parser modes, and file access strings.
    if any(token in context for token in (
        "collectgarbage(", "file:read(", "io.open(", "error(", "assert(", "print(",
    )):
        row["reason"] = "reviewed_internal_api_literal"
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

    changed = 0
    for row in rows:
        changed += int(refine(row))
    write_rows(occ_path, rows)

    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    report["patchability_reasons"] = dict(sorted(Counter(r.get("reason", "") for r in rows).items()))
    report["uncertain_internal_refinements"] = changed
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({
        "refined_occurrences": changed,
        "remaining_uncertain_occurrences": sum(r.get("reason") == "uncertain_context" for r in rows),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
