#!/usr/bin/env python3
"""Build a Koreanized MAW 4.5 zMaw.T.lod staging directory.

The source of truth for gameplay data is the extracted MAW 4.5 zMaw.T.lod.
Only reviewed display fields are inherited from the pinned Korean MMMerge
runtime tables.  Every other field stays on the MAW 4.5 value so loading this
archive after the base Korean MMMerge patch cannot roll MAW balance data back.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

MMMERGE_REPO = "munument1/-KR-MMMerge"
MMMERGE_COMMIT = "01b13c9f3c3d4db33ee650ef489fbbdf58765d7e"
RAW_BASE = f"https://raw.githubusercontent.com/{MMMERGE_REPO}/{MMMERGE_COMMIT}/Data/Text%20localization"

KO_FILES = {
    "items": "KO_ItemsTxt.txt",
    "monsters": "KO_Monsters.txt",
    "classes": "KO_ClassNames.txt",
    "class_desc": "KO_ClassDescriptions.txt",
    "mapstats": "KO_MapStats.txt",
    "placemon": "KO_PlaceMonTxt.txt",
    "spc_names": "KO_SpcItemsTxtNames.txt",
    "spc_stats": "KO_SpcItemsTxtStats.txt",
}
EXPECTED = [
    "ITEMS.txt",
    "MONSTERS.txt",
    "POTION.TXT",
    "POTNOTES.TXT",
    "Placemon.txt",
    "SPCITEMS.TXT",
    "class.txt",
    "mapstats.txt",
    "rnditems.txt",
]

DBCS_RE = re.compile(br"[\xA1-\xAC\xB0-\xC8\xCA-\xFD][\xA0-\xFF](?!\x07)")


def encode_dbcs_special(data: bytes) -> bytes:
    data = DBCS_RE.sub(lambda m: b"\x0e\x20\x0e" + m.group(0) + b"\x07\x0f", data)
    return data.replace(b"\x0f\x0e", b"")


def decode_dbcs_special(data: bytes) -> bytes:
    data = re.sub(br"\x20\x0e(..)\x07", lambda m: m.group(1), data)
    return re.sub(br"\x0e([^\x0f]+)\x0f", lambda m: m.group(1), data)


def encode_mixed_text(text: str) -> bytes:
    output = bytearray()
    for index, char in enumerate(text):
        try:
            output.extend(char.encode("cp1252"))
            continue
        except UnicodeEncodeError:
            pass
        try:
            output.extend(char.encode("cp949"))
        except UnicodeEncodeError as exc:
            raise UnicodeEncodeError(
                "cp949/cp1252", text, index, index + 1,
                f"character {char!r} is unavailable in both target encodings",
            ) from exc
    return bytes(output)


def decode_field(raw: str) -> str:
    if len(raw) >= 2 and raw.startswith('"') and raw.endswith('"'):
        return raw[1:-1].replace('""', '"')
    return raw


def encode_field(value: str) -> str:
    if any(ch in value for ch in ("\t", "\r", "\n", '"')):
        return '"' + value.replace('"', '""') + '"'
    return value


@dataclass
class Row:
    fields: list[str]
    newline: str


class TsvDocument:
    """Tolerant TSV parser preserving untouched field spelling and newlines."""

    def __init__(self, text: str):
        self.rows = self._parse(text)

    @staticmethod
    def _parse(text: str) -> list[Row]:
        rows: list[Row] = []
        fields: list[str] = []
        start = 0
        i = 0
        quoted = bool(text) and text[0] == '"'
        if quoted:
            i = 1
        while i < len(text):
            ch = text[i]
            if quoted:
                if ch == '"':
                    if i + 1 < len(text) and text[i + 1] == '"':
                        i += 2
                        continue
                    quoted = False
                i += 1
                continue
            if ch == "\t":
                fields.append(text[start:i])
                i += 1
                start = i
                quoted = i < len(text) and text[i] == '"'
                if quoted:
                    i += 1
                continue
            if ch in "\r\n":
                fields.append(text[start:i])
                if ch == "\r" and i + 1 < len(text) and text[i + 1] == "\n":
                    newline = "\r\n"
                    i += 2
                else:
                    newline = ch
                    i += 1
                rows.append(Row(fields, newline))
                fields = []
                start = i
                quoted = i < len(text) and text[i] == '"'
                if quoted:
                    i += 1
                continue
            i += 1
        if start < len(text) or fields:
            fields.append(text[start:])
            rows.append(Row(fields, ""))
        return rows

    def render(self) -> str:
        return "".join("\t".join(row.fields) + row.newline for row in self.rows)


def read_source_text(path: Path) -> str:
    data = path.read_bytes()
    try:
        return data.decode("utf-8-sig")
    except UnicodeDecodeError:
        return data.decode("cp1252")


def find_casefold(folder: Path, name: str) -> Path:
    wanted = name.casefold()
    for candidate in folder.iterdir():
        if candidate.name.casefold() == wanted:
            return candidate
    raise FileNotFoundError(name)


def numeric_rows(doc: TsvDocument, column: int = 0) -> dict[int, Row]:
    out: dict[int, Row] = {}
    for row in doc.rows:
        if len(row.fields) <= column:
            continue
        value = decode_field(row.fields[column]).strip()
        if value.isdigit():
            out[int(value)] = row
    return out


def download_text(name: str) -> str:
    url = f"{RAW_BASE}/{name}"
    req = urllib.request.Request(url, headers={"User-Agent": "MAW-MMMerge-Korean-localization/1.0"})
    with urllib.request.urlopen(req, timeout=60) as response:
        return response.read().decode("utf-8-sig")


def parse_runtime_overlay(text: str) -> dict[tuple[int, str], str]:
    records: dict[tuple[int, str], str] = {}
    current: tuple[int, str] | None = None
    for line_no, line in enumerate(text.splitlines(), 1):
        parts = line.split("\t", 3)
        if len(parts) >= 4 and parts[1].strip().isdigit():
            key = (int(parts[1].strip()), parts[2].strip())
            records[key] = decode_field(parts[3])
            current = key
        elif current is not None:
            records[current] += "\n" + line
        elif line_no != 1 and line.strip():
            raise ValueError(f"overlay line {line_no}: orphan continuation")
    return records


def parse_items_overlay(text: str) -> dict[int, tuple[str, str, str]]:
    doc = TsvDocument(text)
    result: dict[int, tuple[str, str, str]] = {}
    for row in doc.rows[1:]:
        if len(row.fields) < 4:
            continue
        raw_id = decode_field(row.fields[0]).strip()
        if not raw_id.isdigit():
            continue
        result[int(raw_id)] = tuple(decode_field(row.fields[i]) for i in (1, 2, 3))
    return result


def set_direct(doc: TsvDocument, record_id: int, column: int, value: str) -> bool:
    if not value:
        return False
    row = numeric_rows(doc).get(record_id)
    if row is None:
        return False
    if len(row.fields) <= column:
        raise ValueError(f"row {record_id} has no column {column}")
    row.fields[column] = encode_field(value)
    return True


def apply_items(doc: TsvDocument, ko_text: str) -> int:
    changed = 0
    rows = numeric_rows(doc)
    for record_id, (name, unidentified, notes) in parse_items_overlay(ko_text).items():
        row = rows.get(record_id)
        if row is None:
            continue
        for column, value in ((2, name), (10, unidentified), (16, notes)):
            if value and len(row.fields) > column:
                row.fields[column] = encode_field(value)
                changed += 1
    return changed


def apply_direct_overlay(doc: TsvDocument, overlay_text: str, field: str, column: int) -> int:
    changed = 0
    rows = numeric_rows(doc)
    for (record_id, source_field), value in parse_runtime_overlay(overlay_text).items():
        if source_field != field or not value:
            continue
        row = rows.get(record_id)
        if row is None:
            continue
        if len(row.fields) <= column:
            raise ValueError(f"row {record_id} has no column {column}")
        row.fields[column] = encode_field(value)
        changed += 1
    return changed


def apply_direct_blank_field_overlay(doc: TsvDocument, overlay_text: str, column: int) -> int:
    changed = 0
    rows = numeric_rows(doc)
    for (record_id, _field), value in parse_runtime_overlay(overlay_text).items():
        if not value:
            continue
        row = rows.get(record_id)
        if row is None:
            continue
        if len(row.fields) <= column:
            raise ValueError(f"row {record_id} has no column {column}")
        row.fields[column] = encode_field(value)
        changed += 1
    return changed


def apply_by_order(doc: TsvDocument, overlay_text: str, column: int,
                   eligible: Callable[[Row, int], bool], field: str | None = None) -> int:
    rows = [row for idx, row in enumerate(doc.rows) if eligible(row, idx)]
    changed = 0
    for (record_id, source_field), value in parse_runtime_overlay(overlay_text).items():
        if field is not None and source_field != field:
            continue
        if not value or record_id < 0 or record_id >= len(rows):
            continue
        row = rows[record_id]
        if len(row.fields) <= column:
            raise ValueError(f"row-order {record_id} has no column {column}")
        row.fields[column] = encode_field(value)
        changed += 1
    return changed


def write_game_text(path: Path, doc: TsvDocument) -> None:
    plain = encode_mixed_text(doc.render())
    encoded = encode_dbcs_special(plain)
    if decode_dbcs_special(encoded) != plain:
        raise ValueError(f"DBCS round-trip failed for {path.name}")
    path.write_bytes(encoded)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source-dir", type=Path, default=Path("localization/zmaw_lod_source"))
    ap.add_argument("--stage-dir", type=Path, default=Path("localization/zmaw_lod_ko_stage"))
    ap.add_argument("--report", type=Path, default=Path("localization/zmaw_lod_ko_report.json"))
    args = ap.parse_args()

    source_dir = args.source_dir.resolve()
    stage_dir = args.stage_dir.resolve()
    report_path = args.report.resolve()

    missing = [name for name in EXPECTED if not any(p.name.casefold() == name.casefold() for p in source_dir.iterdir())]
    if missing:
        raise SystemExit(f"missing extracted MAW tables: {missing}")

    ko = {key: download_text(name) for key, name in KO_FILES.items()}
    if stage_dir.exists():
        shutil.rmtree(stage_dir)
    stage_dir.mkdir(parents=True)

    docs: dict[str, TsvDocument] = {}
    for expected in EXPECTED:
        src = find_casefold(source_dir, expected)
        docs[expected] = TsvDocument(read_source_text(src))

    replacements: dict[str, int] = {}
    replacements["ITEMS.txt"] = apply_items(docs["ITEMS.txt"], ko["items"])
    replacements["MONSTERS.txt"] = apply_direct_overlay(docs["MONSTERS.txt"], ko["monsters"], "Name", 1)
    replacements["Placemon.txt"] = apply_direct_blank_field_overlay(docs["Placemon.txt"], ko["placemon"], 1)
    replacements["mapstats.txt"] = apply_direct_overlay(docs["mapstats.txt"], ko["mapstats"], "Name", 1)

    class_row = lambda row, idx: idx >= 1 and len(row.fields) >= 2 and bool(decode_field(row.fields[0]).strip())
    replacements["class.txt"] = apply_by_order(docs["class.txt"], ko["classes"], 0, class_row)
    replacements["class.txt"] += apply_by_order(docs["class.txt"], ko["class_desc"], 1, class_row)

    spc_row = lambda row, idx: idx >= 4 and len(row.fields) >= 2 and bool(decode_field(row.fields[0]).strip())
    replacements["SPCITEMS.TXT"] = apply_by_order(docs["SPCITEMS.TXT"], ko["spc_stats"], 0, spc_row, "BonusStat")
    replacements["SPCITEMS.TXT"] += apply_by_order(docs["SPCITEMS.TXT"], ko["spc_names"], 1, spc_row, "NameAdd")

    # These MAW tables are repacked to restore MAW 4.5 gameplay data after the
    # base Korean LOD, but are not text-mutated until their display semantics
    # have been reviewed separately.
    for untouched in ("POTION.TXT", "POTNOTES.TXT", "rnditems.txt"):
        replacements[untouched] = 0

    for expected in EXPECTED:
        out = stage_dir / expected
        write_game_text(out, docs[expected])

    report = {
        "base": "MAW MMMerge 4.5 zMaw.T.lod",
        "mmmerge_repository": MMMERGE_REPO,
        "mmmerge_commit": MMMERGE_COMMIT,
        "archive_type": "mm8loclod",
        "output_archive": "korean/Data/zzzMawKO.T.lod",
        "files": EXPECTED,
        "replacements": replacements,
        "total_localized_fields": sum(replacements.values()),
        "untouched_pending_schema_review": ["POTION.TXT", "POTNOTES.TXT", "rnditems.txt"],
        "policy": "MAW 4.5 gameplay fields preserved; reviewed display fields inherit pinned MMMerge Korean runtime text; output uses the existing Korean CP949/DBCS encoding convention.",
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
