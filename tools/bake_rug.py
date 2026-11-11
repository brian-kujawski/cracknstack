"""Bakes the library rug under the tables (room plan phase 1).

A calm, dark field so cards lying on it stay the brightest thing, with the
five colours (style bible §4.4) muted into a running border of small lozenges
and a five-lobed medallion in the middle, white at the top and on round the
wheel: white, blue, black, red, green. The medallion is a rosette of
pointed petals, never circles: five coloured discs in a ring would read as the
cards' own colour-wheel symbols (bible §11). Writes assets/store/rug/albedo.jpg;
StoreBuilder lays it RUG_SIZE metres across.

    python3 tools/bake_rug.py
"""

from pathlib import Path
import math
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
TARGET = ROOT / "assets/store/rug"
SIZE_M = (5.0, 4.6)        # StoreBuilder.RUG_SIZE
PX_PER_M = 320
FIELD = (40, 36, 48)       # deep indigo-charcoal
FIELD_INNER = (48, 40, 50)
GUARD = (150, 128, 92)     # muted gold guard stripes
BAND = (30, 27, 36)
# Bible §4.4 accents, then muted toward the field so they sit in the wool.
ACCENTS = ["f4ecd0", "5b9bd5", "9c8ca8", "d9643e", "5fa86a"]
MUTE = 0.42


def rgb(hex_colour: str) -> tuple:
    return tuple(int(hex_colour[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def main() -> None:
    w, h = round(SIZE_M[0] * PX_PER_M), round(SIZE_M[1] * PX_PER_M)
    accents = [mix(rgb(c), FIELD, MUTE) for c in ACCENTS]
    img = Image.new("RGB", (w, h), FIELD)
    d = ImageDraw.Draw(img)
    m = lambda metres: round(metres * PX_PER_M)
    # Border: outer band, gold guard, lozenge band, gold guard, inner field.
    band_out, guard, band = m(0.06), m(0.018), m(0.26)
    d.rectangle([0, 0, w - 1, h - 1], fill=BAND)
    d.rectangle([band_out, band_out, w - 1 - band_out, h - 1 - band_out], fill=GUARD)
    inset = band_out + guard
    d.rectangle([inset, inset, w - 1 - inset, h - 1 - inset], fill=BAND)
    inner = inset + band
    d.rectangle([inner, inner, w - 1 - inner, h - 1 - inner], fill=GUARD)
    d.rectangle([inner + guard, inner + guard, w - 1 - inner - guard, h - 1 - inner - guard], fill=FIELD_INNER)
    # Lozenges round the band, cycling through the five colours.
    mid = inset + band // 2
    step = m(0.2)
    r = m(0.075)
    i = 0
    for x in range(inset + step // 2, w - inset, step):
        for y in (mid, h - 1 - mid):
            _lozenge(d, x, y, r, accents[i % 5]); i += 1
    for y in range(inset + step // 2 + step, h - inset - step // 2, step):
        for x in (mid, w - 1 - mid):
            _lozenge(d, x, y, r, accents[i % 5]); i += 1
    # A faint tone-on-tone lattice over the field.
    lattice = mix(FIELD_INNER, GUARD, 0.08)
    cell = m(0.36)
    x0, y0, x1, y1 = inner + guard, inner + guard, w - 1 - inner - guard, h - 1 - inner - guard
    field = Image.new("RGB", (x1 - x0 + 1, y1 - y0 + 1), FIELD_INNER)
    fd = ImageDraw.Draw(field)
    fh = field.height
    for gx in range(-fh, field.width + fh, cell):
        fd.line([(gx, 0), (gx + fh, fh)], fill=lattice, width=2)
        fd.line([(gx, fh), (gx + fh, 0)], fill=lattice, width=2)
    img.paste(field, (x0, y0))
    # The medallion: a gold ring round a rosette of five pointed petals.
    cx, cy = w // 2, h // 2
    ring = m(0.66)
    d.ellipse([cx - ring, cy - ring, cx + ring, cy + ring], fill=BAND, outline=GUARD, width=guard)
    for k in range(5):
        a = -math.pi / 2 + k * 2 * math.pi / 5
        _petal(d, cx, cy, a, m(0.12), m(0.56), m(0.17), accents[k])
    for k in range(5):
        a = -math.pi / 2 + (k + 0.5) * 2 * math.pi / 5
        _petal(d, cx, cy, a, m(0.1), m(0.34), m(0.07), GUARD)
    d.ellipse([cx - m(0.1), cy - m(0.1), cx + m(0.1), cy + m(0.1)], fill=GUARD)
    d.ellipse([cx - m(0.05), cy - m(0.05), cx + m(0.05), cy + m(0.05)], fill=BAND)
    # Quarter rosettes in the field's corners, gold only.
    for (qx, qy, start) in [(x0, y0, 0), (x1, y0, 90), (x1, y1, 180), (x0, y1, 270)]:
        q = m(0.42)
        d.arc([qx - q, qy - q, qx + q, qy + q], start, start + 90, fill=GUARD, width=guard)
        for k in range(3):
            a = math.radians(start + 22.5 + k * 22.5)
            _petal(d, qx, qy, a, m(0.04), m(0.34), m(0.06), mix(GUARD, FIELD_INNER, 0.35))
    # Wool: a little blur, then a fine knotted grain and soft wear.
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    rng = random.Random(5)
    px = img.load()
    for y in range(h):
        for x in range(w):
            n = rng.uniform(-7, 7) + 4 * math.sin(x * 0.9) * math.sin(y * 0.9)
            r_, g_, b_ = px[x, y]
            px[x, y] = (max(0, min(255, round(r_ + n))), max(0, min(255, round(g_ + n))), max(0, min(255, round(b_ + n))))
    TARGET.mkdir(parents=True, exist_ok=True)
    img.save(TARGET / "albedo.jpg", quality=90)
    print(f"{TARGET.relative_to(ROOT)}/albedo.jpg: {w}x{h} for {SIZE_M[0]} x {SIZE_M[1]} m")


def _lozenge(d, x, y, r, colour) -> None:
    d.polygon([(x, y - r), (x + r * 0.7, y), (x, y + r), (x - r * 0.7, y)], fill=colour)


def _petal(d, cx, cy, angle, r0, r1, half_width, colour) -> None:
    """A pointed petal from r0 to r1 out along `angle`, widest at its middle."""
    ux, uy = math.cos(angle), math.sin(angle)
    vx, vy = -uy, ux
    points = []
    for i in range(13):
        t = i / 12
        r = r0 + (r1 - r0) * t
        wdt = half_width * math.sin(math.pi * t) ** 0.8
        points.append((cx + ux * r + vx * wdt, cy + uy * r + vy * wdt))
    for i in range(12, -1, -1):
        t = i / 12
        r = r0 + (r1 - r0) * t
        wdt = half_width * math.sin(math.pi * t) ** 0.8
        points.append((cx + ux * r - vx * wdt, cy + uy * r - vy * wdt))
    d.polygon(points, fill=colour)



if __name__ == "__main__":
    main()
