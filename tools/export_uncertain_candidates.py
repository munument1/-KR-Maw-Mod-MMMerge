#!/usr/bin/env python3
"""Export untranslated Lua strings whose player-facing status is still uncertain.

The queue is enriched with exact/ambiguous MMMerge translation-memory matches
when available. It is a review queue, not an automatic patch list.
"""

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path

FIELDS = [
    "source", "category", "uncertain_occurrences", "all_occurrences", "reasons",
    "files", "mmmerge_status", "mmmerge_suggestion", "sample_context",
]


def read_tsv(path: Path):
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--catalog", type=Path, default=Path("localization/catalog.tsv"))
    ap.add_argument("--occurrences", type=Path, default=Path("localization/occurrences.tsv"))
    ap.add_argument("--memory", type=Path, default=Path("localization/mmmerge_matches.tsv"))
    ap.add_argument("--output", type=Path, default=Path("localization/uncertain_candidates.tsv"))
    ap.add_argument("--report", type=Path, default=Path("localization/report.json"))
    args = ap.parse_args()

    root = args.root.resolve()
    catalog = {r.get("source", ""): r for r in read_tsv(root / args.catalog)}
    occurrences = read_tsv(root / args.occurrences)
    memory = {r.get("source", ""): r for r in read_tsv(root / args.memory)}

    groups: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in occurrences:
        source = row.get("source", "")
        if source:
            groups[source].append(row)

    rows = []
    for source, occs in groups.items():
        cat = catalog.get(source, {})
        if cat.get("status") != "untranslated":
            continue
        uncertain = [o for o in occs if o.get("reason") == "uncertain_context" and not o.get("file", "").startswith("Data/Tables/")]
        if not uncertain:
            continue
        reasons = Counter(o.get("reason", "") for o in occs)
        files = sorted({o.get("file", "") for o in uncertain if o.get("file")})
        mem = memory.get(source, {})
        rows.append({
            "source": source,
            "category": cat.get("category", ""),
            "uncertain_occurrences": len(uncertain),
            "all_occurrences": len(occs),
            "reasons": "; ".join(f"{k}:{v}" for k, v in sorted(reasons.items())),
            "files": "; ".join(files),
            "mmmerge_status": mem.get("match_status", ""),
            "mmmerge_suggestion": mem.get("translation", ""),
            "sample_context": uncertain[0].get("context", ""),
        })

    rows.sort(key=lambda r: (
        0 if r["mmmerge_status"] == "exact" else 1 if r["mmmerge_status"] == "ambiguous" else 2,
        r["category"],
        -int(r["uncertain_occurrences"]),
        r["source"].casefold(),
    ))

    out = root / args.output
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)

    report_path = root / args.report
    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    report["uncertain_review_unique_sources"] = len(rows)
    report["uncertain_review_occurrences"] = sum(int(r["uncertain_occurrences"]) for r in rows)
    report["uncertain_review_exact_mmmerge_matches"] = sum(r["mmmerge_status"] == "exact" for r in rows)
    report["uncertain_review_ambiguous_mmmerge_matches"] = sum(r["mmmerge_status"] == "ambiguous" for r in rows)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({
        "uncertain_unique_sources": len(rows),
        "uncertain_occurrences": sum(int(r["uncertain_occurrences"]) for r in rows),
        "exact_mmmerge_matches": sum(r["mmmerge_status"] == "exact" for r in rows),
        "ambiguous_mmmerge_matches": sum(r["mmmerge_status"] == "ambiguous" for r in rows),
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
