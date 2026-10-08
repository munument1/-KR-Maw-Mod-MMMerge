#!/usr/bin/env python3
"""Reapply audited display occurrences after upstream file moves.

Match path, source and exact context; never translate an internal occurrence
because another occurrence of the same literal is user-visible.
"""
import argparse, csv, json, re
from pathlib import Path
from collections import Counter

def read(path):
    with path.open(encoding="utf-8-sig",newline="") as f:return list(csv.DictReader(f,delimiter="\t"))
def write(path,rows):
    with path.open("w",encoding="utf-8",newline="") as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]),delimiter="\t",lineterminator="\n");w.writeheader();w.writerows(rows)
def main():
    ap=argparse.ArgumentParser();ap.add_argument("--root",type=Path,default=Path("."));args=ap.parse_args();root=args.root
    path=root/"localization/occurrences.tsv";rows=read(path)
    reviewed={(r["file"],r["source"],r["context"]):r for r in read(root/"localization/reviewed_occurrences.tsv")}
    found=set()
    for r in rows:
        k=(r["file"],r["source"],r["context"])
        if k in reviewed:
            r["patchable"]=reviewed[k]["patchable"];r["reason"]=reviewed[k]["reason"];found.add(k)
        if "GetProcAddress(" in r["context"] or "UI.Group(" in r["context"]:
            r["patchable"]="no";r["reason"]="reviewed_internal_identifier"
    write(path,rows)
    catpath=root/"localization/catalog.tsv";cat=read(catpath)
    for r in cat:
        stripped=re.sub(r"%(?:\d+\$)?[-+ #0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?[diuoxXfFeEgGaAcspq%]","",r["source"])
        if not re.search(r"[A-Za-z]",stripped) or r["source"]=="PostMessageA":
            if r["status"]=="untranslated":r["status"]="excluded";r["notes"]="Audited formatting-only template or Windows API identifier"
    write(catpath,cat)
    reportpath=root/"localization/report.json";report=json.loads(reportpath.read_text());report["status"]=dict(Counter(r["status"] for r in cat));report["reviewed_upstream_occurrences"]=len(found);report["reviewed_upstream_missing"]=len(reviewed.keys()-found);report["patchability_reasons"]=dict(Counter(r["reason"] for r in rows));reportpath.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print("Audited display occurrences:",len(found),"missing:",len(reviewed.keys()-found))
    return 1 if reviewed.keys()-found else 0
if __name__=="__main__":raise SystemExit(main())
