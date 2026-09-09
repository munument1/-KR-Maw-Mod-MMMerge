#!/usr/bin/env python3
"""Build and validate the Korean localization catalog for MAW MMMerge.

The extractor is intentionally conservative about *editing* game files: it only
collects candidate player-facing strings. Translators can mark false positives
as ``excluded`` in localization/catalog.tsv and those decisions are preserved
when the catalog is regenerated.
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
    "id",
    "status",
    "category",
    "source",
    "translation",
    "placeholders",
    "first_file",
    "first_line",
    "occurrences",
    "notes",
]

OCCURRENCE_FIELDS = ["id", "category", "source", "file", "line", "context"]

# printf-style placeholders used heavily by MAW string.format calls.
PRINTF_RE = re.compile(r"%(?:\d+\$)?[-+ #0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?[hlLzjt]*[diuoxXfFeEgGaAcspq%]")
WORD_RE = re.compile(r"[A-Za-z]")
PATH_RE = re.compile(r"^[A-Za-z0-9_./\\ -]+\.(?:lua|txt|lod|odm|blv|bmp|pcx|png|jpg|jpeg|wav|mp3|dll|exe|ini|json|md|html)$", re.I)
INTERNAL_RE = re.compile(r"^(?:[A-Za-z0-9]+_)+[A-Za-z0-9_]+$")
HEX_RE = re.compile(r"^0x[0-9A-Fa-f]+$")

TARGET_HINTS = (
    "Text =",
    "Text=",
    ".Description",
    ".Name",
    "ShowStatusText",
    "EscMessage",
    "Question",
    "Message",
    "string.format",
    "GameMode",
    "gameMode",
    "MAWBOLSTER",
    "Tooltip",
    "tooltip",
)

SKIP_PREFIXES = (
    "evt.",
    "Game.",
    "Party.",
    "Map.",
    "const.",
    "mem.",
)


def stable_id(source: str) -> str:
    return "maw-" + hashlib.sha1(source.encode("utf-8")).hexdigest()[:12]


def normalize_placeholders(text: str) -> str:
    vals = [p for p in PRINTF_RE.findall(text) if p != "%%"]
    return " ".join(sorted(vals))


def lua_strings_from_line(line: str):
    """Yield (decoded_text, start_column) for Lua single/double quoted strings.

    Stops at -- comments outside strings. This deliberately does not attempt to
    parse multiline long-bracket strings; those are rare in the 4.5 player-facing
    MAW text and can be added explicitly later if found by QA.
    """
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
    # Registry/config/internal keys are common and should only survive when the
    # surrounding statement strongly suggests visible UI text.
    hinted = any(h in line for h in TARGET_HINTS)
    if not hinted and INTERNAL_RE.match(t):
        return False
    if not hinted and t.lower() in {"true", "false", "nil", "on", "off"}:
        return False
    # Tiny lowercase tokens are normally table keys or code flags.
    if not hinted and " " not in t and len(t) <= 4 and t[:1].islower():
        return False
    # Icon/resource identifiers are usually CamelCase with no spaces. Keep
    # known visible categories, but filter them elsewhere.
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
    # These text tables are included as candidates, but the catalog keeps them
    # separate so translators do not accidentally touch numeric/engine fields.
    for path in sorted(table_root.glob("*.txt")):
        rel = path.relative_to(root)
        if path.name.upper() == "SFT.TXT":
            # Animation metadata: huge and overwhelmingly non-translatable.
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
                # Table fields with either spaces or readable title casing are
                # retained. False positives can be permanently excluded.
                if " " not in text and not (len(text) >= 5 and text[:1].isupper()):
                    continue
                yield {
                    "category": "table",
                    "source": text,
                    "file": str(rel).replace("\\", "/"),
                    "line": lineno,
                    "context": line[:500],
                }


def load_existing(path: Path):
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return {row["source"]: row for row in csv.DictReader(f, delimiter="\t") if row.get("source")}


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
    ap.add_argument("--report", type=Path, default=Path("localization/report.json"))
    ap.add_argument("--check", action="store_true", help="fail on translated placeholder mismatches")
    args = ap.parse_args()

    root = args.root.resolve()
    catalog_path = (root / args.catalog).resolve() if not args.catalog.is_absolute() else args.catalog
    occ_path = (root / args.occurrences).resolve() if not args.occurrences.is_absolute() else args.occurrences
    report_path = (root / args.report).resolve() if not args.report.is_absolute() else args.report

    existing = load_existing(catalog_path)
    occurrences = list(scan_lua(root)) + list(scan_tables(root))

    by_source = defaultdict(list)
    for occ in occurrences:
        by_source[occ["source"]].append(occ)

    catalog_rows = []
    occurrence_rows = []
    placeholder_errors = []

    for source in sorted(by_source, key=str.casefold):
        group = by_source[source]
        old = existing.get(source, {})
        categories = Counter(x["category"] for x in group)
        category = old.get("category") or categories.most_common(1)[0][0]
        status = old.get("status") or "untranslated"
        translation = old.get("translation") or ""
        source_ph = normalize_placeholders(source)
        first = sorted(group, key=lambda x: (x["file"], x["line"]))[0]
        row = {
            "id": old.get("id") or stable_id(source),
            "status": status,
            "category": category,
            "source": source,
            "translation": translation,
            "placeholders": source_ph,
            "first_file": first["file"],
            "first_line": first["line"],
            "occurrences": len(group),
            "notes": old.get("notes") or "",
        }
        if translation and status not in {"excluded", "obsolete"}:
            trans_ph = normalize_placeholders(translation)
            if source_ph != trans_ph:
                placeholder_errors.append({"id": row["id"], "source": source, "source_placeholders": source_ph, "translation_placeholders": trans_ph})
        catalog_rows.append(row)
        for occ in group:
            occurrence_rows.append({
                "id": row["id"],
                "category": occ["category"],
                "source": source,
                "file": occ["file"],
                "line": occ["line"],
                "context": occ["context"],
            })

    # Preserve removed text as obsolete so translations are never silently lost
    # and can be reused if upstream reintroduces a string later.
    active_sources = set(by_source)
    for source, old in existing.items():
        if source in active_sources:
            continue
        old = dict(old)
        old["status"] = "obsolete" if old.get("status") != "excluded" else "excluded"
        catalog_rows.append({field: old.get(field, "") for field in CATALOG_FIELDS})

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
        "placeholder_mismatches": placeholder_errors,
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps(report, ensure_ascii=False, indent=2))
    if args.check and placeholder_errors:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
