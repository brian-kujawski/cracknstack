#!/usr/bin/env python3
"""Packages a playtest build: the exported game plus the card data for its
first few chapters, in one folder ready to zip or push to itch.io.

An exported game reads its card data from a data/real folder beside the
executable (CardDatabase.real_path), because data/real has a .gdignore and
the export packs none of it. This script writes that folder, cut down to the
sets of the first N chapters in data/chapters.txt:

  builds/alpha/CrackAndStack.exe                the export (copied from --game)
  builds/alpha/data/real/cards.json      only the chosen chapters' sets, with
                                         "build" set, so the game ends the
                                         last chapter with a note (EndOfBuildNote)
                                         instead of the ending
  builds/alpha/data/real/images/<set>/   their large faces
  builds/alpha/data/real/near/<set>/     their near faces
  builds/alpha/data/real/faces/          a far-face atlas of just their cards
  builds/alpha/data/real/back.jpg        the card back

Run on the machine that has the imported card images, after exporting the
game from Godot (Project > Export > Windows Desktop > Export Project; the
preset writes builds/windows/CrackAndStack.exe):

  python tools/package_alpha.py --chapters 2                 # Chapters 1-2 into builds/alpha
  python tools/package_alpha.py --chapters 2 --zip           # and builds/alpha.zip
  python tools/package_alpha.py --chapters 1 --name "Alpha 1" --game builds/windows --out builds/alpha1

Copies nothing twice: a file already in --out with the same size and time is
left alone, so a second run only copies what changed. Needs Pillow and NumPy
(python -m pip install pillow numpy) to pack the far faces.
"""

import argparse
import json
import shutil
import sys
from pathlib import Path

import import_scryfall as importer

ROOT = Path(__file__).resolve().parent.parent
CHAPTERS = ROOT / "data" / "chapters.txt"
DEFAULT_GAME = ROOT / "builds" / "windows"
DEFAULT_OUT = ROOT / "builds" / "alpha"


def parse_chapters(text):
    """The chapters in data/chapters.txt, each a list of upper-case set codes,
    by the same rules as the game's Chapters.parse: a line starting with
    "Chapter" begins one, "#" starts a comment, a set listed twice keeps its
    first place."""
    chapters, seen = [], set()
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if line.lower().startswith("chapter"):
            chapters.append([])
            continue
        code = line.split()[0].upper()
        if chapters and code not in seen:
            seen.add(code)
            chapters[-1].append(code)
    return chapters


def cut_down(data, codes, build):
    """The card file with only the sets in `codes` (and their cards, in the
    same order), marked as the playtest build `build`. Its faces are left for
    pack_faces to fill in."""
    kept = dict(data)
    kept["sets"] = [s for s in data["sets"] if s["code"].upper() in codes]
    kept["cards"] = [row for row in data["cards"] if row[0].upper() in codes]
    kept["build"] = build
    return kept


def same_file(source, target):
    if not target.exists():
        return False
    a, b = source.stat(), target.stat()
    return a.st_size == b.st_size and int(a.st_mtime) == int(b.st_mtime)


def copy_file(source, target):
    """Copies one file unless an identical one is already there; returns
    whether it copied."""
    if same_file(source, target):
        return False
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    return True


def copy_card_files(data, source, target):
    """Copies each kept card's large and near face, and the card back.
    Returns (copied, skipped) counts."""
    paths = [data["back"]] if data.get("back") else []
    near = data.get("faces", {}).get("near")
    for row in data["cards"]:
        image = row[6]
        if not image:
            continue
        paths.append(image)
        if near:
            # images/<folder>/<number>.jpg -> near/<folder>/<number>.dds.gz
            folder, number = image.split("/")[1], Path(image).stem
            paths.append(near.format(set=folder, number=number))
    copied = 0
    for done, path in enumerate(paths):
        if not (source / path).exists():
            sys.exit(f"Missing {source / path}: run tools/import_scryfall.py on this machine first.")
        copied += copy_file(source / path, target / path)
        if done % 200 == 0 or done == len(paths) - 1:
            print(f"\rcard images: {done + 1}/{len(paths)}", end="", flush=True)
    print()
    return copied, len(paths) - copied


def pack_faces(data, target):
    """Packs a far-face atlas of just the kept cards (slot i is card i, so
    the whole game's atlas can't be reused) into target/faces, from the large
    faces already copied there."""
    importer.check_packing_modules()
    # pack_atlas finds each face at image_path(card), images/<folder>/<number>.jpg.
    cards = [{"set": importer.code_of_folder(row[6].split("/")[1]), "collector_number": Path(row[6]).stem}
             for row in data["cards"]]
    faces = importer.pack_atlas(cards, target)
    old = data.get("faces", {})
    for key in ("near", "near_size"):
        if key in old:
            faces[key] = old[key]
    data["faces"] = faces


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--chapters", type=int, required=True, help="ship Chapters 1 through this one")
    parser.add_argument("--name", default="Alpha", help='the build\'s name, shown in the end-of-build note (default "Alpha")')
    parser.add_argument("--game", type=Path, default=DEFAULT_GAME, help="the exported game's folder (default builds/windows)")
    parser.add_argument("--data", type=Path, default=importer.DEFAULT_OUT, help="the imported card data (default data/real)")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="where to write the build (default builds/alpha)")
    parser.add_argument("--zip", action="store_true", help="also write <out>.zip")
    args = parser.parse_args(argv)

    chapters = parse_chapters(CHAPTERS.read_text(encoding="utf-8"))
    if not 1 <= args.chapters <= len(chapters):
        sys.exit(f"--chapters must be 1 to {len(chapters)} (data/chapters.txt has {len(chapters)})")
    data = json.loads((args.data / "cards.json").read_text(encoding="utf-8"))
    if "faces" not in data:
        sys.exit(f"{args.data / 'cards.json'} has no card images: import them first.")
    loaded = {s["code"].upper() for s in data["sets"]}
    wanted = [code for chapter in chapters[:args.chapters] for code in chapter]
    missing = [code for code in wanted if code not in loaded]
    if missing:
        print(f"Not imported, so not in the build: {', '.join(missing)}")
    codes = {code for code in wanted if code in loaded}
    if not codes:
        sys.exit("None of those chapters' sets are imported.")

    exes = sorted(args.game.glob("*.exe")) if args.game.is_dir() else []
    if not exes:
        sys.exit(f"No exported game in {args.game}: export it from Godot first "
                 "(Project > Export > Windows Desktop > Export Project).")

    kept = cut_down(data, codes, args.name)
    real = args.out / "data" / "real"
    real.mkdir(parents=True, exist_ok=True)
    for path in args.game.iterdir():
        if path.is_file():
            copy_file(path, args.out / path.name)
    copied, skipped = copy_card_files(kept, args.data, real)
    pack_faces(kept, real)
    importer.write_card_file(kept, real / "cards.json")

    size = sum(p.stat().st_size for p in args.out.rglob("*") if p.is_file())
    print(f"Wrote {args.name}: {len(kept['sets'])} sets, {len(kept['cards'])} cards "
          f"({copied} files copied, {skipped} already there), {size / 1e6:.0f} MB in {args.out}")
    if args.zip:
        archive = shutil.make_archive(str(args.out), "zip", root_dir=args.out)
        print(f"Zipped to {archive} ({Path(archive).stat().st_size / 1e6:.0f} MB)")


if __name__ == "__main__":
    main()
