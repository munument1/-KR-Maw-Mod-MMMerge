#!/usr/bin/env python3
"""Keep MAW dungeon state independent from localized MapStats.Name values.

MAW 4.5 stores dungeon completion state under Game.MapStats[i].Name.  Korean
MapStats localizes that field, so a display-only translation would otherwise
change save keys.  Patch the generated Korean overlay to use FileName as the
stable key and lazily migrate both old English-name keys and already-localized
name keys.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path

TARGET = "Scripts/General/zzMaw-Maps.lua"
MAPSTATS = "localization/zmaw_lod_source/mapstats.txt"


def ensure_overlay_file(root: Path, output: Path, rel: str) -> Path:
    dst = output / rel
    if not dst.exists():
        src = root / rel
        if not src.exists():
            raise FileNotFoundError(rel)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
    return dst


def read_source_text(path: Path) -> str:
    data = path.read_bytes()
    try:
        return data.decode("utf-8-sig")
    except UnicodeDecodeError:
        return data.decode("cp1252")


def lua_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\r", "").replace("\n", "\\n") + '"'


def parse_mapstats(path: Path) -> dict[int, tuple[str, str]]:
    out: dict[int, tuple[str, str]] = {}
    for line in read_source_text(path).splitlines():
        parts = line.split("\t")
        if len(parts) < 3 or not parts[0].strip().isdigit():
            continue
        out[int(parts[0].strip())] = (parts[1].strip().strip('"'), parts[2].strip().strip('"'))
    return out


def replace_required(text: str, old: str, new: str, label: str, errors: list[dict]) -> tuple[str, int]:
    count = text.count(old)
    if count != 1:
        errors.append({"type": "map_key_anchor_count", "label": label, "expected": 1, "found": count})
        return text, 0
    return text.replace(old, new), 1


def build_helper(text: str, mapstats: dict[int, tuple[str, str]], errors: list[dict]) -> str:
    match = re.search(r"mapDungeons\s*=\s*\{([^}]*)\}", text)
    if not match:
        errors.append({"type": "map_dungeons_list_not_found"})
        return ""
    ids = [int(x) for x in re.findall(r"\d+", match.group(1))]
    entries = []
    missing = []
    for record_id in ids:
        row = mapstats.get(record_id)
        if not row:
            missing.append(record_id)
            continue
        english_name, file_name = row
        if file_name and english_name:
            entries.append(f"    [{lua_quote(file_name)}] = {lua_quote(english_name)},")
    if missing:
        errors.append({"type": "mapstats_rows_missing", "ids": missing})
    return """local MawDungeonLegacyEnglishNames = {
%s
}

local function MawDungeonState(stats)
    vars.dungeonCompletedList = vars.dungeonCompletedList or {}
    if not stats then return nil end
    local key = stats.FileName
    if not key or key == "" then return nil end
    local value = vars.dungeonCompletedList[key]
    if value == nil then
        local englishName = MawDungeonLegacyEnglishNames[key]
        if englishName and vars.dungeonCompletedList[englishName] ~= nil then
            value = vars.dungeonCompletedList[englishName]
            vars.dungeonCompletedList[key] = value
        elseif stats.Name and vars.dungeonCompletedList[stats.Name] ~= nil then
            value = vars.dungeonCompletedList[stats.Name]
            vars.dungeonCompletedList[key] = value
        end
    end
    return value
end

local function MawSetDungeonState(stats, value)
    vars.dungeonCompletedList = vars.dungeonCompletedList or {}
    if stats and stats.FileName and stats.FileName ~= "" then
        vars.dungeonCompletedList[stats.FileName] = value
    end
end

""" % "\n".join(entries)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--output", type=Path, default=Path("korean"))
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    root = args.root.resolve()
    output = root / args.output
    errors: list[dict] = []
    try:
        path = ensure_overlay_file(root, output, TARGET)
        mapstats_path = root / MAPSTATS
        if not mapstats_path.exists():
            raise FileNotFoundError(MAPSTATS)
        text = path.read_text(encoding="utf-8")
        if "local function MawDungeonState(stats)" not in text:
            helper = build_helper(text, parse_mapstats(mapstats_path), errors)
            marker = "function canResetDungeon(mapFileName)"
            if helper:
                text, _ = replace_required(text, marker, helper + marker, "helper_insertion", errors)

        replacements = 0
        pairs = [
            (
                "\t\t\tlocal name=Game.MapStats[i].Name\n\t\t\tif vars.dungeonCompletedList[name]==true then",
                "\t\t\tif MawDungeonState(Game.MapStats[i])==true then",
                "can_reset_key",
            ),
            (
                "\t\t\t\t\tvars.dungeonCompletedList[Game.MapStats[i].Name]=\"resetting\"",
                "\t\t\t\t\tMawSetDungeonState(Game.MapStats[i], \"resetting\")",
                "reset_set_key",
            ),
            (
                "\t\tif vars.dungeonCompletedList[Game.MapStats[mapDungeons[i]].Name] then",
                "\t\tif MawDungeonState(Game.MapStats[mapDungeons[i]]) then",
                "map_drop_key",
            ),
        ]
        normalized = text.replace("\r\n", "\n")
        for old, new, label in pairs:
            normalized, count = replace_required(normalized, old, new, label, errors)
            replacements += count
        path.write_text(normalized, encoding="utf-8", newline="")

        manifest_path = output / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
        manifest["runtime_mapstats_key_compat"] = {
            "file": TARGET,
            "stable_key": "Game.MapStats[i].FileName",
            "legacy_english_name_migration": True,
            "localized_name_migration": True,
            "replacements": replacements,
            "validation_errors": errors,
        }
        existing = [e for e in manifest.get("validation_errors", []) if e.get("type") != "map_key_anchor_count" and e.get("type") != "map_dungeons_list_not_found" and e.get("type") != "mapstats_rows_missing"]
        manifest["validation_errors"] = existing + errors
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except FileNotFoundError as exc:
        errors.append({"type": "map_key_source_missing", "file": str(exc)})

    print(json.dumps({"target": TARGET, "validation_errors": errors}, ensure_ascii=False, indent=2))
    return 2 if args.check and errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
