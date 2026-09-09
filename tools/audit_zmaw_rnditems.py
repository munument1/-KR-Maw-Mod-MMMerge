#!/usr/bin/env python3
"""Audit MAW rnditems.txt without localizing documentation-only labels.

The MAW 4.5/MMMerge table stores each recognized data row as:

    numeric item id | resource id | level 1..6 weights | label

The runtime-relevant fields are the item/resource identifiers and six numeric
treasure-level weights.  The trailing English item/spell label is a
human-readable aid and is intentionally preserved rather than localized.

For compatibility with related MM table variants the parser also recognizes an
8-field resource-id form, but MAW 4.5 is not required to contain that variant.
The audit never modifies rnditems.txt.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def decode_text(data: bytes) -> tuple[str, str]:
    for encoding in ("utf-8-sig", "cp1252", "latin-1"):
        try:
            return data.decode(encoding), encoding
        except UnicodeDecodeError:
            continue
    return data.decode("latin-1", errors="replace"), "latin-1-replace"


def is_int(value: str) -> bool:
    try:
        int(value.strip())
        return True
    except ValueError:
        return False


def classify(fields: list[str]) -> tuple[str, list[str]] | None:
    # The final field is deliberately kept outside the six numeric weights: it
    # is the human-readable label whose non-runtime role this audit records.
    if len(fields) == 9 and is_int(fields[0]) and all(is_int(v) for v in fields[2:8]):
        return "item_id_resource_weights_label", fields[2:8]
    if len(fields) == 8 and fields[0].strip() and all(is_int(v) for v in fields[1:7]):
        return "resource_weights_label", fields[1:7]
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source-dir", type=Path, default=Path("localization/zmaw_lod_source"))
    ap.add_argument("--report", type=Path, default=Path("localization/zmaw_rnditems_report.json"))
    args = ap.parse_args()

    matches = [p for p in args.source_dir.iterdir() if p.is_file() and p.name.casefold() == "rnditems.txt"]
    if len(matches) != 1:
        raise SystemExit(f"expected exactly one rnditems.txt, found {len(matches)}")

    path = matches[0]
    raw = path.read_bytes()
    text, encoding = decode_text(raw)

    layouts = {
        "item_id_resource_weights_label": 0,
        "resource_weights_label": 0,
    }
    data_rows = 0
    nonempty_labels = 0
    negative_weights = 0
    max_weight = 0
    examples: dict[str, list[dict[str, object]]] = {k: [] for k in layouts}

    for line_no, line in enumerate(text.splitlines(), 1):
        fields = line.split("\t")
        parsed = classify(fields)
        if parsed is None:
            continue
        layout, weight_fields = parsed
        weights = [int(v.strip()) for v in weight_fields]
        label = fields[-1]

        layouts[layout] += 1
        data_rows += 1
        nonempty_labels += int(bool(label.strip()))
        negative_weights += sum(v < 0 for v in weights)
        if weights:
            max_weight = max(max_weight, *weights)

        if len(examples[layout]) < 3:
            examples[layout].append({
                "line": line_no,
                "key": fields[0],
                "label": label,
                "weights": weights,
            })

    errors: list[str] = []
    if data_rows == 0:
        errors.append("no recognized rnditems data rows")
    if layouts["item_id_resource_weights_label"] == 0:
        errors.append("expected MAW item-id/resource/weights rows")
    if negative_weights:
        errors.append(f"found {negative_weights} negative treasure weights")

    report = {
        "file": path.name,
        "bytes": len(raw),
        "encoding": encoding,
        "recognized_data_rows": data_rows,
        "layouts": layouts,
        "rows_with_nonempty_trailing_label": nonempty_labels,
        "max_treasure_weight": max_weight,
        "negative_weight_fields": negative_weights,
        "trailing_label_runtime_role": "documentation_only_not_localized",
        "runtime_fields": "numeric item id, resource id, and six numeric treasure-level weights",
        "evidence": "Compatible MM8 loaders consume item/key data and six weight columns; the trailing item/spell label is outside those runtime fields.",
        "examples": examples,
        "validation_errors": errors,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
