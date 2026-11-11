"""Bakes the library's floorboards (room plan phase 1) from the tables' walnut.

Cuts staggered planks out of assets/store/table_wood (ambientCG Wood066, CC0),
shades each a little differently, and grooves the seams between them, into a
seamless tile at assets/store/floorboards/ (albedo, normal, roughness) that
StoreBuilder lays FLOOR_SIZE metres square. Planks run along x.

    python3 tools/bake_floorboards.py
"""

from pathlib import Path
import random

from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/store/table_wood"
TARGET = ROOT / "assets/store/floorboards"
TILE = 1024          # pixels in the tile
METRES = 1.68        # metres the tile covers (StoreBuilder.FLOOR_SIZE)
SOURCE_METRES = 0.6  # metres the walnut source covers (TABLE_WOOD_SIZE)
ROWS = 16            # planks across the tile (divides TILE): 10.5 cm boards
SEAM = 2             # seam width in pixels
SEED = 11


def main() -> None:
    rng = random.Random(SEED)
    albedo_src = Image.open(SOURCE / "albedo.jpg").convert("RGB")
    normal_src = Image.open(SOURCE / "normal.jpg").convert("RGB")
    rough_src = Image.open(SOURCE / "roughness.jpg").convert("L")
    # The source at the floor's scale: one source tile is 0.6 m.
    scale = TILE / METRES * SOURCE_METRES / albedo_src.width
    size = (round(albedo_src.width * scale), round(albedo_src.height * scale))
    albedo_src = albedo_src.resize(size, Image.Resampling.LANCZOS)
    normal_src = normal_src.resize(size, Image.Resampling.LANCZOS)
    rough_src = rough_src.resize(size, Image.Resampling.LANCZOS)
    # The source tiles seamlessly: lay it 4 x 2 so a long plank fits in it.
    albedo_src, normal_src, rough_src = (_tiled(im, 4, 2) for im in (albedo_src, normal_src, rough_src))
    size = albedo_src.size

    albedo = Image.new("RGB", (TILE, TILE))
    normal = Image.new("RGB", (TILE, TILE), (128, 128, 255))
    rough = Image.new("L", (TILE, TILE))
    row_h = TILE // ROWS
    for row in range(ROWS):
        y = row * row_h
        x = rng.randrange(TILE)  # where this row's first joint falls
        covered = 0
        while covered < TILE:
            length = rng.randrange(int(TILE * 0.45), int(TILE * 0.85))
            length = min(length, TILE - covered)
            sx = rng.randrange(size[0] - length) if size[0] > length else 0
            sy = rng.randrange(size[1] - row_h)
            box = (sx, sy, sx + length, sy + row_h)
            tone = rng.uniform(0.82, 1.1)
            warm = rng.uniform(0.92, 1.06)
            plank = ImageEnhance.Brightness(albedo_src.crop(box)).enhance(tone)
            plank = ImageEnhance.Color(plank).enhance(warm)
            # Paste with wrap-around so the tile stays seamless along x.
            for dx in (0, -TILE):
                px = (x + covered) % TILE + dx
                albedo.paste(plank, (px, y))
                normal.paste(normal_src.crop(box), (px, y))
                rough.paste(rough_src.crop(box), (px, y))
            # The joint at this plank's start.
            jx = (x + covered) % TILE
            _seam(albedo, normal, rough, (jx, y, jx + SEAM, y + row_h), vertical=True)
            covered += length
        _seam(albedo, normal, rough, (0, y, TILE, y + SEAM), vertical=False)

    TARGET.mkdir(parents=True, exist_ok=True)
    albedo.save(TARGET / "albedo.jpg", quality=90)
    normal.save(TARGET / "normal.jpg", quality=92)
    rough.save(TARGET / "roughness.jpg", quality=90)
    print(f"{TARGET.relative_to(ROOT)}: {TILE}px over {METRES} m, {ROWS} boards")


def _tiled(image: Image.Image, across: int, down: int) -> Image.Image:
    out = Image.new(image.mode, (image.width * across, image.height * down))
    for i in range(across):
        for j in range(down):
            out.paste(image, (i * image.width, j * image.height))
    return out


def _seam(albedo, normal, rough, box, vertical: bool) -> None:
    """A dark, rough groove between boards, its sides tipped in the normal map."""
    x0, y0, x1, y1 = box
    for x in range(x0, min(x1, TILE)):
        for y in range(y0, min(y1, TILE)):
            r, g, b = albedo.getpixel((x, y))
            albedo.putpixel((x, y), (r * 2 // 5, g * 2 // 5, b * 2 // 5))
            rough.putpixel((x, y), 235)
            first = (x == x0) if vertical else (y == y0)
            if vertical:
                normal.putpixel((x, y), (90, 128, 240) if first else (166, 128, 240))
            else:
                normal.putpixel((x, y), (128, 166, 240) if first else (128, 90, 240))


if __name__ == "__main__":
    main()
