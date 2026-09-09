#!/usr/bin/env python3
"""Promote display occurrences reviewed for localization batch 026."""
from __future__ import annotations

import argparse
import csv
import json
from collections import Counter
from pathlib import Path

FIELDS = ["id", "category", "source", "file", "line", "patchable", "reason", "context"]

BY_FILE = {
    "Scripts/Global/Quest_SavingGoobers.lua": {
        "Charge telelocator",
    },
    "Scripts/General/NPCFollowers.lua": {
        "Following you would be foolish",
    },
    "Scripts/General/BountyHunt.lua": {
        "monster",
    },
    "Scripts/General/zzMaw-Monsters.lua": {
        "Insane",
        "Mad.",
        "Beyond Madness - a word of warning.\n\nNo bolster here (except on starting maps).\n\nQuest timing matters:\n- Finish early: immediate power now, less XP.\n- Finish late: bigger XP later, no early power.\n\nRun-wide tracking:\n- On the character screen, you'll see a death counter shared across all saves of this run.\n- On the map, a red counter appears after you take damage and clears when no monsters are nearby.\n- Loading or leaving the game while that counter is red counts as a death.\n\nIf Insanity wasn't enough for you, you're in the right place.",
    },
    "Scripts/General/zzMAW-Skills.lua": {
        "Chance to Stun: ",
        "%\n\nPress P to enable/disable\n",
        "Cover Skill is a defensive prowess enabling a character to shield allies by intercepting incoming damage. This ability strategically positions the user as the primary target of enemy onslaughts, thereby protecting teammates who are more susceptible to damage.\n\nIf available, Expert, Master and Grandmaster is learned at skill 6-12-20.\n\nGrants 10 plus 1% chance per skill point to Cover, up to 40%, however, something might happen once at max level....\n\nCurrent cover chance: ",
        "Cover Skill is a defensive prowess enabling a character to shield allies by intercepting incoming damage. This ability strategically positions the user as the primary target of enemy onslaughts, thereby protecting teammates who are more susceptible to damage.\n\nIf available, Expert, Master and Grandmaster is learned at skill 8-20-30.\n\nGrants 10 plus 1% chance per skill point to Cover, up to 40%, however, something might happen once at max level....\n\nCurrent cover chance: ",
        "Attack|", "AC|", "Dmg%%|", "Dmg|", "%sRes", "%s Res\t000",
    },
    "Scripts/Global/zzMAWStatusMsg.lua": {
        "%s hits %s for %s points!%s",
        "%s shoots %s for %s points!%s",
        "%s inflicts %s points killing %s!%s",
        "%s hits for a total of %s points!%s",
    },
}


def read_rows(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_rows(path: Path, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


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
        if row.get("patchable") != "no" or row.get("reason") != "uncertain_context":
            continue
        allowed = BY_FILE.get(row.get("file", ""))
        if allowed and row.get("source", "") in allowed:
            row["patchable"] = "yes"
            row["reason"] = "reviewed_batch026_display"
            promoted += 1

    write_rows(occ_path, rows)
    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    report["patchability_reasons"] = dict(sorted(Counter(r.get("reason", "") for r in rows).items()))
    report["reviewed_batch026_display_promotions"] = promoted
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"promoted_occurrences": promoted}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
