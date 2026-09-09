#!/usr/bin/env python3
"""Promote MAW 4.5 legendary-effect strings proven to feed item descriptions."""

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter
from pathlib import Path

FIELDS = ["id", "category", "source", "file", "line", "patchable", "reason", "context"]
REL = "Scripts/General/zzMaw-Items.lua"


def read_rows(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_rows(path: Path, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        w.writeheader(); w.writerows(rows)


def quoted_values(text: str) -> set[str]:
    vals: set[str] = set(); i = 0
    while i < len(text):
        q = text[i]
        if q not in ('"', "'"):
            i += 1; continue
        i += 1; out: list[str] = []
        while i < len(text):
            ch = text[i]
            if ch == "\\" and i + 1 < len(text):
                nxt = text[i + 1]
                esc = {"n":"\n", "r":"\r", "t":"\t", "\\":"\\", '"':'"', "'":"'"}
                out.append(esc.get(nxt, "\\" + nxt)); i += 2; continue
            if ch == q:
                vals.add("".join(out)); i += 1; break
            out.append(ch); i += 1
    return vals


def safe_lines(root: Path) -> set[int]:
    path = root / REL
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    safe: set[int] = set(); in_table = False
    for n, line in enumerate(lines, 1):
        s = line.strip()
        if not in_table:
            if s.startswith("legendaryEffects=") and "{" in s:
                in_table = True
            continue
        if s == "}":
            break
        if quoted_values(line):
            safe.add(n)
    return safe


def main() -> int:
    ap = argparse.ArgumentParser(); ap.add_argument("--root", type=Path, default=Path(".")); args = ap.parse_args()
    root = args.root.resolve(); occ = root / "localization/occurrences.tsv"; report_path = root / "localization/report.json"
    rows = read_rows(occ); table_lines = safe_lines(root); promoted = 0
    for row in rows:
        if row.get("patchable") != "no" or row.get("reason") != "uncertain_context" or row.get("file") != REL:
            continue
        src = row.get("source", ""); ctx = row.get("context", "")
        try: line = int(row.get("line", "0"))
        except ValueError: line = 0
        if src and src in quoted_values(ctx) and line in table_lines:
            row["patchable"] = "yes"; row["reason"] = "proven_legendary_item_tooltip"; promoted += 1
        elif src and src in quoted_values(ctx) and "legText=legText .." in ctx:
            row["patchable"] = "yes"; row["reason"] = "proven_legendary_item_dynamic_tooltip"; promoted += 1
    write_rows(occ, rows)
    report = json.loads(report_path.read_text(encoding="utf-8"))
    report["patchability_reasons"] = dict(sorted(Counter(r.get("reason", "") for r in rows).items()))
    report["proven_legendary_item_tooltip_lines"] = len(table_lines)
    report["proven_legendary_item_promotions"] = promoted
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"table_lines": len(table_lines), "promoted_occurrences": promoted}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__": raise SystemExit(main())
