#!/usr/bin/env python3
"""Build and validate the Korean localization catalog for MAW MMMerge.

Human edits live in ``localization/translations.tsv``. Generated catalog files
are refreshed from the 4.5 source tree and preserve translation decisions.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

CATALOG_FIELDS = [
    "id", "status", "category", "source", "translation", "placeholders",
    "first_file", "first_line", "occurrences", "notes",
]
OCCURRENCE_FIELDS = ["id", "category", "source", "file", "line", "context"]
TRANSLATION_FIELDS = ["source", "translation", "status", "notes"]

PRINTF_RE = re.compile(r"%(?:\d+\$)?[-+ #0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?[hlLzjt]*[diuoxXfFeEgGaAcspq%]")
WORD_RE = re.compile(r"[A-Za-z]")
PATH_RE = re.compile(r"^[A-Za-z0-9_./\\ -]+\.(?:lua|txt|lod|odm|blv|bmp|pcx|png|jpg|jpeg|wav|mp3|dll|exe|ini|json|md|html)$", re.I)
INTERNAL_RE = re.compile(r"^(?:[A-Za-z0-9]+_)+[A-Za-z0-9_]+$")
HEX_RE = re.compile(r"^0x[0-9A-Fa-f]+$")

TARGET_HINTS = (
    "Text =", "Text=", ".Description", ".Name", "ShowStatusText",
    "EscMessage", "Question", "Message", "string.format", "GameMode",
    "gameMode", "MAWBOLSTER", "Tooltip", "tooltip",
)
SKIP_PREFIXES = ("evt.", "Game.", "Party.", "Map.", "const.", "mem.")


def stable_id(source: str) -> str:
    return "maw-" + hashlib.sha1(source.encode("utf-8")).hexdigest()[:12]


def normalize_placeholders(text: str) -> str:
    vals = [p for p in PRINTF_RE.findall(text) if p != "%%"]
    return " ".join(sorted(vals))


def decode_manual(text: str) -> str:
    """Decode the small escape subset used in translations.tsv."""
    out = []
    i = 0
    while i < len(text):
        if text[i] == "\\" and i + 1 < len(text):
            nxt = text[i + 1]
            if nxt == "n":
                out.append("\n"); i += 2; continue
            if nxt == "t":
                out.append("\t"); i += 2; continue
            if nxt == "r":
                out.append("\r"); i += 2; continue
            if nxt == "\\":
                out.append("\\"); i += 2; continue
        out.append(text[i]); i += 1
    return "".join(out)


def lua_strings_from_line(line: str):
    """Yield decoded Lua single/double quoted strings outside -- comments."""
    i = 0
    n = len(line)
    while i < n:
        if line.startswith("--", i):
            return
        ch = line[i]
        if ch not in ("\"", "'"):
            i += 1
            continue
        quote = ch
        start = i
        i += 1
        out = []
        while i < n:
            ch = line[i]
            if ch == "\\" and i + 1 < n:
                nxt = line[i + 1]
                escapes = {"n": "\n", "r": "\r", "t": "\t", "\\": "\\", "\"": "\"", "'": "'"}
                out.append(escapes.get(nxt, "\\" + nxt))
                i += 2
                continue
            if ch == quote:
                i += 1
                yield "".join(out), start + 1
                break
            out.append(ch)
            i += 1
        else:
            return


def category_for(path: Path, line: str) -> str:
    s = str(path).replace("\\", "/")
    low = line.lower()
    if "showstatustext" in low or "escmessage" in low or "message" in low:
        return "status"
    if "description" in low or "tooltip" in low:
        return "tooltip"
    if "menu" in s.lower() or "customui" in low or "text =" in low or "text=" in low:
        return "ui"
    if "/Maps/" in s:
        return "map"
    if "Data/Tables/" in s:
        return "table"
    if "Items" in s or "item" in low:
        return "item"
    if "Spells" in s or "spell" in low:
        return "spell"
    if "Skills" in s or "skill" in low:
        return "skill"
    if "Classes" in s or "class" in low:
        return "class"
    if "Monsters" in s or "monster" in low:
        return "monster"
    return "misc"


def is_candidate(text: str, line: str, category: str) -> bool:
    t = text.strip()
    if not t or len(t) < 2 or not WORD_RE.search(t):
        return False
    if t.startswith(SKIP_PREFIXES) or HEX_RE.match(t) or PATH_RE.match(t):
        return False
    hinted = any(h in line for h in TARGET_HINTS)
    if not hinted and INTERNAL_RE.match(t):
        return False
    if not hinted and t.lower() in {"true", "false", "nil", "on", "off"}:
        return False
    if not hinted and " " not in t and len(t) <= 4 and t[:1].islower():
        return False
    if not hinted and category == "misc" and " " not in t and re.match(r"^[A-Za-z][A-Za-z0-9]*$", t):
        return False
    return True


def scan_lua(root: Path):
    for path in sorted((root / "Scripts").rglob("*.lua")):
        rel = path.relative_to(root)
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for lineno, line in enumerate(lines, 1):
            category = category_for(rel, line)
            for text, _col in lua_strings_from_line(line):
                if is_candidate(text, line, category):
                    yield {
                        "category": category,
                        "source": text,
                        "file": str(rel).replace("\\", "/"),
                        "line": lineno,
                        "context": line.strip()[:500],
                    }


def scan_tables(root: Path):
    table_root = root / "Data" / "Tables"
    if not table_root.exists():
        return
    for path in sorted(table_root.glob("*.txt")):
        rel = path.relative_to(root)
        if path.name.upper() == "SFT.TXT":
            continue
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for lineno, line in enumerate(lines, 1):
            for field in line.split("\t"):
                text = field.strip().strip('"')
                if not text or not WORD_RE.search(text):
                    continue
                if PATH_RE.match(text) or INTERNAL_RE.match(text) or HEX_RE.match(text):
                    continue
                if " " not in text and not (len(text) >= 5 and text[:1].isupper()):
                    continue
                yield {
                    "category": "table",
                    "source": text,
                    "file": str(rel).replace("\\", "/"),
                    "line": lineno,
                    "context": line[:500],
                }


def load_tsv(path: Path, *, decode=False):
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        rows = {}
        for row in csv.DictReader(f, delimiter="\t"):
            source = row.get("source", "")
            if decode:
                source = decode_manual(source)
                row = dict(row)
                row["source"] = source
                row["translation"] = decode_manual(row.get("translation", ""))
            if source:
                rows[source] = row
        return rows


def write_tsv(path: Path, fields, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--catalog", type=Path, default=Path("localization/catalog.tsv"))
    ap.add_argument("--occurrences", type=Path, default=Path("localization/occurrences.tsv"))
    ap.add_argument("--translations", type=Path, default=Path("localization/translations.tsv"))
    ap.add_argument("--report", type=Path, default=Path("localization/report.json"))
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    root = args.root.resolve()
    catalog_path = root / args.catalog
    occ_path = root / args.occurrences
    translations_path = root / args.translations
    report_path = root / args.report

    existing = load_tsv(catalog_path)
    manual = load_tsv(translations_path, decode=True)
    occurrences = list(scan_lua(root)) + list(scan_tables(root))
    by_source = defaultdict(list)
    for occ in occurrences:
        by_source[occ["source"]].append(occ)

    catalog_rows = []
    occurrence_rows = []
    errors = []

    for source in sorted(by_source, key=str.casefold):
        group = by_source[source]
        old = existing.get(source, {})
        override = manual.get(source, {})
        categories = Counter(x["category"] for x in group)
        category = override.get("category") or old.get("category") or categories.most_common(1)[0][0]
        translation = override.get("translation") if source in manual else old.get("translation", "")
        status = override.get("status") if source in manual else old.get("status", "")
        notes = override.get("notes") if source in manual else old.get("notes", "")
        if not status:
            status = "translated" if translation else "untranslated"
        source_ph = normalize_placeholders(source)
        first = sorted(group, key=lambda x: (x["file"], x["line"]))[0]
        row = {
            "id": old.get("id") or stable_id(source),
            "status": status,
            "category": category,
            "source": source,
            "translation": translation or "",
            "placeholders": source_ph,
            "first_file": first["file"],
            "first_line": first["line"],
            "occurrences": len(group),
            "notes": notes or "",
        }
        if status == "translated" and not translation:
            errors.append({"id": row["id"], "type": "empty_translation", "source": source})
        if translation and status not in {"excluded", "obsolete"}:
            trans_ph = normalize_placeholders(translation)
            if source_ph != trans_ph:
                errors.append({
                    "id": row["id"], "type": "placeholder_mismatch", "source": source,
                    "source_placeholders": source_ph, "translation_placeholders": trans_ph,
                })
        catalog_rows.append(row)
        for occ in group:
            occurrence_rows.append({
                "id": row["id"], "category": occ["category"], "source": source,
                "file": occ["file"], "line": occ["line"], "context": occ["context"],
            })

    active_sources = set(by_source)
    for source, old in existing.items():
        if source in active_sources:
            continue
        old = dict(old)
        old["status"] = "excluded" if old.get("status") == "excluded" else "obsolete"
        catalog_rows.append({field: old.get(field, "") for field in CATALOG_FIELDS})

    # Manual entries that do not exist in the current source are errors; this
    # catches typos and stale escape sequences early.
    for source in manual:
        if source not in active_sources:
            errors.append({"type": "manual_source_not_found", "source": source})

    catalog_rows.sort(key=lambda r: (r.get("status") == "obsolete", r.get("category", ""), r.get("source", "").casefold()))
    occurrence_rows.sort(key=lambda r: (r["file"], int(r["line"]), r["source"].casefold()))
    write_tsv(catalog_path, CATALOG_FIELDS, catalog_rows)
    write_tsv(occ_path, OCCURRENCE_FIELDS, occurrence_rows)

    counts = Counter(row["status"] for row in catalog_rows)
    active_rows = [r for r in catalog_rows if r["status"] != "obsolete"]
    report = {
        "base": "MAW MMMerge 4.5",
        "base_commit": "342f34edf73dbd72808422cc56f4602959a94030",
        "unique_active_candidates": len(active_rows),
        "occurrences": len(occurrence_rows),
        "status": dict(sorted(counts.items())),
        "categories": dict(sorted(Counter(r["category"] for r in active_rows).items())),
        "validation_errors": errors,
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 2 if args.check and errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
