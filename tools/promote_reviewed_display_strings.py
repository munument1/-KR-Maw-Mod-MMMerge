#!/usr/bin/env python3
"""Promote display strings proven during bulk Google Drive review.

This pass intentionally uses narrow file/source allow-lists for strings whose
runtime sink was manually verified in the pinned MAW 4.5 source. It avoids
turning generic internal keys into patchable text merely because the English
looks user-facing.
"""
from __future__ import annotations

import argparse
import csv
import json
from collections import Counter
from pathlib import Path

FIELDS = ["id", "category", "source", "file", "line", "patchable", "reason", "context"]

CRAFTING_NAMES = {
    "Lunar Shard", "Fire Topaz", "Amethyst Chunk", "Amber Droplet",
    "Royal Amethyst", "Gemcutter's Ruby", "Solarstone", "Erudite Crystal",
    "Erathian Sapphire", "Queen's Diamond", "Ascended Lunar Shard",
    "Ascended Topaz", "Ascended Amethyst", "Ascended Amber",
    "Ascended Purple Amethyst", "Ascended Ruby", "Ascended Solarstone",
    "Ascended Amber Droplet", "Ascended Sapphire", "Ascended Diamond",
}

ALCHEMY_ITEM_NAMES = {
    "Lunar Shard", "Fire Topaz", "Amethyst Chunk", "Amber Droplet",
    "Royal Amethyst", "Gemcutter's Ruby", "Solarstone", "Erudite Crystal",
    "Erathian Sapphire", "Queen's Diamond", "Ascended Lunar Shard",
    "Ascended Fire Topaz", "Ascended Amethyst Chunk", "Ascended Amber Droplet",
    "Ascended Royal Amethyst", "Ascended Gemcutter's Ruby", "Ascended Solarstone",
    "Ascended Erudite Crystal", "Ascended Erathian Sapphire", "Ascended Queen's Diamond",
    "Eye of Void", "Creator's Hourglass", "Pandora's Cube", "Archibald's Mirror",
    "Emerald of Power", "Pearl of Memory", "Orb of Creation", "Celestial Orb",
}

ITEM_SORTER_MESSAGES = {
    " - Corrupted bag #",
    " - Corrupted item #",
    " in bag #",
    "\n\nSummary:\n",
    "Total corrupted bags: ",
    "Total corrupted items: ",
    "WARNING!!!\n\nDURING THE AUTOSAVE, CORRUPTED ITEMS/BAGS HAVE BEEN DETECTED! Either load a previous save, where items/bags are not corrupted, or properly check your bags, and if no item/bag is missing you can keep playing (not recommended). \nDown below a list of corrupted items:\n\n",
    "WARNING!!!\n\nSAVE HAVE BEEN STOPPED DUE TO CORRUPTED ITEMS/BAGS! Either load a previous save, where items/bags are not corrupted, or properly check your bags, and if no item/bag is missing you can save again (this time no warning will be given). \nDown below a list of corrupted items:\n\n",
}

HOUSE_UI = {
    "%s (speaking with %s)",
    "Player",
    "Other players in house:",
}

EXPERIENCE_UI = {"%s: %s grants you %s exp."}

TELELOCATOR_UI = {
    "Locate item", "Locate person", "Locate monster",
    "Targets found. Realms: Attuned. Time: Attuned.\n\n",
    "\nRealms: Detached. Time: Detached.",
    "\n\nRealms: Detached. Time: Detached.",
    "%s. World: Enroth. Realm: %s. Landmark: %s. Year: %s\nTargets' status: in %s.\n",
    "%s. World: Enroth. Realm: %s. Landmark: %s. Year: %s.",
    "World: Enroth. Realm: %s. Landmark: %s. Year: %s\nTargets' status: %s, type: %s, state: %s.\n",
}

ARENA_UI = {
    "It looks like you've never tried the Endless Waves mode before. In this mode, waves of enemies will keep appearing, growing stronger over time. Everytime you clear a level, your progress is saved, and you can start from the latest checkpoint. Prepare yourself for a relentless challenge!",
    "Endless Arena",
    "Start Level ",
    "Let's get started!",
}

