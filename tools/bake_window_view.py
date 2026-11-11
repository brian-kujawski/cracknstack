"""Bake quick placeholder pictures for the view out of the shop windows.

Three layers, nearest first, for shaders/window_view.gdshader:
  near.png  railings, a hedge and a lamp post just outside (alpha)
  mid.png   the houses across the street, on the far pavement (alpha)
  far.png   the sky, with distant roofs, a spire and treetops (opaque)
Each spans the rect given for it in shaders/window_view.gdshader (metres
in room space: left, bottom, width, height); px per metre is fixed here.
These are stand-ins: the user will hand-draw replacements at the same
sizes. Muted and hazy on purpose: the view mustn't pull focus from the cards.

Run: python3 tools/bake_window_view.py
"""
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets/store/window_view"
random.seed(11)


def box(d, corners, fill):
    """A rectangle between two corners, given in either order."""
    (x0, y0), (x1, y1) = corners
    d.rectangle([min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)], fill=fill)


def canvas(rect, ppm, mode="RGBA", fill=(0, 0, 0, 0)):
    w, h = int(rect[2] * ppm), int(rect[3] * ppm)
    img = Image.new(mode, (w, h), fill)
    # Room metres -> pixel coordinates.
    def px(x, y):
        return ((x - rect[0]) * ppm, h - (y - rect[1]) * ppm)
    return img, ImageDraw.Draw(img), px


def far():
    rect = (-50.0, -4.0, 112.0, 42.0)
    img, d, px = canvas(rect, 18, "RGB")
    w, h = img.size
    top, horizon = (150, 166, 182), (222, 212, 192)
    for y in range(h):
        t = min(1.0, max(0.0, (y / h - 0.1) / 0.8))
        d.line([(0, y), (w, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, horizon)))
    # Distant treeline, roofs and a spire, hazy blue-grey.
    haze = (150, 158, 160)
    x = rect[0]
    while x < rect[0] + rect[2]:
        width = random.uniform(4, 9)
        height = random.uniform(9, 14)
        box(d, [px(x, -4), px(x + width, height)], fill=haze)
        d.polygon([px(x, height), px(x + width / 2, height + random.uniform(2, 4)), px(x + width, height)], fill=haze)
        x += width
    for _ in range(14):
        cx, cy = random.uniform(rect[0], rect[0] + rect[2]), random.uniform(12, 16)
        r = random.uniform(2.5, 5)
        d.ellipse([px(cx - r, cy + r), px(cx + r, cy - r)], fill=(138, 150, 142))
    sx = 18.0
    box(d, [px(sx - 1.2, 0), px(sx + 1.2, 20)], fill=(140, 148, 152))
    d.polygon([px(sx - 1.4, 20), px(sx, 30), px(sx + 1.4, 20)], fill=(140, 148, 152))
    return img.filter(ImageFilter.GaussianBlur(3))


def mid():
    rect = (-14.0, -1.0, 40.0, 16.0)
    img, d, px = canvas(rect, 40)
    box(d, [px(rect[0], -1), px(rect[0] + rect[2], 0.0)], fill=(118, 114, 108, 255))
    bricks = [(132, 92, 76), (150, 120, 96), (176, 160, 136), (120, 104, 96), (160, 136, 112)]
    x = rect[0]
    while x < rect[0] + rect[2]:
        width = random.uniform(5, 7.5)
        height = random.uniform(8, 11)
        colour = random.choice(bricks)
        box(d, [px(x, 0), px(x + width - 0.05, height)], fill=colour + (255,))
        # A parapet or a slate roof.
        if random.random() < 0.5:
            box(d, [px(x - 0.1, height), px(x + width + 0.05, height + 0.5)], fill=(96, 90, 86, 255))
        else:
            d.polygon([px(x, height), px(x + width / 2, height + 2.2), px(x + width - 0.05, height)], fill=(78, 80, 86, 255))
        # Windows: rows of tall sashes, a door at street level.
        cols = int(width // 1.6)
        for row, wy in enumerate([1.2, 4.2, 7.0]):
            if wy + 1.8 > height:
                break
            for c in range(cols):
                wx = x + 0.6 + c * (width - 1.2) / max(cols, 1)
                lit = random.random() < 0.25
                fill = (214, 196, 150, 255) if lit else (58, 62, 70, 255)
                box(d, [px(wx, wy), px(wx + 0.8, wy + 1.6 if row else 1.8)], fill=fill)
                box(d, [px(wx - 0.05, wy - 0.12), px(wx + 0.85, wy)], fill=(196, 188, 170, 255))
        box(d, [px(x + width - 1.6, 0), px(x + width - 0.7, 2.2)], fill=(52, 60, 58, 255))
        x += width
    return img.filter(ImageFilter.GaussianBlur(1.5))


def near():
    rect = (-1.0, -0.6, 14.0, 3.5)
    img, d, px = canvas(rect, 120)
    box(d, [px(rect[0], -0.6), px(rect[0] + rect[2], 0.0)], fill=(126, 122, 116, 255))
    iron = (30, 30, 32, 255)
    # Area railings along the pavement edge.
    box(d, [px(rect[0], 0.95), px(rect[0] + rect[2], 1.0)], fill=iron)
    box(d, [px(rect[0], 0.1), px(rect[0] + rect[2], 0.14)], fill=iron)
    x = rect[0]
    while x < rect[0] + rect[2]:
        box(d, [px(x, 0.0), px(x + 0.02, 1.08)], fill=iron)
        d.polygon([px(x - 0.02, 1.08), px(x + 0.01, 1.16), px(x + 0.04, 1.08)], fill=iron)
        x += 0.12
    # Hedge clumps behind the railings.
    for cx in [1.8, 2.6, 8.4, 9.6, 10.3]:
        for _ in range(30):
            r = random.uniform(0.15, 0.3)
            ox, oy = cx + random.uniform(-0.6, 0.6), random.uniform(0.2, 0.75)
            g = random.randint(64, 92)
            d.ellipse([px(ox - r, oy + r), px(ox + r, oy - r)], fill=(g - 20, g, g - 30, 255))
    # A lamp post between the windows.
    lx = 6.0
    box(d, [px(lx - 0.05, 0), px(lx + 0.05, 3.2)], fill=iron)
    return img.filter(ImageFilter.GaussianBlur(1.0))


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, make in [("near", near), ("mid", mid), ("far", far)]:
        image = make()
        image.save(OUT / f"{name}.png")
        print(name, image.size)
    (OUT / "SOURCE.txt").write_text(
        "Placeholder window view, baked by tools/bake_window_view.py.\n"
        "To be replaced by hand-drawn art at the same sizes and placement:\n"
        "near.png 1680x420 (14 x 3.5 m, alpha), mid.png 1600x640 (40 x 16 m, alpha),\n"
        "far.png 2016x756 (112 x 42 m, opaque). Placement: shaders/window_view.gdshader\n"
        "(*_rect = left, bottom, width, height in room metres; *_depth = metres outside the wall).\n")
