"""Bake the leaded glass for the shop windows (assets/store/leaded_glass).

Diamond quarries of slightly uneven clear glass held in dark lead came,
sized for one window pane (StoreBuilder.WINDOW_SIZE, 1.8 x 1.5 m, split by
the transom into two panes of 1.8 x 0.75 m). The window glass is unshaded
and tinted by the DayCycle's sky colour, so the glass here is near white and
the lead near black: the glass glows with the daylight, the lead stays dark.
Clear glass only: the style bible keeps coloured light for the cards.

Run: python3 tools/bake_leaded_glass.py
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets/store/leaded_glass/albedo.png"
PX_PER_M = 600
PANE = (1.8, 0.75)
ACROSS = 10          # diamonds across one pane
DOWN = 3.5           # diamonds down one pane (half diamonds at top and bottom)
LEAD = 7             # lead line width in px
LEAD_COLOUR = (22, 20, 18)


def main() -> None:
    random.seed(7)
    w, h = round(PANE[0] * PX_PER_M), round(PANE[1] * PX_PER_M)
    cw, ch = w / ACROSS, h / DOWN
    glass = Image.new("RGB", (w, h))
    draw = ImageDraw.Draw(glass)
    # Each quarry its own faint shade, like old hand-made glass.
    for i in range(-1, ACROSS + 2):
        for j in range(-1, int(DOWN) + 3):
            for (ox, oy) in ((0, 0), (0.5, 0.5)):
                cx, cy = (i + ox) * cw, (j + oy) * ch
                v = random.uniform(0.84, 1.0)
                warm = random.uniform(-0.02, 0.02)
                colour = tuple(int(255 * min(1, max(0, v + d))) for d in (warm, 0.0, -warm - 0.01))
                draw.polygon([(cx, cy - ch / 2), (cx + cw / 2, cy), (cx, cy + ch / 2), (cx - cw / 2, cy)], fill=colour)
    # Faint streaks and seeds in the glass.
    streaks = Image.new("L", (w, h), 0)
    sd = ImageDraw.Draw(streaks)
    for _ in range(140):
        x, y = random.uniform(0, w), random.uniform(0, h)
        length = random.uniform(20, 90)
        a = random.uniform(-0.4, 0.4)
        sd.line([(x, y), (x + length * math.cos(a), y + length * math.sin(a))], fill=random.randint(10, 26), width=2)
    streaks = streaks.filter(ImageFilter.GaussianBlur(2))
    glass = Image.composite(Image.new("RGB", (w, h), (255, 255, 255)), glass, streaks)
    # Lead came along both diagonals, and round the edge of the pane.
    draw = ImageDraw.Draw(glass)
    for k in range(-ACROSS * 2, ACROSS * 3):
        x0 = k * cw + cw / 2
        draw.line([(x0, 0), (x0 + w * 0 + (h / ch) * cw / 2 * 2, h)], fill=LEAD_COLOUR, width=LEAD)
        draw.line([(x0, 0), (x0 - (h / ch) * cw / 2 * 2, h)], fill=LEAD_COLOUR, width=LEAD)
    draw.rectangle([0, 0, w - 1, h - 1], outline=LEAD_COLOUR, width=LEAD + 3)
    glass = glass.filter(ImageFilter.GaussianBlur(0.6))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    glass.save(OUT)
    print(f"{OUT} {glass.size}")


if __name__ == "__main__":
    main()
