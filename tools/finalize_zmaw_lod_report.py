#!/usr/bin/env python3
"""Finalize zMaw Korean LOD report after table-specific audits.

POTION/POTNOTES are localized by build_korean_zmaw_potions.py. rnditems.txt is
intentionally left byte-identical after audit_zmaw_rnditems.py proves its
trailing English labels are outside the runtime probability fields.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", type=Path, default=Path("localization/zmaw_lod_ko_report.json"))
    ap.add_argument("--rnditems-report", type=Path, default=Path("localization/zmaw_rnditems_report.json"))
    args = ap.parse_args()

    report = json.loads(args.report.read_text(encoding="utf-8"))
    rnd = json.loads(args.rnditems_report.read_text(encoding="utf-8"))

    errors = list(rnd.get("validation_errors", []))
    if errors:
        raise SystemExit(f"rnditems audit has validation errors: {errors}")
    if rnd.get("recognized_data_rows", 0) <= 0:
        raise SystemExit("rnditems audit recognized no runtime data rows")
    if rnd.get("trailing_label_runtime_role") != "documentation_only_not_localized":
        raise SystemExit("rnditems trailing-label role is not approved for non-localization")

    report["untouched_pending_schema_review"] = []
    report["untouched_byte_preserved"] = ["rnditems.txt"]
    report["reviewed_nonlocalized"] = {
        "rnditems.txt": {
            "reason": "Trailing English item/spell labels are documentation-only; runtime uses item/resource identifiers and six treasure-level weight fields.",
            "recognized_data_rows": rnd["recognized_data_rows"],
            "rows_with_nonempty_trailing_label": rnd.get("rows_with_nonempty_trailing_label", 0),
            "audit_report": "localization/zmaw_rnditems_report.json",
            "byte_preserved": True,
        }
    }
    report["policy"] = (
        "MAW 4.5 gameplay fields preserved; reviewed display fields inherit Korean text; "
        "POTION/POTNOTES localize only Name/Description/Effect while preserving recipe/control matrices; "
        "rnditems is reviewed non-localized data and remains byte-for-byte MAW 4.5 because its trailing English labels are documentation-only."
    )

    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "pending_schema_review": report["untouched_pending_schema_review"],
        "reviewed_nonlocalized": report["reviewed_nonlocalized"],
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
