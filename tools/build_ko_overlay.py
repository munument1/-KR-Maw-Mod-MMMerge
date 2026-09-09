#!/usr/bin/env python3
"""Build a patch-only Korean overlay from localization/catalog.tsv.

Global translations are applied only to ``status=translated`` sources at
``patchable=yes`` occurrences. ``localization/scoped_overrides.tsv`` can target
an explicitly reviewed file/source/context occurrence when the same English
literal is also used as an internal key elsewhere. The source tree is never
edited in place; patched copies are written under ``korean/``.
"""

from __future__ import annotations

import argparse
import csv
import json
import shutil
from collections import Counter, defaultdict
from pathlib import Path


def read_tsv(path: Path):
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def decode_manual(text: str) -> str:
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


def lua_string_spans(line: str):
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
    ap.add_argument("--scoped-overrides", type=Path, default=Path("localization/scoped_overrides.tsv"))
    ap.add_argument("--output", type=Path, default=Path("korean"))
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    root = args.root.resolve()
    catalog = read_tsv(root / args.catalog)
    occurrences = read_tsv(root / args.occurrences)
    scoped_rows = read_tsv(root / args.scoped_overrides)
    output = root / args.output

    translated = {
        row["source"]: row["translation"]
        for row in catalog
        if row.get("status") == "translated" and row.get("translation")
    }

    target_lines = defaultdict(lambda: defaultdict(dict))
    expected = defaultdict(int)
    skipped_unpatchable = defaultdict(int)
    for occ in occurrences:
        source = occ.get("source", "")
        if source not in translated:
            continue
        if occ.get("patchable") != "yes":
            skipped_unpatchable[source] += 1
            continue
        file = occ["file"]
        line = int(occ["line"])
        target_lines[file][line][source] = translated[source]
        expected[source] += 1

    scoped_errors = []
    scoped_targets = 0
    for idx, row in enumerate(scoped_rows, 2):
        file = row.get("file", "").strip()
        source = decode_manual(row.get("source", ""))
        translation = decode_manual(row.get("translation", ""))
        context_contains = decode_manual(row.get("context_contains", ""))
        if not file or not source or not translation:
            scoped_errors.append({"type": "invalid_scoped_override", "row": idx})
            continue
        matches = [
            occ for occ in occurrences
            if occ.get("file") == file
            and occ.get("source") == source
            and (not context_contains or context_contains in occ.get("context", ""))
        ]
        if not matches:
            scoped_errors.append({
                "type": "scoped_override_not_found",
                "row": idx,
                "file": file,
                "source": source,
                "context_contains": context_contains,
            })
            continue
        for occ in matches:
            target_lines[file][int(occ["line"])][source] = translation
            scoped_targets += 1

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

    errors = list(scoped_errors)
    warnings = []
    for source in sorted(translated, key=str.casefold):
        if expected[source] == 0:
            warnings.append({
                "type": "translated_source_has_no_patchable_occurrence",
                "source": source,
                "unpatchable_occurrences": skipped_unpatchable[source],
            })
        elif applied[source] == 0:
            errors.append({
                "type": "translated_source_not_applied",
                "source": source,
                "expected_patchable_occurrences": expected[source],
            })

    manifest = {
        "base": "MAW MMMerge 4.5",
        "base_commit": "342f34edf73dbd72808422cc56f4602959a94030",
        "translated_entries": len(translated),
        "translated_entries_with_patchable_occurrences": sum(1 for s in translated if expected[s] > 0),
        "patchable_occurrences_targeted": sum(expected.values()),
        "scoped_override_rows": len(scoped_rows),
        "scoped_occurrences_targeted": scoped_targets,
        "skipped_unpatchable_occurrences_for_translated_sources": sum(skipped_unpatchable.values()),
        "changed_files": changed_files,
        "warnings": warnings,
        "validation_errors": errors,
        "install": "Copy the contents of korean/ over an MAW MMMerge 4.5 installation after MAW files are installed.",
    }
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    return 2 if args.check and errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
