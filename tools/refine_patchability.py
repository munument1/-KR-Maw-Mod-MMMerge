#!/usr/bin/env python3
"""Refine MAW localization patchability at the individual string level.

The main extractor intentionally uses conservative line-level display signals.
This second pass removes false positives where a line contains both player-facing
text and control literals such as ``answer == "yes"`` or table index keys such
as ``["SpellPoints"]``.  Only occurrences.tsv is changed; catalog membership is
kept broad for audit purposes.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path

FIELDS = ["id", "category", "source", "file", "line", "patchable", "reason", "context"]


def read_rows(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_rows(path: Path, rows):
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def quoted(text: str) -> str:
    return re.escape(text)


def refine(row: dict[str, str]) -> None:
    if row.get("patchable") != "yes":
        return

    source = row.get("source", "")
    context = row.get("context", "")
    q = quoted(source)

    # Comparison/control literals can share a line with Question() or another
    # display call. Translating them changes program flow instead of UI text.
    if re.search(rf"(?:==|~=|<=|>=)\s*['\"]{q}['\"]", context):
        row["patchable"] = "no"
        row["reason"] = "comparison_control_literal"
        return

    # String table/index keys are identifiers even when the same expression is
    # embedded inside ShowStatusText().
    if re.search(rf"\[\s*['\"]{q}['\"]\s*(?:\]|\.\.)", context):
        row["patchable"] = "no"
        row["reason"] = "index_key_literal"
        return

    # Explicitly protect common answer tokens. These are user-input parser
    # values, not labels; translated prompts should continue to show yes/no.
    if source in {"yes", "Yes", "YES", "no", "No", "NO"}:
        if re.search(r"\banswer\b", context, re.I):
            row["patchable"] = "no"
            row["reason"] = "answer_parser_literal"
            return


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--occurrences", type=Path, default=Path("localization/occurrences.tsv"))
    ap.add_argument("--report", type=Path, default=Path("localization/report.json"))
    args = ap.parse_args()

    root = args.root.resolve()
    occ_path = root / args.occurrences
    report_path = root / args.report

    rows = read_rows(occ_path)
    before = sum(r.get("patchable") == "yes" for r in rows)
    for row in rows:
        refine(row)
    after = sum(r.get("patchable") == "yes" for r in rows)
    write_rows(occ_path, rows)

    if report_path.exists():
        report = json.loads(report_path.read_text(encoding="utf-8"))
        patchable_rows = [r for r in rows if r.get("patchable") == "yes"]
        report["patchable_occurrences"] = len(patchable_rows)
        report["patchable_unique_sources"] = len({r.get("source", "") for r in patchable_rows})
        report["unpatchable_occurrences"] = len(rows) - len(patchable_rows)
        report["patchability_reasons"] = dict(sorted(Counter(r.get("reason", "") for r in rows).items()))
        report["individual_literal_refinements"] = before - after
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({"patchable_before": before, "patchable_after": after, "rejected": before - after}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
