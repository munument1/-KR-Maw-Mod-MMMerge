#!/usr/bin/env python3
"""Scan the effective Korean overlay for high-confidence runtime English.

This is intentionally independent from catalog translation counts.  It reads
what the game would actually execute (``korean/<path>`` when an overlay copy
exists, otherwise the MAW 4.5 source) and looks for English string literals in
strong player-facing Lua sinks such as status messages, questions, UI text,
descriptions, hints, and display-name assignments.

The first version is audit-only: it writes a focused review queue and does not
fail merely because residuals exist.  Once reviewed, intentional English can be
whitelisted and CI can promote the queue to a strict gate.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path

FIELDS = ["file", "line", "sink", "literal", "context"]
ENGLISH_RE = re.compile(r"[A-Za-z]{3,}")
HANGUL_RE = re.compile(r"[가-힣]")
IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_.:/\\-]*$")
RESOURCE_RE = re.compile(r"^[A-Za-z0-9_./\\ -]+\.(?:lua|txt|lod|odm|blv|bmp|pcx|png|jpg|jpeg|wav|mp3|dll|exe|ini|json|md|html)$", re.I)

# English tokens intentionally retained in Korean UI or implementation-facing
# labels.  Whole literals only; phrases are still reviewed.
WHOLE_LITERAL_ALLOW = {
    "MAW", "GM", "HP", "SP", "AC", "XP", "DPS", "FPS", "ON", "OFF",
    "Alt", "Ctrl", "Shift", "Enter", "ESC", "C", "R", "Y", "n/a",
}

SINK_PATTERNS = [
    ("status", re.compile(r"\bGame\.ShowStatusText\s*\(")),
    ("esc_message", re.compile(r"\bGame\.EscMessage\s*\(")),
    ("message", re.compile(r"(?<![A-Za-z0-9_.])Message\s*\(")),
    ("question", re.compile(r"(?<![A-Za-z0-9_.])Question\s*\(")),
    ("event_hint", re.compile(r"\bevt\.hint\s*\[[^\]]+\]\s*=")),
    ("ui_text", re.compile(r"(?:^|[,{\s])Text\s*=")),
    ("ui_tooltip", re.compile(r"(?:^|[,{\s])(?:Tooltip|tooltip|Title|Label)\s*=")),
    ("description", re.compile(r"(?:\.Description|ClassDescriptions\s*\[[^\]]+\]|SkillDes(?:Normal|Expert|Master|GM)\s*\[[^\]]+\])\s*=")),
    ("display_name", re.compile(r"(?:ClassNames\s*\[[^\]]+\]|(?:ItemsTxt|SpellsTxt|MonstersTxt)\s*\[[^\]]+\]\.Name)\s*=")),
    ("skill_description", re.compile(r"\bSkillz\.setDesc\s*\(")),
]


def lua_string_spans(line: str):
    i = 0
    n = len(line)
    while i < n:
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
                yield start, i, "".join(out)
                break
            out.append(ch)
            i += 1
        else:
            return


def strip_lua_comments(lines: list[str]) -> list[str]:
    """Remove -- comments and common --[[...]] blocks while preserving lines."""
    out = []
    in_block = False
    for raw in lines:
        line = raw.rstrip("\r\n")
        result = []
        i = 0
        while i < len(line):
            if in_block:
                end = line.find("]]", i)
                if end < 0:
                    i = len(line)
                    continue
                in_block = False
                i = end + 2
                continue
            if line.startswith("--[[", i):
                in_block = True
                i += 4
                continue
            if line.startswith("--", i):
                break
            ch = line[i]
            if ch in ('"', "'"):
                quote = ch
                start = i
                i += 1
                while i < len(line):
                    if line[i] == "\\" and i + 1 < len(line):
                        i += 2
                        continue
                    if line[i] == quote:
                        i += 1
                        break
                    i += 1
                result.append(line[start:i])
                continue
            result.append(ch)
            i += 1
        out.append("".join(result))
    return out


def sink_for(line: str) -> str | None:
    for name, pattern in SINK_PATTERNS:
        if pattern.search(line):
            return name
    return None


def looks_like_runtime_english(text: str, sink: str) -> bool:
    stripped = text.strip()
    if not stripped or stripped in WHOLE_LITERAL_ALLOW:
        return False
    if HANGUL_RE.search(stripped):
        return False
    if not ENGLISH_RE.search(stripped):
        return False
    if RESOURCE_RE.fullmatch(stripped):
        return False
    # For broad assignment sinks, identifier-like strings are commonly resource
    # or schema names. Direct message/question sinks keep one-word UI copy.
    if sink not in {"status", "esc_message", "message", "question", "event_hint"}:
        if IDENTIFIER_RE.fullmatch(stripped) and " " not in stripped:
            return False
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--overlay", type=Path, default=Path("korean"))
    ap.add_argument("--output", type=Path, default=Path("localization/runtime_english_residuals.tsv"))
    ap.add_argument("--report", type=Path, default=Path("localization/runtime_english_report.json"))
    args = ap.parse_args()

    root = args.root.resolve()
    overlay = root / args.overlay
    rows = []
    scanned_files = 0

    for src in sorted((root / "Scripts").rglob("*.lua")):
        rel = src.relative_to(root)
        effective = overlay / rel
        path = effective if effective.exists() else src
        raw_lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        clean_lines = strip_lua_comments(raw_lines)
        scanned_files += 1
        for lineno, clean in enumerate(clean_lines, 1):
            sink = sink_for(clean)
            if not sink:
                continue
            for _, _, literal in lua_string_spans(clean):
                if looks_like_runtime_english(literal, sink):
                    rows.append({
                        "file": rel.as_posix(),
                        "line": lineno,
                        "sink": sink,
                        "literal": literal.replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r"),
                        "context": clean.strip().replace("\t", " ")[:500],
                    })

    out_path = root / args.output
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)

    report = {
        "scanned_lua_files": scanned_files,
        "high_confidence_runtime_english_occurrences": len(rows),
        "by_sink": dict(sorted(Counter(r["sink"] for r in rows).items())),
        "policy": "Audit-only high-confidence scan of effective runtime Lua. Review rows before making this a strict CI gate.",
    }
    (root / args.report).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
