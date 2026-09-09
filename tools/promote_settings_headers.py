#!/usr/bin/env python3
"""Promote only settings-page header literals proven to become CustomUI text."""
from __future__ import annotations
import argparse,csv,json,re
from collections import Counter
from pathlib import Path
FIELDS=["id","category","source","file","line","patchable","reason","context"]
TARGETS={
 ("Scripts/General/MenuExtraSettings.lua"," General settings"),
 ("Scripts/General/AdaptiveMonstersStats.lua","MAW SETTINGS"),
}
def read(p):
 with p.open("r",encoding="utf-8-sig",newline="") as f:return list(csv.DictReader(f,delimiter="\t"))
def write(p,rows):
 with p.open("w",encoding="utf-8",newline="") as f:
  w=csv.DictWriter(f,fieldnames=FIELDS,delimiter="\t",lineterminator="\n",extrasaction="ignore");w.writeheader();w.writerows(rows)
def main():
 ap=argparse.ArgumentParser();ap.add_argument("--root",type=Path,default=Path("."));a=ap.parse_args();root=a.root.resolve();occ=root/"localization/occurrences.tsv";rp=root/"localization/report.json";rows=read(occ);n=0
 for r in rows:
  if r.get("patchable")!="no" or r.get("reason")!="uncertain_context":continue
  key=(r.get("file",""),r.get("source",""));ctx=r.get("context","")
  if key in TARGETS and "NewSettingsPage(" in ctx:
   r["patchable"]="yes";r["reason"]="proven_settings_page_header";n+=1
 write(occ,rows);rep=json.loads(rp.read_text(encoding="utf-8"));rep["patchability_reasons"]=dict(sorted(Counter(r.get("reason","") for r in rows).items()));rep["proven_settings_header_promotions"]=n;rp.write_text(json.dumps(rep,ensure_ascii=False,indent=2)+"\n",encoding="utf-8");print(json.dumps({"promoted_occurrences":n},ensure_ascii=False,indent=2));return 0
if __name__=="__main__":raise SystemExit(main())
