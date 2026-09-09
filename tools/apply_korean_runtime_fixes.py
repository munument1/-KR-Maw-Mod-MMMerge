#!/usr/bin/env python3
"""Apply Korean runtime-only localization fixes to the generated overlay.

These fixes are deliberately kept out of the MAW 4.5 source tree. They handle
strings where the visible label is also used as a canonical internal value:

* MAW setting switch labels keep their English stored values but render Korean.
* Boss affix names render Korean while boss logic continues to use canonical
  English skill tokens (prefer mapvars.bossData, with old-save name fallback).
"""
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


BOSS_DISPLAY = {
    "Summoner": "[소환]",
    "Venomous": "[맹독]",
    "Exploding": "[폭발]",
    "Thorn": "[가시]",
    "Reflecting": "[반사]",
    "Adamantite": "[아다만타이트]",
    "Swapper": "[교환]",
    "Regenerating": "[재생]",
    "Puller": "[견인]",
    "Leecher": "[흡혈]",
    "Swift": "[신속]",
    "Fixator": "[약화]",
    "Shadow": "[그림자]",
    "Plagueborn": "[역병]",
    "Broodling": "[군체하수인]",
    "Broodlord": "[군체군주]",
    "Omnipotent": "[전능]",
}


def ensure_overlay_file(root: Path, output: Path, rel: str) -> Path:
    dst = output / rel
    if not dst.exists():
        src = root / rel
        if not src.exists():
            raise FileNotFoundError(rel)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
    return dst


def replace_required(text: str, old: str, new: str, label: str, errors: list[dict], minimum: int = 1) -> tuple[str, int]:
    count = text.count(old)
    if count < minimum:
        errors.append({"type": "runtime_fix_anchor_not_found", "label": label, "expected_minimum": minimum, "found": count})
        return text, 0
    return text.replace(old, new), count


def patch_settings(root: Path, output: Path, errors: list[dict]) -> dict:
    rel = "Scripts/General/zz_Maw-initialize.lua"
    path = ensure_overlay_file(root, output, rel)
    text = path.read_text(encoding="utf-8")

    marker = "local function CustomSwitch(Screen, X, Y, Condition, Header, Parent, Field, Options)\n"
    helper = '''local function MawLocalizedSettingValue(field, value)
    local labels = {
        ON = "켜짐", OFF = "꺼짐",
        Common = "일반", ["Uncom."] = "고급", Rare = "희귀", Epic = "영웅",
        Ancient = "고대", Primordial = "태고", Legendary = "전설",
    }
    return labels[value] or tostring(value)
end

'''
    if helper not in text:
        text, inserted = replace_required(text, marker, helper + marker, "settings_helper", errors)
    else:
        inserted = 0

    replacements = 0
    pairs = [
        (
            'self.Value.Text = " " .. self.Options[currentIndex] .. " "',
            'self.Value.Text = " " .. MawLocalizedSettingValue(src.Field, self.Options[currentIndex]) .. " "',
            "settings_handler_display",
        ),
        (
            'self.Value.Text = " " .. tostring(val) .. " "',
            'self.Value.Text = " " .. MawLocalizedSettingValue(src.Field, val) .. " "',
            "settings_update_display",
        ),
        (
            'Option.Value = SimpleText(Screen, " " .. tostring(Parent[Field]) .. " ",',
            'Option.Value = SimpleText(Screen, " " .. MawLocalizedSettingValue(Field, Parent[Field]) .. " ",',
            "settings_initial_display",
        ),
    ]
    for old, new, label in pairs:
        text, count = replace_required(text, old, new, label, errors)
        replacements += count

    path.write_text(text, encoding="utf-8", newline="")
    return {"file": rel, "helper_insertions": inserted, "replacements": replacements}


def boss_helper_lua() -> str:
    display_lines = [f'    ["{key}"] = "{value}",' for key, value in BOSS_DISPLAY.items()]
    return '''MawBossSkillDisplayNames = MawBossSkillDisplayNames or {
''' + "\n".join(display_lines) + '''
}
local MawBossSkillCanonicalNames = {}
for canonical, display in pairs(MawBossSkillDisplayNames) do
    MawBossSkillCanonicalNames[display] = canonical
end

function NormalizeMawBossSkill(skill)
    return MawBossSkillCanonicalNames[skill] or skill
end

function GetMawBossSkill(mon)
    if not mon then return nil end
    local index = mon.GetIndex and mon:GetIndex() or nil
    if index and mapvars and mapvars.bossData and mapvars.bossData[index] and mapvars.bossData[index].Skills then
        return mapvars.bossData[index].Skills
    end
    local nameId = mon.NameId
    if nameId and Game.PlaceMonTxt and Game.PlaceMonTxt[nameId] then
        local visible = string.match(Game.PlaceMonTxt[nameId], "([^%s]+)")
        return NormalizeMawBossSkill(visible)
    end
    return nil
end

function CanonicalizeMawBossName(name)
    if type(name) ~= "string" then return name end
    local prefix, rest = string.match(name, "^(%S+)(.*)$")
    if not prefix then return name end
    return (NormalizeMawBossSkill(prefix) or prefix) .. (rest or "")
end

'''


