#!/usr/bin/env python3
"""Mark extracted strings that actually live inside Lua --[[ ... ]] comments.

The main extractor already ignores ordinary ``--`` line comments, but its
line-oriented scanner cannot carry block-comment state across lines.  This
post-pass reconstructs that state and marks comment-only occurrences as
non-localizable without changing runtime source files.
"""
from __future__ import annotations

import argparse
import csv
import json
from collections import Counter, defaultdict
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


def strip_block_comments(line: str, in_block: bool) -> tuple[str, bool]:
    """Remove --[[...]] regions while respecting normal quoted strings."""
    out: list[str] = []
    i = 0
    quote: str | None = None
    while i < len(line):
        if in_block:
            end = line.find("]]", i)
            if end < 0:
                return "".join(out), True
            i = end + 2
            in_block = False
            continue

        ch = line[i]
        if quote:
            out.append(ch)
            if ch == "\\" and i + 1 < len(line):
                out.append(line[i + 1])
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue

        if line.startswith("--[[", i):
            in_block = True
            i += 4
            continue
        if ch in ('"', "'"):
            quote = ch
        out.append(ch)
        i += 1
    return "".join(out), in_block


def decoded_strings(line: str) -> set[str]:
    values: set[str] = set()
    i = 0
    while i < len(line):
        if line.startswith("--", i):
            break
        if line[i] not in ('"', "'"):
            i += 1
            continue
        quote = line[i]
        i += 1
        out: list[str] = []
        while i < len(line):
            ch = line[i]
            if ch == "\\" and i + 1 < len(line):
                nxt = line[i + 1]
                escapes = {"n": "\n", "r": "\r", "t": "\t", "\\": "\\", '"': '"', "'": "'"}
                out.append(escapes.get(nxt, "\\" + nxt))
                i += 2
                continue
            if ch == quote:
                i += 1
                values.add("".join(out))
                break
            out.append(ch)
            i += 1
        else:
            break
    return values


def live_strings_by_line(path: Path) -> dict[int, set[str]]:
    live: dict[int, set[str]] = {}
    in_block = False
    for lineno, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        code, in_block = strip_block_comments(line, in_block)
        live[lineno] = decoded_strings(code)
    return live


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

    by_file: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        if row.get("file", "").endswith(".lua"):
            by_file[row["file"]].append(row)

    changed = 0
    for rel, file_rows in by_file.items():
        path = root / rel
        if not path.exists():
            continue
        live = live_strings_by_line(path)
        for row in file_rows:
            try:
                lineno = int(row.get("line", "0"))
            except ValueError:
                continue
            if row.get("source", "") not in live.get(lineno, set()):
                row["patchable"] = "no"
                row["reason"] = "lua_comment_literal"
                changed += 1

    write_rows(occ_path, rows)
    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    report["patchability_reasons"] = dict(sorted(Counter(r.get("reason", "") for r in rows).items()))
    report["lua_comment_literal_occurrences"] = sum(r.get("reason") == "lua_comment_literal" for r in rows)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"comment_occurrences_classified": changed}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
