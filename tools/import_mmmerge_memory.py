#!/usr/bin/env python3
"""Match MAW candidates against the existing MMMerge Korean PO.

Matches are suggestions only. The report also intersects exact PO matches with
``patchable=yes`` occurrences so inherited translations can later be reviewed
from the safest subset instead of from the broad audit catalog.
"""

from __future__ import annotations

import argparse
import ast
import csv
import json
import re
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

MMMERGE_REPO = "munument1/-KR-MMMerge"
MMMERGE_COMMIT = "01b13c9f3c3d4db33ee650ef489fbbdf58765d7e"
MMMERGE_PO_PATH = "translations/ko/mmmerge.po"
MMMERGE_PO_URL = f"https://raw.githubusercontent.com/{MMMERGE_REPO}/{MMMERGE_COMMIT}/{MMMERGE_PO_PATH}"

MATCH_FIELDS = [
    "source", "translation", "match_status", "inheritance_status", "category",
    "occurrences", "patchable_occurrences", "variant_count", "notes",
]
PRINTF_RE = re.compile(r"%(?:\d+\$)?[-+ #0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?[hlLzjt]*[diuoxXfFeEgGaAcspq%]")


def read_tsv(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def normalize_placeholders(text: str) -> str:
    vals = [p for p in PRINTF_RE.findall(text) if p != "%%"]
    return " ".join(sorted(vals))


def po_unquote(token: str) -> str:
    token = token.strip()
    if not token.startswith('"'):
        return ""
    try:
        value = ast.literal_eval(token)
    except (SyntaxError, ValueError):
        return ""
    return value if isinstance(value, str) else ""


def read_po_value(lines: list[str], start: int, directive: str):
    line = lines[start]
    prefix = directive + " "
    if not line.startswith(prefix):
        return None, start
    value = po_unquote(line[len(prefix):])
    i = start + 1
    while i < len(lines) and lines[i].lstrip().startswith('"'):
        value += po_unquote(lines[i].lstrip())
        i += 1
    return value, i


def parse_po(text: str):
    lines = text.splitlines()
    i = 0
    fuzzy = False
    msgid = None
    msgstr = None

    def flush():
        nonlocal fuzzy, msgid, msgstr
        pair = None
        if not fuzzy and msgid not in (None, "") and msgstr not in (None, ""):
            pair = (msgid, msgstr)
        fuzzy = False
        msgid = None
        msgstr = None
        return pair

    while i < len(lines):
        line = lines[i]
        if not line.strip():
            pair = flush()
            if pair:
                yield pair
            i += 1
            continue
        if line.startswith("#,") and "fuzzy" in {flag.strip() for flag in line[2:].split(",")}:
            fuzzy = True
            i += 1
            continue
        if line.startswith("msgid "):
            msgid, i = read_po_value(lines, i, "msgid")
            continue
        if line.startswith("msgstr "):
            msgstr, i = read_po_value(lines, i, "msgstr")
            continue
        i += 1

    pair = flush()
    if pair:
        yield pair


def download_po() -> str:
    request = urllib.request.Request(
        MMMERGE_PO_URL,
        headers={"User-Agent": "MAW-MMMerge-Korean-localization/1.0"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read().decode("utf-8-sig")


def write_tsv(path: Path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(
            f, fieldnames=MATCH_FIELDS, delimiter="\t", lineterminator="\n", extrasaction="ignore"
        )
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--catalog", type=Path, default=Path("localization/catalog.tsv"))
    ap.add_argument("--occurrences", type=Path, default=Path("localization/occurrences.tsv"))
    ap.add_argument("--output", type=Path, default=Path("localization/mmmerge_matches.tsv"))
    ap.add_argument("--report", type=Path, default=Path("localization/mmmerge_match_report.json"))
    args = ap.parse_args()

    root = args.root.resolve()
    catalog = read_tsv(root / args.catalog)
    occurrences = read_tsv(root / args.occurrences)
    po_text = download_po()

    patchable_counts = Counter(
        row.get("source", "") for row in occurrences if row.get("patchable") == "yes"
    )

    memory: dict[str, set[str]] = defaultdict(set)
    pair_count = 0
    for msgid, msgstr in parse_po(po_text):
        memory[msgid].add(msgstr)
        pair_count += 1

    rows = []
    exact = 0
    ambiguous = 0
    safe_exact = 0
    safe_exact_occurrences = 0
    placeholder_rejected = 0
    safe_categories = Counter()

    for row in catalog:
        if row.get("status") == "obsolete":
            continue
        source = row.get("source", "")
        variants = sorted(memory.get(source, set()))
        if not variants:
            continue
        patchable = patchable_counts[source]

        if len(variants) == 1:
            match_status = "exact"
            translation = variants[0]
            exact += 1
            placeholders_ok = normalize_placeholders(source) == normalize_placeholders(translation)
            if patchable > 0 and placeholders_ok:
                inheritance_status = "safe_candidate"
                safe_exact += 1
                safe_exact_occurrences += patchable
                safe_categories[row.get("category", "")] += 1
                notes = "Exact MMMerge PO match with at least one patchable display occurrence; still review MAW wording/context before approval."
            elif patchable > 0 and not placeholders_ok:
                inheritance_status = "rejected_placeholder_mismatch"
                placeholder_rejected += 1
                notes = "Exact PO match exists, but printf placeholders differ; never inherit automatically."
            else:
                inheritance_status = "no_patchable_occurrence"
                notes = "Exact PO match exists, but current MAW occurrences are not approved for patching."
        else:
            match_status = "ambiguous"
            translation = " || ".join(variants)
            inheritance_status = "ambiguous"
            ambiguous += 1
            notes = "Same msgid has multiple Korean translations in MMMerge PO; manual context review required."

        rows.append({
            "source": source,
            "translation": translation,
            "match_status": match_status,
            "inheritance_status": inheritance_status,
            "category": row.get("category", ""),
            "occurrences": row.get("occurrences", ""),
            "patchable_occurrences": patchable,
            "variant_count": len(variants),
            "notes": notes,
        })

    rank = {"safe_candidate": 0, "rejected_placeholder_mismatch": 1, "ambiguous": 2, "no_patchable_occurrence": 3}
    rows.sort(key=lambda r: (rank.get(r["inheritance_status"], 9), r["category"], r["source"].casefold()))
    write_tsv(root / args.output, rows)

    report = {
        "mmmerge_repository": MMMERGE_REPO,
        "mmmerge_commit": MMMERGE_COMMIT,
        "mmmerge_po_path": MMMERGE_PO_PATH,
        "po_pairs_read": pair_count,
        "po_unique_msgids": len(memory),
        "maw_active_candidates": sum(1 for r in catalog if r.get("status") != "obsolete"),
        "matched_sources": len(rows),
        "exact_single_translation": exact,
        "ambiguous_multiple_translations": ambiguous,
        "safe_exact_patchable_sources": safe_exact,
        "safe_exact_patchable_occurrences": safe_exact_occurrences,
        "safe_exact_by_category": dict(sorted(safe_categories.items())),
        "placeholder_mismatch_rejected": placeholder_rejected,
        "policy": "suggestions_only_safe_intersection",
    }
    report_path = root / args.report
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
