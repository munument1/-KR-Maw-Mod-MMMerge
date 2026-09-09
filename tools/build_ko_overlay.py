#!/usr/bin/env python3
"""Build a patch-only Korean overlay from localization/catalog.tsv.

Only entries with status=translated are applied. Source files are never edited
in place; patched copies are written under korean/ using the same relative path.
"""

from __future__ import annotations

import argparse
import csv
import json
import shutil
from collections import Counter, defaultdict
from pathlib import Path


def read_tsv(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def lua_string_spans(line: str):
    """Yield (start, end, quote, decoded_text) for strings outside -- comments."""
    i = 0
    n = len(line)
    while i < n:
        if line.startswith("--", i):
            return
        ch = line[i]
        if ch not in ('"', "'"):
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
                escapes = {"n": "\n", "r": "\r", "t": "\t", "\\": "\\", '"': '"', "'": "'"}
                out.append(escapes.get(nxt, "\\" + nxt))
                i += 2
                continue
            if ch == quote:
                i += 1
                yield start, i, quote, "".join(out)
                break
            out.append(ch)
            i += 1
        else:
            return


def encode_lua(text: str, quote: str) -> str:
    text = text.replace("\\", "\\\\")
    text = text.replace("\r", "\\r").replace("\n", "\\n").replace("\t", "\\t")
    text = text.replace(quote, "\\" + quote)
    return quote + text + quote


def patch_lua_line(line: str, mapping: dict[str, str]):
    spans = list(lua_string_spans(line))
    if not spans:
        return line, Counter()
    replacements = []
    matched = Counter()
    for start, end, quote, decoded in spans:
        if decoded in mapping:
            replacements.append((start, end, encode_lua(mapping[decoded], quote)))
            matched[decoded] += 1
    if not replacements:
        return line, matched
    out = line
    for start, end, replacement in reversed(replacements):
        out = out[:start] + replacement + out[end:]
    return out, matched


def patch_table_line(line: str, mapping: dict[str, str]):
    fields = line.split("\t")
    matched = Counter()
    out = []
    for field in fields:
        left_len = len(field) - len(field.lstrip())
        right_len = len(field) - len(field.rstrip())
        left = field[:left_len]
        right = field[len(field) - right_len:] if right_len else ""
        core_end = len(field) - right_len if right_len else len(field)
        core = field[left_len:core_end]
        quoted = len(core) >= 2 and core[0] == '"' and core[-1] == '"'
        value = core[1:-1] if quoted else core
        if value in mapping:
            new_value = mapping[value]
            core = '"' + new_value.replace('"', '""') + '"' if quoted else new_value
            matched[value] += 1
        out.append(left + core + right)
    return "\t".join(out), matched


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--catalog", type=Path, default=Path("localization/catalog.tsv"))
    ap.add_argument("--occurrences", type=Path, default=Path("localization/occurrences.tsv"))
    ap.add_argument("--output", type=Path, default=Path("korean"))
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    root = args.root.resolve()
    catalog = read_tsv(root / args.catalog)
    occurrences = read_tsv(root / args.occurrences)
    output = root / args.output

    translated = {
        row["source"]: row["translation"]
        for row in catalog
        if row.get("status") == "translated" and row.get("translation")
    }

    target_lines = defaultdict(lambda: defaultdict(dict))
    expected = defaultdict(int)
    for occ in occurrences:
        source = occ["source"]
        if source not in translated:
            continue
        file = occ["file"]
        line = int(occ["line"])
        target_lines[file][line][source] = translated[source]
        expected[source] += 1

    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True, exist_ok=True)

    applied = defaultdict(int)
    changed_files = []

    for rel, line_map in sorted(target_lines.items()):
        src = root / rel
        if not src.exists():
            continue
        lines = src.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
        changed = 0
        for lineno, mapping in sorted(line_map.items()):
            if lineno < 1 or lineno > len(lines):
                continue
            raw = lines[lineno - 1]
            newline = ""
            body = raw
            if raw.endswith("\r\n"):
                body, newline = raw[:-2], "\r\n"
            elif raw.endswith("\n"):
                body, newline = raw[:-1], "\n"
            elif raw.endswith("\r"):
                body, newline = raw[:-1], "\r"

            if rel.lower().endswith(".lua"):
                patched, matched = patch_lua_line(body, mapping)
            elif rel.startswith("Data/Tables/") and rel.lower().endswith(".txt"):
                patched, matched = patch_table_line(body, mapping)
            else:
                patched, matched = body, Counter()

            count = sum(matched.values())
            if count:
                lines[lineno - 1] = patched + newline
                changed += count
                for source, match_count in matched.items():
                    applied[source] += match_count

        if changed:
            dst = output / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_text("".join(lines), encoding="utf-8", newline="")
            changed_files.append({"file": rel, "replacements": changed})

    errors = []
    for source in sorted(translated, key=str.casefold):
        if expected[source] == 0:
            errors.append({"type": "translated_source_has_no_occurrence", "source": source})
        elif applied[source] == 0:
            errors.append({"type": "translated_source_not_applied", "source": source, "expected_occurrences": expected[source]})

    manifest = {
        "base": "MAW MMMerge 4.5",
        "base_commit": "342f34edf73dbd72808422cc56f4602959a94030",
        "translated_entries": len(translated),
        "changed_files": changed_files,
        "validation_errors": errors,
        "install": "Copy the contents of korean/ over an MAW MMMerge 4.5 installation after MAW files are installed.",
    }
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    return 2 if args.check and errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
