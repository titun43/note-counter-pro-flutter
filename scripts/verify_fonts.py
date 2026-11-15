#!/usr/bin/env python3
"""Verify downloaded TTFs contain required Unicode ranges."""
from fontTools.ttLib import TTFont
import sys

REQUIRED = {
    "Latin basic":      (0x0020, 0x007F),
    "Latin extended":   (0x00A0, 0x00FF),
    "Bengali":          (0x0980, 0x09FF),
    "Devanagari":       (0x0900, 0x097F),
}

def coverage(path):
    f = TTFont(path)
    cmap = f.getBestCmap()
    results = {}
    for name, (lo, hi) in REQUIRED.items():
        present = sum(1 for cp in range(lo, hi+1) if cp in cmap)
        total = hi - lo + 1
        results[name] = (present, total, round(100*present/total, 1))
    return results, f["name"].getDebugName(1)  # family name

files = [
    "/tmp/font-staging/HindSiliguri-Regular.ttf",
    "/tmp/font-staging/HindSiliguri-Bold.ttf",
    "/tmp/font-staging/Hind-Regular.ttf",
    "/tmp/font-staging/Hind-Bold.ttf",
]

all_ok = True
for p in files:
    res, family = coverage(p)
    print(f"\n{p}")
    print(f"  family name: {family}")
    for name, (present, total, pct) in res.items():
        flag = "OK" if pct >= 80 else ("LOW" if pct > 0 else "MISSING")
        if flag != "OK":
            all_ok = False
        print(f"  {name:18s}: {present:4d}/{total:4d} ({pct:5.1f}%)  {flag}")

sys.exit(0 if all_ok else 1)
