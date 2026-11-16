#!/usr/bin/env python3
"""
Shrink "big" content text across the 5 main tab screens (+ group detail)
so the in-page content reads smaller / less heavy.

Option B (medium, ~15-20% reduction) — only sizes >= 14 are reduced;
small labels (<=13) are left untouched (already compact).

The hero Grand Total on the Counter page (home_screen) is EXCLUDED:
the user explicitly asked for that to stay big in v3.62.4 and confirmed
"sob thik ache". We identify it by the `_grandTotal.toStringAsFixed(0)`
substring on the same line as its fontSize.
"""
import re
from pathlib import Path

BASE = Path('/home/z/my-project/lib/screens')
FILES = [
    'home_screen.dart',
    'khata_screen.dart',
    'smart_pay_screen.dart',
    'bills_screen.dart',
    'group_split_screen.dart',
    'group_detail_screen.dart',
]

# Reduction map: only sizes >= 14. Sizes <= 13 stay as-is.
SIZE_MAP = {
    26: 22,
    24: 20,
    22: 18,
    21: 18,
    20: 17,
    18: 16,
    16: 14,
    15: 13,
    14: 13,
}

# Skip fontSize reduction on any line containing this (the hero total).
EXCLUDE_SUBSTR = '_grandTotal.toStringAsFixed(0)'

PAT = re.compile(r'fontSize:\s*(\d+)')


def process(path: Path):
    lines = path.read_text(encoding='utf-8').splitlines(keepends=True)
    changes = 0
    skipped = 0
    detail = {}
    for i, line in enumerate(lines):
        # Look-back: if any of the previous 3 lines carries the hero
        # substring, this fontSize belongs to the hero Text — keep it.
        lookback = ''.join(lines[max(0, i - 3):i])
        if EXCLUDE_SUBSTR in line or EXCLUDE_SUBSTR in lookback:
            if 'fontSize:' in line:
                skipped += 1
            continue

        def repl(m):
            nonlocal changes
            old = int(m.group(1))
            new = SIZE_MAP.get(old)
            if new is None:
                return m.group(0)
            changes += 1
            detail[old] = detail.get(old, 0) + 1
            return f'fontSize: {new}'

        lines[i] = PAT.sub(repl, line)
    path.write_text(''.join(lines), encoding='utf-8')
    return changes, skipped, detail


def main():
    total_changes = 0
    total_skipped = 0
    all_detail = {}
    for name in FILES:
        p = BASE / name
        if not p.exists():
            print(f'SKIP (missing): {name}')
            continue
        c, s, d = process(p)
        total_changes += c
        total_skipped += s
        for k, v in d.items():
            all_detail[k] = all_detail.get(k, 0) + v
        print(f'{name}: {c} reduced, {s} hero-line(s) skipped, map={d}')
    print(f'\nTOTAL: {total_changes} fontSize reductions, {total_skipped} hero line(s) kept')
    print('Reductions by old size:')
    for k in sorted(all_detail, reverse=True):
        print(f'  {k} -> {SIZE_MAP[k]}: {all_detail[k]}x')


if __name__ == '__main__':
    main()
