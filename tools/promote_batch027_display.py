#!/usr/bin/env python3
"""Promote display occurrences reviewed for localization batch 027."""
from __future__ import annotations

import argparse
import csv
import json
from collections import Counter
from pathlib import Path

FIELDS = ["id", "category", "source", "file", "line", "patchable", "reason", "context"]

BY_FILE = {
    "Scripts/General/zzClasses.lua": {
        "Seraphim is a divine warrior, blessed by the gods with otherworldly powers that set him apart from mortal fighters. His origins are shrouded in mystery, but it is said that he was chosen by the divine to carry out their will on the mortal plane. Some whisper that he was born from the union of a mortal and an angel, while others believe that he was created by the gods themselves. Regardless of his origins, there is no denying the power that Seraphim wields, and his presence on the battlefield is a testament to the will of the divine.\n\nProficiency in Plate, Sword, Mace, and Shield (can't dual wield)\n3 HP and 1 mana points gained per level\n\nAbilities:\n\nGods Wrath: Attacks deal extra magic damage based on Light skill (2 damage added per point in Light and Mind)\n\nHoly Strikes: Attacking will heal the most injured party member based on Body skill (2 points per point in Body and Spirit)\n\nDivine Protection: self-heals by 25% of your HP when facing lethal attacks, 5 minutes cooldown.",
        "The Elementalist is the caster with the highest mana pool, who learns spells not from the book, but from casting spells of the same elemental school. He can't learn Ascension, but his ascension level is directly tied to the sum of the school levels divided by 4. Baseline spell recovery time is 50% higher; however, when he casts Magic, he gains stacks, which increase:\n\nSpell Damage: 10% per stack\nSpell Recovery Speed: 5% per stack\nMana Cost: 1 + 7.5% of the total.\n\nAfter a few seconds without casting, the stacks decay by 50%. Dealing damage with a bow, melee weapon, or from the spellbook will break concentration, instantly resetting all stacks.\n\nSpells are cast randomly but divided into three categories: Single Target, Area of Effect, and Shotgun. Depending on the chosen quick-cast spell, the rotation is adjusted accordingly. For example, setting Fireball as a quick-cast spell will automatically prioritize AoE spells.",
        "The Shaman is a mystical warrior whose knowledge of magic enhances his martial prowess.\nYou can check following values by checking magic schools description in skills menu.\n - Each school will provide a unique bonus. There is strength in diversifying as well as specialization\n - Each point in Air will reduce damage a % pr rank reduced by level\n - Each point in Water will reduce damage by a flat number, making water better for weaker enemies, or if your defenses are already strong\n - Each point in spirit will increase healing and spell damage by a %\n - Fire will deal a % of current monster HP as fire damage, partially piercing this resistance. The bosskiller.\n - Each point in Earth will increase melee damage by a flat amount\n - Each point in Body will heal by flat amount\n - Each point in mind will restore a flat amount of mana",
        "This class combines the evil forces with brute power, making it powerful and versatile.\n Learning Frost/Blood/Unholy E/M/GM will unlock automatically new spells. However death knight can't learn spells from books.\n\nFrost:\n\nIncreases damage by 1-2-3 (at Novice, Master, Grandmaster levels) and boosts attack speed by 1% for every skill point invested.\n\nBlood:\n\nThis skill fortifies their resilience, reducing physical damage taken by 1% per skill point. Additionally, it endows their attacks with a leech effect, converting a portion of the damage dealt into health recovery.\n\nUnholy:\n\nIt amplifies damage by 1-2-3 (at Novice, Master, Grandmaster levels) and diminishes magical damage received by 1% for each skill point allocated.",
        "% at novice, expert, master and grandmaster rankings per point of skill in Dragon Ability.\nEach point in the skill increases damage and increases recovery time by 3%.",
    },
    "Scripts/General/zzMAW-Skills.lua": {
        "Increases spell damage and healing at the expense of higher mana cost and cast time.",
        "Speed|",
        "%s\t075AC|",
    },
    "Scripts/General/zzMaw-Monsters.lua": {
        "446561746820436f756e743a20",
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
            row["reason"] = "reviewed_batch027_display"
            promoted += 1

    write_rows(occ_path, rows)
    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    report["patchability_reasons"] = dict(sorted(Counter(r.get("reason", "") for r in rows).items()))
    report["reviewed_batch027_display_promotions"] = promoted
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"promoted_occurrences": promoted}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