SERIOUS_MAW_MONSTER_NAMES = {
    "Serpent Mother",
    "Captain Sharp-Tooth",
    "Captain Strong-Scale",
    "Captain Finch",
    "Mountain Man",
    "Huge Orc",
    "Naga Empress",
}

MAW_SETTINGS_HEADERS = {
    "Buff Rework", "M&M6 Projectiles", "Homing Projectiles",
    "Damage on Friendly Units", "Loot Filter",
}

RESPEC_UI = {
    "Skill reset info",
    "I want to reset",
    "By agreeing to this, every skill you possess shall be returned to the beginning, to the level of a Novice, and all the points you've invested in these skills shall be returned to you. \n\nOnce your skill grows to the necessary level, mastery of it shall be bestowed upon you once more, should you have achieved it before.\n\nFor this service, a tribute of 1000 gold for each level you have achieved shall be required",
}


def read_rows(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_rows(path: Path, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def promote(row: dict[str, str]) -> bool:
    if row.get("patchable") != "no" or row.get("reason") != "uncertain_context":
        return False
    source = row.get("source", "")
    file = row.get("file", "")

    reason = None
    if file == "Scripts/General/zzMaw-Items.lua" and source in CRAFTING_NAMES:
        reason = "reviewed_crafting_status_name"
    elif file == "Scripts/General/zzAlchemy.lua" and source in ALCHEMY_ITEM_NAMES:
        reason = "reviewed_alchemy_item_name"
    elif file == "Scripts/General/zzMaw-Item-Sorter.lua" and source in ITEM_SORTER_MESSAGES:
        reason = "reviewed_item_corruption_message"
    elif file == "Scripts/Modules/Multiplayer/UI/House.lua" and source in HOUSE_UI:
        reason = "reviewed_multiplayer_house_ui"
    elif file == "Scripts/Modules/Multiplayer/Synchronization/Players/Experience.lua" and source in EXPERIENCE_UI:
        reason = "reviewed_multiplayer_experience_ui"
    elif file == "Scripts/Global/Quest_SavingGoobers.lua" and source in TELELOCATOR_UI:
        reason = "reviewed_telelocator_ui"
    elif file == "Scripts/Global/zzMaw_Arena.lua" and source in ARENA_UI:
        reason = "reviewed_arena_ui"
    elif file == "Scripts/General/zSERIOUSMAW.lua" and source in SERIOUS_MAW_MONSTER_NAMES:
        reason = "reviewed_monster_display_name"
    elif file == "Scripts/General/zz_Maw-initialize.lua" and source in MAW_SETTINGS_HEADERS:
        reason = "reviewed_maw_settings_header"
    elif file == "Scripts/Global/zzMAWRespec.lua" and source in RESPEC_UI:
        reason = "reviewed_respec_ui"
    elif file == "Scripts/General/zzMaw-Maps.lua" and source == "Map Level: ":
        reason = "reviewed_map_level_label"
    elif file == "Scripts/General/zzMaw-Monsters.lua" and source == "\nLevel Recommended:\n":
        reason = "reviewed_recommended_level_label"

    if not reason:
        return False
    row["patchable"] = "yes"
    row["reason"] = reason
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--occurrences", type=Path, default=Path("localization/occurrences.tsv"))
    ap.add_argument("--report", type=Path, default=Path("localization/report.json"))
    args = ap.parse_args()

    root = args.root.resolve()
    occ = root / args.occurrences
    report_path = root / args.report
    rows = read_rows(occ)
    promoted = sum(int(promote(r)) for r in rows)
    write_rows(occ, rows)

    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    report["patchability_reasons"] = dict(sorted(Counter(r.get("reason", "") for r in rows).items()))
    report["reviewed_bulk_display_promotions"] = promoted
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"promoted_occurrences": promoted}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
