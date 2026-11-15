#!/usr/bin/env python3
"""Minimal removal of `fontFamily: 'KhataHandwriting'` from lib/*.dart.

Strategy: drop only the fontFamily parameter; never reflow surrounding code.
- Lines that are JUST the param (with optional `,` or `),`) → drop / shrink.
- Inline occurrences → remove the fragment (and its leading `,` if any).
"""
import re
from pathlib import Path

LIB_DIR = Path("/home/z/my-project/lib")

# --- Drop-the-whole-line patterns ---
DROP_PATTERNS = [
    #   fontFamily: 'KhataHandwriting',
    re.compile(r"^\s*fontFamily:\s*'KhataHandwriting'\s*,?\s*$"),
    #   fontFamily: isLabel || isHeader ? null : 'KhataHandwriting',
    re.compile(
        r"^\s*fontFamily:\s*isLabel\s*\|\|\s*isHeader\s*\?\s*null\s*:\s*'KhataHandwriting'\s*,?\s*$"
    ),
    #   fontFamily: (isLabel || isHeader) ? null : 'KhataHandwriting',
    re.compile(
        r"^\s*fontFamily:\s*\(isLabel\s*\|\|\s*isHeader\)\s*\?\s*null\s*:\s*'KhataHandwriting'\s*,?\s*$"
    ),
]

# --- Shrink-the-line patterns (keep surrounding structure) ---
#   <indent>fontFamily: 'KhataHandwriting'),<rest>   →   <indent>),<rest>
SHRINK_PAREN = re.compile(r"^(\s*)fontFamily:\s*'KhataHandwriting'\)(.*)$")

# --- Inline-fragment removal patterns (operate within a line) ---
INLINE_PATTERNS = [
    # TextStyle(fontFamily: 'KhataHandwriting', X   →   TextStyle(X
    (re.compile(r"TextStyle\(fontFamily:\s*'KhataHandwriting',\s*"), "TextStyle("),
    # , fontFamily: (isLabel || isHeader) ? null : 'KhataHandwriting',  →  ,
    (re.compile(r",\s*fontFamily:\s*\(isLabel\s*\|\|\s*isHeader\)\s*\?\s*null\s*:\s*'KhataHandwriting'\s*,"), ","),
    # , fontFamily: isLabel || isHeader ? null : 'KhataHandwriting',  →  ,
    (re.compile(r",\s*fontFamily:\s*isLabel\s*\|\|\s*isHeader\s*\?\s*null\s*:\s*'KhataHandwriting'\s*,"), ","),
    # , fontFamily: 'KhataHandwriting')  →  )
    (re.compile(r",\s*fontFamily:\s*'KhataHandwriting'\)"), ")"),
    # , fontFamily: 'KhataHandwriting',  →  ,
    (re.compile(r",\s*fontFamily:\s*'KhataHandwriting'\s*,"), ","),
]

changed_files = []
for dart in sorted(LIB_DIR.rglob("*.dart")):
    src = dart.read_text(encoding="utf-8")
    out = []
    for line in src.splitlines(keepends=True):
        # 1. Drop-the-line patterns
        if any(p.match(line) for p in DROP_PATTERNS):
            continue
        # 2. Shrink: standalone line ending with `),` → just `),`
        m = SHRINK_PAREN.match(line)
        if m:
            newline = "\n" if line.endswith("\n") else ""
            out.append(f"{m.group(1)}){m.group(2)}{newline}")
            continue
        # 3. Inline fragment removal
        for pat, repl in INLINE_PATTERNS:
            line = pat.sub(repl, line)
        out.append(line)
    new = "".join(out)
    if new != src:
        dart.write_text(new, encoding="utf-8")
        changed_files.append(str(dart.relative_to(LIB_DIR.parent)))

print(f"Files changed: {len(changed_files)}")
for f in changed_files:
    print(f"  {f}")
