#!/usr/bin/env python3
"""Apply small runtime localization fixes found by the independent English scan."""
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


def ensure_overlay_file(root: Path, output: Path, rel: str) -> Path:
    dst = output / rel
    if not dst.exists():
        src = root / rel
        if not src.exists():
            raise FileNotFoundError(rel)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
    return dst


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--output", type=Path, default=Path("korean"))
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    root = args.root.resolve()
    output = root / args.output
    manifest_path = output / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    errors = []
    fixes = []

    rel = "Scripts/Maps/d22.lua"
    try:
        path = ensure_overlay_file(root, output, rel)
        text = path.read_text(encoding="utf-8")
        old = 'evt.hint[452] = "test"'
        new = 'evt.hint[452] = "문"'
        count = text.count(old)
        if count != 1:
            errors.append({
                "type": "runtime_residual_anchor_mismatch",
                "file": rel,
                "anchor": old,
                "expected": 1,
                "found": count,
            })
        else:
            text = text.replace(old, new, 1)
            path.write_text(text, encoding="utf-8", newline="")
            fixes.append({
                "file": rel,
                "source": "test",
                "translation": "문",
                "reason": "Active event 452 opens door 1; replace developer placeholder hint with a neutral Korean door label.",
                "replacements": 1,
            })
    except FileNotFoundError as exc:
        errors.append({"type": "runtime_residual_source_missing", "file": str(exc)})

    existing_errors = list(manifest.get("validation_errors", []))
    manifest["runtime_residual_fixes"] = fixes
    manifest["validation_errors"] = existing_errors + errors
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({"runtime_residual_fixes": fixes, "validation_errors": errors}, ensure_ascii=False, indent=2))
    return 2 if args.check and errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
