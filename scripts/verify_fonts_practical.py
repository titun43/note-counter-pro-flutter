#!/usr/bin/env python3
"""Verify PRACTICAL glyph coverage — commonly-used chars, not the full reserved block."""
from fontTools.ttLib import TTFont

# Practical chars actually used in everyday text
BENGALI_ESSENTIAL = (
    "অআইঈউঊঋএঐওঔ"          # vowels
    "ািীুূৃেৈোৌ"            # vowel matras
    "কখগঘঙচছজঝঞটঠডঢণতথদধন"  # consonants 1
    "পফবভমযরলশষসহ"           # consonants 2
    "ংঃঁ"                     # signs
    "ৎ ড় ঢ় য়"               # special (with spaces removed below)
    "০১২৩৪৫৬৭৮৯"            # digits
    "।॥"                     # danda
).replace(" ", "")

DEVANAGARI_ESSENTIAL = (
    "अआइईउऊऋएऐओऔ"          # vowels
    "ािीुूृेैोौ"            # matras
    "कखगघङचछजझञटठडढणतथदधन"  # consonants 1
    "पफबभमयरलवशषसह"          # consonants 2
    "ंःँ"                     # signs
    "०१२३४५६७८९"            # digits
    "।॥"                     # danda
)

LATIN_SAMPLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 .,-!'?:/$@"

files = {
    "/tmp/font-staging/HindSiliguri-Regular.ttf": ("Hind Siliguri", BENGALI_ESSENTIAL, "Bengali"),
    "/tmp/font-staging/HindSiliguri-Bold.ttf":    ("Hind Siliguri", BENGALI_ESSENTIAL, "Bengali"),
    "/tmp/font-staging/Hind-Regular.ttf":         ("Hind",         DEVANAGARI_ESSENTIAL, "Devanagari"),
    "/tmp/font-staging/Hind-Bold.ttf":            ("Hind",         DEVANAGARI_ESSENTIAL, "Devanagari"),
}

all_ok = True
for path, (family, script_chars, script_name) in files.items():
    f = TTFont(path)
    cmap = f.getBestCmap()

    # Latin check (every font must have Latin)
    lat_missing = [c for c in LATIN_SAMPLE if ord(c) not in cmap]
    # Script check
    scr_missing = [c for c in script_chars if ord(c) not in cmap]

    lat_ok = not lat_missing
    scr_ok = not scr_missing
    if not (lat_ok and scr_ok):
        all_ok = False

    print(f"\n{path}")
    print(f"  family: {family}")
    print(f"  Latin:    {'OK' if lat_ok else 'MISSING ' + repr(''.join(lat_missing))}")
    print(f"  {script_name}: {'OK (' + str(len(script_chars)) + ' chars)' if scr_ok else 'MISSING ' + repr(''.join(scr_missing))}")

print("\n=== RESULT:", "ALL PRACTICAL CHARS PRESENT" if all_ok else "GAPS FOUND", "===")
