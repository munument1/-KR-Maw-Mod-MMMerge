#!/usr/bin/env python3
"""Add manually reviewed short player-facing literals missed by the broad scanner.

The broad extractor deliberately drops many short lower-case tokens because they
are usually engine/control values. A tiny reviewed supplement lets us restore
specific proven display literals without weakening that global safety rule.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

CATALOG_FIELDS = [
    "id", "status", "category", "source", "translation", "placeholders",
    "first_file", "first_line", "occurrences", "notes",
]
OCCURRENCE_FIELDS = [
    "id", "category", "source", "file", "line", "patchable", "reason", "context",
]
PRINTF_RE = re.compile(r"%(?:\d+\$)?[-+ #0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?[diuoxXfFeEgGaAcspq%](?![A-Za-z])")


def read_tsv(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_tsv(path: Path, fields, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def stable_id(source: str) -> str:
    return "maw-" + hashlib.sha1(source.encode("utf-8")).hexdigest()[:12]


def placeholders(text: str) -> str:
    vals = [p for p in PRINTF_RE.findall(text) if p != "%%"]
    return " ".join(sorted(vals))


def lua_strings(line: str):
    i, n = 0, len(line)
    while i < n:
        if line.startswith("--", i):
            return
        if line[i] not in ('"', "'"):
            i += 1
            continue
        quote = line[i]
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
                yield "".join(out)
                break
            out.append(ch)
            i += 1
        else:
            return


def refresh_report(report_path: Path, catalog, occurrences, errors):
    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    counts = Counter(r.get("status", "") for r in catalog)
    active = [r for r in catalog if r.get("status") != "obsolete"]
    patchable = [r for r in occurrences if r.get("patchable") == "yes"]
    report.update({
        "unique_active_candidates": len(active),
        "occurrences": len(occurrences),
        "patchable_occurrences": len(patchable),
        "patchable_unique_sources": len({r.get("source", "") for r in patchable}),
        "unpatchable_occurrences": len(occurrences) - len(patchable),
        "status": dict(sorted(counts.items())),
        "categories": dict(sorted(Counter(r.get("category", "") for r in active).items())),
        "patchability_reasons": dict(sorted(Counter(r.get("reason", "") for r in occurrences).items())),
        "reviewed_short_literal_supplements": len(read_tsv(report_path.parent / "supplemental_short_literals.tsv")),
    })
    existing_errors = [e for e in report.get("validation_errors", []) if e.get("type") != "reviewed_short_literal_not_found"]
    report["validation_errors"] = existing_errors + errors
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--catalog", type=Path, default=Path("localization/catalog.tsv"))
    ap.add_argument("--occurrences", type=Path, default=Path("localization/occurrences.tsv"))
    ap.add_argument("--supplement", type=Path, default=Path("localization/supplemental_short_literals.tsv"))
    ap.add_argument("--report", type=Path, default=Path("localization/report.json"))
    args = ap.parse_args()

    root = args.root.resolve()
    catalog_path = root / args.catalog
    occ_path = root / args.occurrences
    supplement_path = root / args.supplement
    report_path = root / args.report

    catalog = read_tsv(catalog_path)
    occurrences = read_tsv(occ_path)
    supplements = read_tsv(supplement_path)
    by_source = {r.get("source", ""): r for r in catalog if r.get("source")}
    existing_occ = {(r.get("file", ""), r.get("line", ""), r.get("source", "")) for r in occurrences}
    errors = []
    added_occurrences = 0

    for spec in supplements:
        rel = spec.get("file", "")
        source = spec.get("source", "")
        translation = spec.get("translation", "")
        category = spec.get("category", "misc") or "misc"
        notes = spec.get("notes", "")
        path = root / rel
        matches = []
        if path.exists():
            for lineno, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                if any(value == source for value in lua_strings(line)):
                    matches.append((lineno, line.strip()[:500]))
        if not matches:
            errors.append({"type": "reviewed_short_literal_not_found", "file": rel, "source": source})
            continue

        row = by_source.get(source)
        if row is None:
            row = {
                "id": stable_id(source), "status": "translated", "category": category,
                "source": source, "translation": translation, "placeholders": placeholders(source),
                "first_file": rel, "first_line": matches[0][0], "occurrences": 0, "notes": notes,
            }
            catalog.append(row)
            by_source[source] = row
        else:
            row["status"] = "translated"
            row["translation"] = translation
            row["category"] = row.get("category") or category
            row["first_file"] = row.get("first_file") or rel
            row["first_line"] = row.get("first_line") or str(matches[0][0])
            if notes:
                row["notes"] = notes

        if placeholders(source) != placeholders(translation):
            errors.append({"type": "placeholder_mismatch", "source": source})

        for lineno, context in matches:
            key = (rel, str(lineno), source)
            if key in existing_occ:
                continue
            occurrences.append({
                "id": row["id"], "category": category, "source": source,
                "file": rel, "line": lineno, "patchable": "yes",
                "reason": "reviewed_short_display_literal", "context": context,
            })
            existing_occ.add(key)
            added_occurrences += 1

    counts_by_source = Counter(r.get("source", "") for r in occurrences)
    first_by_source = {}
    for occ in sorted(occurrences, key=lambda r: (r.get("file", ""), int(r.get("line", 0) or 0))):
        first_by_source.setdefault(occ.get("source", ""), occ)
    for row in catalog:
        source = row.get("source", "")
        if source in counts_by_source:
            row["occurrences"] = counts_by_source[source]
            first = first_by_source[source]
            row["first_file"] = first.get("file", row.get("first_file", ""))
            row["first_line"] = first.get("line", row.get("first_line", ""))

    catalog.sort(key=lambda r: (r.get("status") == "obsolete", r.get("category", ""), r.get("source", "").casefold()))
    occurrences.sort(key=lambda r: (r.get("file", ""), int(r.get("line", 0) or 0), r.get("source", "").casefold()))
    write_tsv(catalog_path, CATALOG_FIELDS, catalog)
    write_tsv(occ_path, OCCURRENCE_FIELDS, occurrences)
    refresh_report(report_path, catalog, occurrences, errors)

    print(json.dumps({"supplements": len(supplements), "added_occurrences": added_occurrences, "errors": errors}, ensure_ascii=False, indent=2))
    return 2 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
