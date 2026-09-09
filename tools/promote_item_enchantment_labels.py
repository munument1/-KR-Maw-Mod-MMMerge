#!/usr/bin/env python3
"""Promote active MAW 4.5 item-enchantment labels proven to reach item UI."""

from __future__ import annotations
import argparse, csv, json
from collections import Counter
from pathlib import Path

FIELDS=["id","category","source","file","line","patchable","reason","context"]
REL="Scripts/General/zzMaw-Items.lua"

def read_rows(p):
    with p.open("r",encoding="utf-8-sig",newline="") as f:return list(csv.DictReader(f,delimiter="\t"))
def write_rows(p,rows):
    with p.open("w",encoding="utf-8",newline="") as f:
        w=csv.DictWriter(f,fieldnames=FIELDS,delimiter="\t",lineterminator="\n",extrasaction="ignore");w.writeheader();w.writerows(rows)
def qvals(s):
    vals=set();i=0
    while i<len(s):
        q=s[i]
        if q not in ('"',"'"):i+=1;continue
        i+=1;out=[]
        while i<len(s):
            c=s[i]
            if c=="\\" and i+1<len(s):
                n=s[i+1];e={"n":"\n","r":"\r","t":"\t","\\":"\\",'"':'"',"'":"'"};out.append(e.get(n,"\\"+n));i+=2;continue
            if c==q:vals.add("".join(out));i+=1;break
            out.append(c);i+=1
    return vals

def discover(root):
    lines=(root/REL).read_text(encoding="utf-8",errors="replace").splitlines();safe=set();in_base=False
    for n,line in enumerate(lines,1):
        s=line.strip()
        if not in_base and s.startswith("baseStatName=") and "{" in s:
            in_base=True;continue
        if in_base:
            if s=="}":in_base=False
            elif qvals(line):safe.add(n)
        # Active fire-aura tooltip: the name table and composed display string.
        if 'local name={"Fire","Flame","Inferno","Hell"' in line or ' Aura: adds ' in line:
            safe.add(n)
        # Random-enchantment preview written straight to t.Enchantment.
        if 'baseStatName[bonus] .. " +X"' in line:
            safe.add(n)
    return safe

def main():
    ap=argparse.ArgumentParser();ap.add_argument("--root",type=Path,default=Path("."));a=ap.parse_args();root=a.root.resolve()
    occ=root/"localization/occurrences.tsv";rp=root/"localization/report.json";rows=read_rows(occ);safe=discover(root);p=0
    for r in rows:
        if r.get("patchable")!="no" or r.get("reason")!="uncertain_context" or r.get("file")!=REL:continue
        try:ln=int(r.get("line","0"))
        except ValueError:ln=0
        src=r.get("source","");ctx=r.get("context","")
        if ln in safe and src and src in qvals(ctx):
            r["patchable"]="yes";r["reason"]="proven_item_enchantment_label";p+=1
    write_rows(occ,rows);rep=json.loads(rp.read_text(encoding="utf-8"));rep["patchability_reasons"]=dict(sorted(Counter(r.get("reason","") for r in rows).items()));rep["proven_item_enchantment_label_lines"]=len(safe);rep["proven_item_enchantment_label_promotions"]=p;rp.write_text(json.dumps(rep,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"safe_lines":len(safe),"promoted_occurrences":p},ensure_ascii=False,indent=2));return 0
if __name__=="__main__":raise SystemExit(main())
