"""Bakes the laptop's desktop wallpaper from the marbled paper (style bible §8).

A 1993 laptop couldn't show a photo-quality image, so the wallpaper is the
marbled tile at half resolution with 256 colours and Floyd-Steinberg
dithering. The laptop draws it at 2x with nearest filtering, so each of its
pixels is 2 screen pixels: Win95.LINE, the laptop's own "one pixel". It is
turned a quarter turn from the title screen's marbling and dimmed a touch so
the desktop icons' captions read on it.

Run after changing assets/ui/frames/marbled.png:
    python3 tools/bake_laptop_wallpaper.py
"""

from pathlib import Path

from PIL import Image, ImageEnhance, ImageStat

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/ui/frames/marbled.png"
TARGET = ROOT / "assets/ui/frames/marbled_laptop.png"
## The laptop's pixel, in screen pixels (Win95.LINE).
PIXEL = 2
COLOURS = 256
## A little darker and less saturated than the paper, behind white captions.
BRIGHTNESS = 0.72
SATURATION = 0.85


def main() -> None:
    paper = Image.open(SOURCE).convert("RGB")
    paper = paper.transpose(Image.Transpose.ROTATE_90)
    paper = ImageEnhance.Brightness(paper).enhance(BRIGHTNESS)
    paper = ImageEnhance.Color(paper).enhance(SATURATION)
    small = paper.resize((paper.width // PIXEL, paper.height // PIXEL), Image.Resampling.LANCZOS)
    baked = small.quantize(colors=COLOURS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
    baked.convert("RGB").save(TARGET, optimize=True)
    print(f"{TARGET.relative_to(ROOT)}: {baked.width}x{baked.height}, {COLOURS} colours")
    # The screen's glow in the room uses this (Win95.DESKTOP).
    average = [round(c) for c in ImageStat.Stat(baked.convert("RGB")).mean]
    print("average colour: Color8(%d, %d, %d)" % tuple(average))


if __name__ == "__main__":
    main()
