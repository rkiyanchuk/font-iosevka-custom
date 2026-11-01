# /// script
# requires-python = ">=3.11"
# dependencies = ["fonttools"]
# ///
"""Enlarge ⎋ (U+238B BROKEN CIRCLE WITH NORTHWEST ARROW) in compiled Iosevka.

Iosevka draws ⎋ at ~57% of cap height in term spacing (squeezed into a
half-em cell) and ~87% in normal spacing. This replaces the glyph in both
families with the normal-spacing outline, scaled and centered on the cap
height and on each font's advance width: 100% of cap height in normal
spacing, 82% in term spacing. The term glyph is ~1.2 cells wide, so it
overlaps neighbouring glyphs slightly when it touches them.

Usage: enlarge-escape-glyph.py NORMAL_DIR TERM_DIR
Fonts are modified in place; term fonts are matched to the normal font of
the same style by filename suffix (iosevka-Light.ttf <-> iosevka-term-Light.ttf).
"""

import sys
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

ESC = 0x238B
NORMAL_HEIGHT = 1.0  # fraction of cap height
TERM_HEIGHT = 0.82


def scaled_outline(src: TTFont, adv: int, height: float):
    """Return src's ⎋ at height x cap height, centered on an advance of adv."""
    gs = src.getGlyphSet()
    name = src.getBestCmap()[ESC]
    bp = BoundsPen(gs)
    gs[name].draw(bp)
    x0, y0, x1, y1 = bp.bounds
    cap = src["OS/2"].sCapHeight
    s = height * cap / (y1 - y0)
    dx = adv / 2 - s * (x0 + x1) / 2
    dy = cap / 2 - s * (y0 + y1) / 2
    pen = TTGlyphPen(None)
    gs[name].draw(TransformPen(pen, (s, 0, 0, s, dx, dy)))
    return pen.glyph()


def replace(dst_path: Path, src: TTFont, height: float) -> None:
    dst = TTFont(dst_path)
    name = dst.getBestCmap()[ESC]
    adv = dst["hmtx"][name][0]
    glyph = scaled_outline(src, adv, height)
    glyf = dst["glyf"]
    glyf[name] = glyph
    glyph.recalcBounds(glyf)
    dst["hmtx"][name] = (adv, glyph.xMin)
    dst.save(dst_path)
    print(f"  {dst_path.name}: ⎋ -> {glyph.xMax - glyph.xMin}x{glyph.yMax - glyph.yMin} on advance {adv}")


def main(normal_dir: str, term_dir: str) -> None:
    for normal_path in sorted(Path(normal_dir).glob("iosevka-*.ttf")):
        style = normal_path.name.removeprefix("iosevka-")
        # Read the source outline before overwriting the normal font itself.
        src = TTFont(normal_path)
        term_path = Path(term_dir) / f"iosevka-term-{style}"
        if term_path.exists():
            replace(term_path, src, TERM_HEIGHT)
        replace(normal_path, src, NORMAL_HEIGHT)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])
