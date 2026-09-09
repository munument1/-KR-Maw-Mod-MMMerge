#!/usr/bin/env python3
"""Promote literals written directly to MAW 4.5 monster-inspection UI fields."""

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
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def quoted_values(text: str) -> set[str]:
    vals: set[str] = set()
    i = 0
    while i < len(text):
        q = text[i]
        if q not in ('"', "'"):
            i += 1
            continue
        i += 1
        out: list[str] = []
        while i < len(text):
            ch = text[i]
            if ch == "\\" and i + 1 < len(text):
                nxt = text[i + 1]
                esc = {"n":"\n", "r":"\r", "t":"\t", "\\":"\\", '"':'"', "'":"'"}
                out.append(esc.get(nxt, "\\" + nxt))
                i += 2
                continue
            if ch == q:
                vals.add("".join(out))
                i += 1
                break
            out.append(ch)
            i += 1
    return vals


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    args = ap.parse_args()
    root = args.root.resolve()
    occ = root / "localization/occurrences.tsv"
    report_path = root / "localization/report.json"
    rows = read_rows(occ)
    promoted = 0

    for row in rows:
        if row.get("patchable") != "no" or row.get("reason") != "uncertain_context":
            continue
        src = row.get("source", "")
        ctx = row.get("context", "")
        file = row.get("file", "")
        if not src or src not in quoted_values(ctx):
            continue

        if file == "Scripts/General/zzMaw-Monsters.lua" and re.search(
            r"\bt\.(?:EffectsHeader|ArmorClass)\.Text\s*=|\bt\.Resistances\s*\[[^\]]+\]\.Text\s*=",
            ctx,
        ):
            row["patchable"] = "yes"
            row["reason"] = "proven_monster_inspection_field"
            promoted += 1
        elif file == "Scripts/General/BountyHunt.lua" and re.search(r"\bNote\.Text\s*=", ctx):
            row["patchable"] = "yes"
            row["reason"] = "proven_bounty_ui_field"
            promoted += 1

    write_rows(occ, rows)
    report = json.loads(report_path.read_text(encoding="utf-8"))
    report["patchability_reasons"] = dict(sorted(Counter(r.get("reason", "") for r in rows).items()))
    report["proven_monster_ui_promotions"] = promoted
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"promoted_occurrences": promoted}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