def patch_boss_monsters(root: Path, output: Path, errors: list[dict]) -> dict:
    rel = "Scripts/General/zzMaw-Monsters.lua"
    path = ensure_overlay_file(root, output, rel)
    text = path.read_text(encoding="utf-8")

    marker = '--SKILLS\nSkillList={"Summoner","Venomous","Exploding","Thorn","Reflecting","Adamantite","Swapper","Regenerating","Puller","Leecher","Swift","Fixator","Shadow","Plagueborn"} --defensives\n'
    helper = boss_helper_lua()
    if "function GetMawBossSkill(mon)" not in text:
        text, inserted = replace_required(text, marker, "--SKILLS\n" + helper + 'SkillList={"Summoner","Venomous","Exploding","Thorn","Reflecting","Adamantite","Swapper","Regenerating","Puller","Leecher","Swift","Fixator","Shadow","Plagueborn"} --defensives\n', "boss_helper", errors)
    else:
        inserted = 0

    replacements = 0
    pairs = [
        (
            'local name = string.format(skill .. " " .. Game.MonstersTxt[mon.Id].Name)',
            'local name = string.format((MawBossSkillDisplayNames[skill] or skill) .. " " .. Game.MonstersTxt[mon.Id].Name)',
            "boss_display_name",
        ),
        (
            'skill = string.match(Game.PlaceMonTxt[mon.NameId], "([^%s]+)")',
            'skill = GetMawBossSkill(mon)',
            "boss_parse_mon",
        ),
        (
            'skill = string.match(Game.PlaceMonTxt[t.Monster.NameId], "([^%s]+)")',
            'skill = GetMawBossSkill(t.Monster)',
            "boss_parse_target_monster",
        ),
        (
            'local monsterSkill = string.match(Game.PlaceMonTxt[Map.Monsters[round(t.MonsterIndex)].NameId], "([^%s]+)")',
            'local monsterSkill = GetMawBossSkill(Map.Monsters[round(t.MonsterIndex)])',
            "boss_parse_scale",
        ),
        (
            'local monsterSkill = string.match(Game.PlaceMonTxt[killedMonster.NameId], "([^%s]+)")',
            'local monsterSkill = GetMawBossSkill(killedMonster)',
            "boss_parse_killed",
        ),
        (
            'local s = string.match(entry, "([^%s]+)")\n      return s',
            'local s = string.match(entry, "([^%s]+)")\n      return NormalizeMawBossSkill(s)',
            "boss_safe_fallback",
        ),
    ]
    for old, new, label in pairs:
        text, count = replace_required(text, old, new, label, errors)
        replacements += count

    path.write_text(text, encoding="utf-8", newline="")
    return {"file": rel, "helper_insertions": inserted, "replacements": replacements}


def patch_simple_boss_parsers(root: Path, output: Path, errors: list[dict]) -> list[dict]:
    specs = {
        "Scripts/General/zzMaw-Items.lua": [
            ('local skill = string.match(Game.PlaceMonTxt[mon.NameId], "([^%s]+)")', 'local skill = GetMawBossSkill(mon)', "items_broodling"),
            ('local monsterSkill = string.match(Game.PlaceMonTxt[mon.NameId], "([^%s]+)")', 'local monsterSkill = GetMawBossSkill(mon)', "items_omnipotent"),
        ],
        "Scripts/General/zzMaw-Maps.lua": [
            ('local skill = string.match(Game.PlaceMonTxt[mon.NameId], "([^%s]+)")', 'local skill = GetMawBossSkill(mon)', "maps_broodling"),
        ],
        "Scripts/General/zzAlchemy.lua": [
            ('local skill = string.match(Game.PlaceMonTxt[mon.NameId], "([^%s]+)")', 'local skill = GetMawBossSkill(mon)', "alchemy_broodling"),
        ],
        "Scripts/General/zzMaw-Stats.lua": [
            ('local skill = string.match(Game.PlaceMonTxt[mon.NameId], "([^%s]+)")', 'local skill = GetMawBossSkill(mon)', "stats_omnipotent"),
        ],
        "Scripts/General/BountyHunt.lua": [
            ('local monsterSkill = string.match(Entry.MonName, "([^%s]+)")', 'local monsterSkill = GetMawBossSkill(Hunt)', "bounty_omnipotent"),
            ('if MonName ~= Game.PlaceMonTxt[Monster.NameId] then', 'if CanonicalizeMawBossName(MonName) ~= CanonicalizeMawBossName(Game.PlaceMonTxt[Monster.NameId]) then', "bounty_old_save_name_compare"),
        ],
    }
    results = []
    for rel, pairs in specs.items():
        path = ensure_overlay_file(root, output, rel)
        text = path.read_text(encoding="utf-8")
        total = 0
        for old, new, label in pairs:
            text, count = replace_required(text, old, new, label, errors)
            total += count
        path.write_text(text, encoding="utf-8", newline="")
        results.append({"file": rel, "replacements": total})
    return results


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--output", type=Path, default=Path("korean"))
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    root = args.root.resolve()
    output = root / args.output
    manifest_path = output / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    errors: list[dict] = []
    fixes = []

    try:
        fixes.append(patch_settings(root, output, errors))
        fixes.append(patch_boss_monsters(root, output, errors))
        fixes.extend(patch_simple_boss_parsers(root, output, errors))
    except FileNotFoundError as exc:
        errors.append({"type": "runtime_fix_source_missing", "file": str(exc)})

    existing_errors = list(manifest.get("validation_errors", []))
    manifest["runtime_i18n_fixes"] = fixes
    manifest["runtime_boss_display_names"] = BOSS_DISPLAY
    manifest["validation_errors"] = existing_errors + errors
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"runtime_i18n_fixes": fixes, "validation_errors": errors}, ensure_ascii=False, indent=2))
    return 2 if args.check and errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
