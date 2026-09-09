#!/usr/bin/env python3
"""Build Korean POTION.TXT/POTNOTES.TXT display fields without touching recipes.

MAW uses the first four fields as ID/Name/Description/Effect.  Every field from
index 4 onward is treated as recipe/control data and must remain byte-logically
identical.  POTION and POTNOTES are intentionally translated independently.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path

from build_korean_zmaw_lod_stage import (
    TsvDocument, decode_field, encode_field, find_casefold, numeric_rows,
    read_source_text, write_game_text,
)

NAME_MAP = {
    "Widowsweep Berries": "위도우스위프 열매",
    "Crushed Rose Petals": "으깬 장미 꽃잎",
    "Vial of Troll Blood": "트롤의 피 약병",
    "Ruby": "루비",
    "Dragon's Eye": "드래곤의 눈",
    "Phirna Root": "피마 뿌리",
    "Meteorite Fragment": "운석 조각",
    "Harpy Feather": "하피 깃털",
    "Moonstone": "월장석",
    "Elvish Toadstool": "엘프 독버섯",
    "Poppysnaps": "양귀비 꼬투리",
    "Fae Dust": "요정 가루",
    "Sulfur": "황",
    "Garnet": "석류석",
    "Vial of Devil Ichor": "악마 체액 약병",
    "Mushroom": "버섯",
    "Obsidian": "흑요석",
    "Vial of Ooze Endoplasm": "우즈 원형질 약병",
    "Mercury": "수은",
    "Philosopher's Stone": "현자의 돌",
    "Potion Bottle": "물약병",
    "Catalyst": "촉매",
    "Cure Wounds": "상처 치료",
    "Magic Potion": "마법 물약",
    "Energy Potion": "활력 물약",
    "Cure Weakness": "약화 치료",
    "Antidote": "해독제",
    "Cure Disease": "질병 치료",
    "Hexbane": "헥스베인",
    "Cure Poison": "독 치료",
    "Lucidity": "명료함",
    "Awaken": "각성",
    "Haste": "가속",
    "Heroism": "영웅심",
    "Bless": "축복",
    "Protection": "보호",
    "Preservation": "보존",
    "Meditation": "명상",
    "Shield": "방패",
    "Regeneration": "재생",
    "Recharge Item": "아이템 재충전",
    "Stone Skin": "돌가죽",
    "Stoneskin": "돌가죽",
    "Water Breathing": "수중 호흡",
    "Harden Item": "아이템 강화",
    "Magic Protection": "마법 보호",
    "Remove Fear": "공포 제거",
    "Enchant Item": "아이템 마법 부여",
    "Remove Curse": "저주 제거",
    "Stone to Flesh": "석화 해제",
    "Cure Insanity": "광기 치료",
    "Power Boost": "힘 강화",
    "Might Boost": "힘 강화",
    "Wisdom Boost": "지혜 강화",
    "Intellect Boost": "지성 강화",
    "Resilience Boost": "회복력 강화",
    "Personality Boost": "인격 강화",
    "Lesser Element": "하급 원소",
    "Endurance Boost": "지구력 강화",
    "Swiftness": "신속",
    "Speed Boost": "속도 강화",
    "Champion's Potion": "챔피언의 물약",
    "Accuracy Boost": "정확도 강화",
    "Divine Restoration": "신성한 회복",
    "Flaming Potion": "화염 물약",
    "Divine Cure": "신성한 치유",
    "Freezing Potion": "냉기 물약",
    "Divine Magic": "신성한 마법",
    "Noxious Potion": "맹독 물약",
    "Elemental Resistance": "원소 저항",
    "Shocking Potion": "전격 물약",
    "Self Resistance": "자기 저항",
    "Swift Potion": "신속 물약",
    "Paladin's Potion": "성기사의 물약",
    "Cure Paralysis": "마비 치료",
    "Pure Power": "순수한 힘",
    "Pure Wisdom": "순수한 지혜",
    "Pure Resilience": "순수한 회복력",
    "Divine Power": "신성한 힘",
    "Greater Element": "상급 원소",
    "Luck Boost": "행운 강화",
    "Darkness": "어둠",
    "Fire Resistance": "화염 저항",
    "Divine Blessing": "신성한 축복",
    "Air Resistance": "공기 저항",
    "Twilight": "황혼",
    "Water Resistance": "물 저항",
    "Transcendence": "초월",
    "Earth Resistance": "대지 저항",
    "Dawn": "여명",
    "Mind Resistance": "정신 저항",
    "Pure Elemental Resistance": "순수 원소 저항",
    "Body Resistance": "육체 저항",
    "Pure Self Resistance": "순수 자기 저항",
    "Divine Resistance": "신성 저항",
    "Slaying Potion": "용살 물약",
    "Pure Luck": "순수한 행운",
    "Pure Speed": "순수한 속도",
    "Pure Intellect": "순수한 지성",
    "Pure Endurance": "순수한 지구력",
    "Pure Personality": "순수한 인격",
    "Pure Accuracy": "순수한 정확도",
    "Pure Might": "순수한 힘",
    "Rejuvenation": "회춘",
    "Essence of Might": "힘의 정수",
    "Essence of Intellect": "지성의 정수",
    "Essence of Personality": "인격의 정수",
    "Essence of Endurance": "지구력의 정수",
    "Essence of Accuracy": "정확도의 정수",
    "Essence of Speed": "속도의 정수",
    "Essence of Luck": "행운의 정수",
    "Potion of Doom": "파멸의 물약",
    "Divine Boost": "신성한 강화",
    "Divine Protection": "신성한 보호",
    "Divine Transcendence": "신성한 초월",
    "Potion of the Gods": "신들의 물약",
    "Pure Fire Resistance": "순수 화염 저항",
    "Pure Air Resistance": "순수 공기 저항",
    "Pure Water Resistance": "순수 물 저항",
    "Pure Earth Resistance": "순수 대지 저항",
    "Pure Mind Resistance": "순수 정신 저항",
    "Pure Body Resistance": "순수 육체 저항",
    "Protection from Magic": "마법으로부터 보호",
    "Strange potion": "이상한 물약",
    "Topaz": "토파즈",
    "Amethyst": "자수정",
    "Emerald": "에메랄드",
    "Purple Topaz": "보라색 토파즈",
    "Sunstone": "태양석",
    "Sapphire": "사파이어",
    "Diamond": "다이아몬드",
    "The Third Eye": "제3의 눈",
    "Hourglass of Time": "시간의 모래시계",
    "Control Cube": "제어 큐브",
    "Enchanted Amulet": "마법이 부여된 부적",
}

DESCRIPTION_MAP = {
    "Reagent": "시약", "Empty Bottle": "빈 물약병", "Gray Potion": "회색 물약",
    "Red Potion": "붉은색 물약", "Blue Potion": "푸른색 물약",
    "Yellow Potion": "노란색 물약", "Orange Potion": "주황색 물약",
    "Purple Potion": "보라색 물약", "Green Potion": "녹색 물약",
    "White Potion": "흰색 물약", "Black Potion": "검은색 물약",
    "Red and Orange Potion": "붉은색과 주황색 물약",
    "Red and Purple Potion": "붉은색과 보라색 물약",
    "Red and Green Potion": "붉은색과 녹색 물약",
    "Blue and Orange Potion": "푸른색과 주황색 물약",
    "Blue and Purple Potion": "푸른색과 보라색 물약",
    "Blue and Green Potion": "푸른색과 녹색 물약",
    "Yellow and Orange Potion": "노란색과 주황색 물약",
    "Yellow and Purple Potion": "노란색과 보라색 물약",
    "Yellow and Green Potion": "노란색과 녹색 물약",
    "Orange and Purple Potion": "주황색과 보라색 물약",
    "Purple and Green Potion": "보라색과 녹색 물약",
    "Orange and Green Potion": "주황색과 녹색 물약",
}

STAT_KO = {
    "Might": "힘", "Intellect": "지성", "Personality": "인격",
    "Endurance": "지구력", "Accuracy": "정확도", "Speed": "속도", "Luck": "행운",
}
RESIST_KO = {
    "Fire": "화염", "Air": "공기", "Water": "물", "Earth": "대지",
    "Mind": "정신", "Body": "육체",
}
SPELL_KO = {
    "Haste": "가속", "Heroism": "영웅심", "Bless": "축복", "Preservation": "보존",
    "Shield": "방패", "Protection": "보호", "Stoneskin": "돌가죽",
}
WEAPON_EFFECT_KO = {
    "flame": "화염", "frost": "냉기", "poison": "독", "sparks": "전격", "swiftness": "신속",
}
COLOR_KO = {"Red": "붉은색", "Blue": "푸른색", "Yellow": "노란색", "Gray": "회색"}

EXACT_EFFECT = {
    "None": "없음",
    "Boost Potion": "물약 강화",
    "Heal 10+skill HP": "생명력 10 + 연금술 기술만큼 회복",
    "Restore 10+skill MP": "주문력 10 + 연금술 기술만큼 회복",
    "Remove Weak cond": "약화 상태 제거",
    "Remove Disease 1,2,3 cond": "질병 1·2·3단계 상태 제거",
    "Remove Poison 1,2,3 cond": "독 1·2·3단계 상태 제거",
    "Remove Sleep cond": "수면 상태 제거",
    "Prevents drowning damage": "익사 피해 방지",
    "Prevent drowning damage": "익사 피해 방지",
    "Add strength to toughness of item": "아이템 견고함 +물약 위력",
    "Remove Fear cond": "공포 상태 제거",
    "Remove Curse cond": "저주 상태 제거",
    "Remove Insanity cond": "광기 상태 제거",
    "Remove Paralyze cond": "마비 상태 제거",
    "Remove all cond (not dead/stone/errad)": "모든 상태 제거(사망·석화·소멸 제외)",
    "Heal 10xskill HP": "생명력 (연금술 기술 x 10) 회복",
    "Restore 10xskill MP": "주문력 (연금술 기술 x 10) 회복",
    "Remove Stone cond": "석화 상태 제거",
    "Add 'of dragon slaying' to weapon": "무기에 용 살해 효과 부여",
    "Set Age Temp to 0": "일시적 나이 수치를 0으로 설정",
    "Permanently raises Endurance by 15 while reducing all other attributes by 2": "지구력 영구 +15, 다른 모든 능력치 영구 -2",
    "Permanently adds 1 to all seven stats, HP, SP, AC and resistances at the cost of 5 years of magical aging": "7개 능력치·생명력·주문력·방어도·저항 영구 +1, 마법적 나이 +5년",
    "Increases all Seven Statistics temporarily by (3 x Power) for (30 x Power) minutes": "7개 능력치 일시 +(위력 x 3), 지속 (위력 x 30)분",
    "Increases Fire, Air, Water, Earth, Mind and Body resistances temporarily by (3 x Power) for (30 x Power) minutes": "화염·공기·물·대지·정신·육체 저항 일시 +(위력 x 3), 지속 (위력 x 30)분",
    "Increases the character�s level by 20 for (30 x Power) minutes": "레벨 +20, 지속 (위력 x 30)분",
    "Increases the character’s level by 20 for (30 x Power) minutes": "레벨 +20, 지속 (위력 x 30)분",
    "Permanently raises all seven stats by 20 at the cost of 10 years of magical aging, single-use": "7개 능력치 영구 +20, 마법적 나이 +10년, 1회만 사용 가능",
    "Grants Protection from Magic (as a spell) for 30 minutes per point of potion strength.": "마법으로부터 보호 주문 효과, 물약 위력 1당 30분",
    "Strange potion": "이상한 물약",
}


def norm(text: str) -> str:
    return text.strip()


def translate_name(text: str) -> str | None:
    return NAME_MAP.get(norm(text))


def translate_description(text: str) -> str | None:
    return DESCRIPTION_MAP.get(norm(text))


def translate_effect(text: str) -> str | None:
    key = norm(text)
    if key in EXACT_EFFECT:
        return EXACT_EFFECT[key]
    if key in NAME_MAP:
        return NAME_MAP[key]

    m = re.fullmatch(r"\+ Bottle = (Red|Blue|Yellow|Gray) Potion \+(\d+)", key)
    if m:
        return f"+ 물약병 = {COLOR_KO[m.group(1)]} 물약 +{m.group(2)}"

    m = re.fullmatch(r"Cast (Haste|Heroism|Bless|Preservation|Shield|Protection|Stoneskin)", key)
    if m:
        return f"{SPELL_KO[m.group(1)]} 시전"

    m = re.fullmatch(r"Set (Might|Intellect|Personality|Endurance|Accuracy|Speed|Luck) Temp to 3xstrength for 30 min per strength", key)
    if m:
        return f"{STAT_KO[m.group(1)]} 일시 +(물약 위력 x 3), 지속: 위력 1당 30분"

    m = re.fullmatch(r"Set (Fire|Air|Water|Earth|Mind|Body) Resist Temp to 3xskill for 30 min per skill", key)
    if m:
        return f"{RESIST_KO[m.group(1)]} 저항 일시 +(연금술 기술 x 3), 지속: 기술 1당 30분"

    m = re.fullmatch(r"Add 'of (flame|frost|poison|sparks|swiftness)' to weapon for 30 min per strength", key)
    if m:
        return f"무기에 {WEAPON_EFFECT_KO[m.group(1)]} 효과 부여, 지속: 위력 1당 30분"

    m = re.fullmatch(r"\+50 to Perm (Luck|Speed|Intellect|Endurance|Personality|Accuracy|Might)", key)
    if m:
        return f"{STAT_KO[m.group(1)]} 영구 +50"

    m = re.fullmatch(r"Permanently raises (Might|Intellect|Personality|Accuracy|Speed|Luck) by 15 while reducing (Might|Intellect|Personality|Accuracy|Speed|Luck) by 15", key)
    if m:
        return f"{STAT_KO[m.group(1)]} 영구 +15, {STAT_KO[m.group(2)]} 영구 -15"

    m = re.fullmatch(r"Permanently adds 40 to (Fire|Air|Water|Earth|Mind|Body) Resistance, single-use", key)
    if m:
        return f"{RESIST_KO[m.group(1)]} 저항 영구 +40, 1회만 사용 가능"

    return None


def load_audit(path: Path) -> dict[int, dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return {int(row["id"]): row for row in csv.DictReader(f, delimiter="\t")}


def localize_table(path: Path, audit: dict[int, dict[str, str]], prefix: str):
    doc = TsvDocument(read_source_text(path))
    rows = numeric_rows(doc)
    errors: list[dict[str, object]] = []
    review: list[dict[str, str]] = []
    changed = 0

    for record_id, audit_row in audit.items():
        row = rows.get(record_id)
        if row is None:
            errors.append({"table": path.name, "id": record_id, "type": "missing_row"})
            continue
        if len(row.fields) < 4:
            errors.append({"table": path.name, "id": record_id, "type": "short_row"})
            continue

        original_tail = list(row.fields[4:])
        source = tuple(decode_field(row.fields[i]) for i in (1, 2, 3))
        guarded = tuple(audit_row[f"{prefix}_{field}"] for field in ("name", "description", "effect"))
        if source != guarded:
            errors.append({"table": path.name, "id": record_id, "type": "audit_source_mismatch", "stage": source, "audit": guarded})
            continue

        translated = (translate_name(source[0]), translate_description(source[1]), translate_effect(source[2]))
        for field_name, raw, ko in zip(("name", "description", "effect"), source, translated):
            if ko is None:
                errors.append({"table": path.name, "id": record_id, "type": "untranslated_display_field", "field": field_name, "source": raw})
        if any(v is None for v in translated):
            continue

        for index, ko in enumerate(translated, 1):
            assert ko is not None
            row.fields[index] = encode_field(ko)
            changed += 1

        if row.fields[4:] != original_tail:
            errors.append({"table": path.name, "id": record_id, "type": "matrix_changed"})

        review.append({
            "table": path.name, "id": str(record_id),
            "source_name": source[0], "ko_name": translated[0] or "",
            "source_description": source[1], "ko_description": translated[1] or "",
            "source_effect": source[2], "ko_effect": translated[2] or "",
        })

    return doc, changed, errors, review


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stage-dir", type=Path, default=Path("localization/zmaw_lod_ko_stage"))
    ap.add_argument("--audit", type=Path, default=Path("localization/zmaw_potion_display.tsv"))
    ap.add_argument("--review", type=Path, default=Path("localization/zmaw_potion_ko.tsv"))
    ap.add_argument("--report", type=Path, default=Path("localization/zmaw_lod_ko_report.json"))
    args = ap.parse_args()

    audit = load_audit(args.audit.resolve())
    stage_dir = args.stage_dir.resolve()
    errors: list[dict[str, object]] = []
    reviews: list[dict[str, str]] = []
    replacements: dict[str, int] = {}

    for filename, prefix in (("POTION.TXT", "potion"), ("POTNOTES.TXT", "potnotes")):
        path = find_casefold(stage_dir, filename)
        doc, count, table_errors, table_review = localize_table(path, audit, prefix)
        replacements[filename] = count
        errors.extend(table_errors)
        reviews.extend(table_review)
        if not table_errors:
            write_game_text(path, doc)

    args.review.parent.mkdir(parents=True, exist_ok=True)
    fields = ["table", "id", "source_name", "ko_name", "source_description", "ko_description", "source_effect", "ko_effect"]
    with args.review.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(reviews)

    report_path = args.report.resolve()
    report = json.loads(report_path.read_text(encoding="utf-8"))
    report["replacements"].update(replacements)
    report["total_localized_fields"] = sum(report["replacements"].values())
    report["untouched_pending_schema_review"] = ["rnditems.txt"]
    report["untouched_byte_preserved"] = ["rnditems.txt"]
    report["potion_display_localization"] = {
        "rows_per_table": len(audit),
        "columns": ["Name", "Description", "Effect"],
        "matrix_columns_preserved": True,
        "validation_errors": errors,
        "review_file": "localization/zmaw_potion_ko.tsv",
    }
    report["policy"] = (
        "MAW 4.5 gameplay fields preserved; reviewed display fields inherit Korean text; "
        "POTION/POTNOTES localize only Name/Description/Effect while preserving recipe/control matrices; "
        "rnditems remains byte-for-byte MAW 4.5 data."
    )
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({"rows": len(audit), "replacements": replacements, "total_localized_fields": report["total_localized_fields"], "errors": errors}, ensure_ascii=False, indent=2))
    return 2 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
