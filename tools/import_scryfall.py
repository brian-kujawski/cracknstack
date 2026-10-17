#!/usr/bin/env python3
"""Imports real card data from Scryfall into data/real/ (plan §5).

Writes, for the chosen sets (Khans of Tarkir only, by default):

  data/real/cards.json           the same card data format as the placeholder
                                 file, plus face atlas, image paths and credits
  data/real/faces/page_N.png     small faces packed into atlas pages
  data/real/images/<set>/N.jpg   large faces for the inspect view

Only the base version of each card is kept: one printing per collector
number, plain whole numbers from 1 to the set's printed size, no promos,
variants, showcase or borderless frames (plan §3.3). The import stops if a
set's kept cards don't run 1..N with no gaps.

Usage, from the project root:

  python3 -m pip install pillow        # once, for packing the atlas
  python3 tools/import_scryfall.py                 # Khans of Tarkir
  python3 tools/import_scryfall.py ktk frf         # several sets
  python3 tools/import_scryfall.py --bulk default-cards.json ktk

Without --bulk, card metadata comes from Scryfall's search API (two requests
for one set). For many sets, download the "Default Cards" bulk file from
https://scryfall.com/docs/api/bulk-data once and pass it with --bulk.

Re-runnable: downloaded images are cached in data/real/images/ and only
missing ones are fetched. We follow Scryfall's API guidelines: a descriptive
User-Agent, at least 100 ms between requests, everything cached, the card
images used whole (artist credit and copyright line intact), and no paywall.
"""

import argparse
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://api.scryfall.com"
USER_AGENT = "Pickup/0.1 (free private fan game; https://github.com/brian-kujawski/pickup)"
REQUEST_GAP = 0.1  # seconds between requests to Scryfall
FORMAT_VERSION = 1

# Atlas layout: 2048 px square pages of 128 × 179 px slots (a card's 63:88
# shape), 16 across and 11 down.
PAGE_SIZE = 2048
SLOT_SIZE = (128, 179)
COLUMNS = PAGE_SIZE // SLOT_SIZE[0]
ROWS = PAGE_SIZE // SLOT_SIZE[1]

# Binder cover colour per set. Anything not listed gets a colour derived
# from its code.
SET_ACCENTS = {
    "ktk": "#a8783c",  # Tarkir's desert sand
}

# Frames that mark a card as a variant rather than the base version.
VARIANT_FRAME_EFFECTS = {"showcase", "extendedart", "etched", "inverted"}
COLOR_ORDER = "WUBRG"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("sets", nargs="*", default=["ktk"], help="Scryfall set codes (default: ktk)")
    parser.add_argument("--bulk", type=Path, help="a downloaded Scryfall Default Cards bulk file")
    parser.add_argument("--out", type=Path, default=Path("data/real"), help="output folder (default: data/real)")
    parser.add_argument("--no-images", action="store_true", help="write card data only; no downloads, no atlas")
    args = parser.parse_args(argv)
    codes = [code.lower() for code in args.sets]

    client = Scryfall()
    bulk = load_bulk(args.bulk, codes) if args.bulk else None
    sets, cards = [], []
    for code in codes:
        info = client.get_json(f"{API}/sets/{code}")
        printings = bulk[code] if bulk is not None else client.search_set(code)
        kept, report = select_base_cards(printings, expected_size(info))
        print(f"{code.upper()} {info['name']}: {report}")
        sets.append(set_entry(info))
        cards.extend(kept)

    data = build_card_file(sets, cards)
    args.out.mkdir(parents=True, exist_ok=True)
    if not args.no_images:
        download_images(client, cards, args.out)
        data["faces"] = pack_atlas(cards, args.out)
        for row, card in zip(data["cards"], cards):
            row.append(image_path(card))
    write_card_file(data, args.out / "cards.json")
    print(f"Wrote {len(data['sets'])} sets, {len(data['cards'])} cards to {args.out / 'cards.json'}")


class Scryfall:
    """Talks to Scryfall politely: one request at a time, REQUEST_GAP apart."""

    def __init__(self):
        self._last = 0.0

    def get(self, url):
        wait = self._last + REQUEST_GAP - time.monotonic()
        if wait > 0:
            time.sleep(wait)
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json;q=0.9,*/*;q=0.8"})
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return response.read()
        finally:
            self._last = time.monotonic()

    def get_json(self, url):
        return json.loads(self.get(url))

    def search_set(self, code):
        """Every English paper printing in a set, following Scryfall's pages."""
        query = urllib.parse.urlencode({
            "q": f"e:{code} lang:en",
            "unique": "prints",
            "order": "set",
            "include_extras": "true",
            "include_variations": "true",
        })
        url, printings = f"{API}/cards/search?{query}", []
        while url:
            page = self.get_json(url)
            printings.extend(page["data"])
            url = page.get("next_page") if page.get("has_more") else None
        return printings


def load_bulk(path, codes):
    """The printings of each wanted set from a Default Cards bulk file."""
    wanted = {code: [] for code in codes}
    with open(path, encoding="utf-8") as f:
        for card in json.load(f):
            if card.get("set") in wanted:
                wanted[card["set"]].append(card)
    return wanted


def expected_size(set_info):
    """How many base cards the set should have: its printed size if Scryfall
    knows it (card_count also counts extras), else its card count."""
    return set_info.get("printed_size") or set_info["card_count"]


def is_base_version(card, size):
    number = card.get("collector_number", "")
    if not re.fullmatch(r"\d+", number) or not 1 <= int(number) <= size:
        return False
    if card.get("lang", "en") != "en" or card.get("digital") or "paper" not in card.get("games", ["paper"]):
        return False
    if card.get("promo") or card.get("variation") or card.get("oversized"):
        return False
    if card.get("border_color") == "borderless":
        return False
    return not VARIANT_FRAME_EFFECTS.intersection(card.get("frame_effects", []))


def select_base_cards(printings, size):
    """One base printing per collector number 1..size, in number order.
    Raises ValueError if any number is missing."""
    by_number = {}
    for card in printings:
        if is_base_version(card, size):
            by_number.setdefault(int(card["collector_number"]), card)
    missing = [n for n in range(1, size + 1) if n not in by_number]
    if missing:
        shown = ", ".join(str(n) for n in missing[:20]) + (" …" if len(missing) > 20 else "")
        raise ValueError(f"{len(missing)} of {size} collector numbers have no base printing: {shown}")
    kept = [by_number[n] for n in range(1, size + 1)]
    return kept, f"kept {len(kept)} base cards of {len(printings)} printings (expected {size})"


def set_entry(info):
    code = info["code"]
    return {
        "code": code.upper(),
        "name": info["name"],
        "release_date": info["released_at"],
        "accent_color": SET_ACCENTS.get(code, derived_accent(code)),
    }


def derived_accent(code):
    """A stable, mid-toned colour for a set code."""
    import colorsys
    hue = (sum(ord(c) * 31 ** i for i, c in enumerate(code)) % 360) / 360
    r, g, b = colorsys.hsv_to_rgb(hue, 0.55, 0.75)
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def card_colors(card):
    colors = set(card.get("colors") or [])
    for face in card.get("card_faces", []):
        colors.update(face.get("colors") or [])
    return [c for c in COLOR_ORDER if c in colors]


def card_row(card):
    """[set_code, collector_number, name, rarity, colors, type_line]."""
    type_line = card.get("type_line") or " // ".join(f.get("type_line", "") for f in card.get("card_faces", []))
    return [card["set"].upper(), int(card["collector_number"]), card["name"], card["rarity"], card_colors(card), type_line]


def card_artists(card):
    names = [card["artist"]] if card.get("artist") else []
    for face in card.get("card_faces", []):
        if face.get("artist") and face["artist"] not in names:
            names.append(face["artist"])
    return names


def build_card_file(sets, cards):
    artists = {}
    for card in cards:
        artists.setdefault(card["set"].upper(), set()).update(card_artists(card))
    return {
        "format": FORMAT_VERSION,
        "source": "Scryfall (scryfall.com), imported %s" % time.strftime("%Y-%m-%d"),
        "sets": [dict(s, artists=sorted(artists.get(s["code"], ()), key=str.casefold)) for s in sets],
        "cards": [card_row(card) for card in cards],
    }


def write_card_file(data, path):
    # One card per line, like the placeholder file.
    header = {k: v for k, v in data.items() if k != "cards"}
    text = json.dumps(header, ensure_ascii=False, indent="\t")[:-2]
    text += ',\n"cards": [\n' + ",\n".join(json.dumps(row, ensure_ascii=False) for row in data["cards"]) + "\n]}\n"
    path.write_text(text, encoding="utf-8")


def image_path(card):
    return f"images/{card['set']}/{int(card['collector_number'])}.jpg"


def image_url(card):
    """The 488 × 680 "normal" image; a double-faced card uses its front face."""
    uris = card.get("image_uris") or card["card_faces"][0]["image_uris"]
    return uris["normal"]


def download_images(client, cards, out):
    fetched = 0
    for i, card in enumerate(cards):
        path = out / image_path(card)
        if path.exists() and path.stat().st_size > 0:
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(client.get(image_url(card)))
        fetched += 1
        print(f"\rimages: {i + 1}/{len(cards)}", end="", flush=True)
    print(f"\rimages: {fetched} downloaded, {len(cards) - fetched} already cached")


def pack_atlas(cards, out):
    """Packs every card's face, shrunk to one slot, into atlas pages in card
    order: card i is page i // (COLUMNS × ROWS), slot i % (COLUMNS × ROWS),
    slots running left to right, top to bottom."""
    try:
        from PIL import Image
    except ImportError:
        sys.exit("Packing the atlas needs Pillow: python3 -m pip install pillow")
    per_page = COLUMNS * ROWS
    pages = []
    (out / "faces").mkdir(exist_ok=True)
    for first in range(0, len(cards), per_page):
        page = Image.new("RGB", (PAGE_SIZE, PAGE_SIZE), (0, 0, 0))
        for slot, card in enumerate(cards[first:first + per_page]):
            with Image.open(out / image_path(card)) as face:
                small = face.convert("RGB").resize(SLOT_SIZE, Image.LANCZOS)
            page.paste(small, ((slot % COLUMNS) * SLOT_SIZE[0], (slot // COLUMNS) * SLOT_SIZE[1]))
        name = f"faces/page_{len(pages)}.png"
        page.save(out / name, optimize=True)
        pages.append(name)
    return {"pages": pages, "page_size": PAGE_SIZE, "slot_size": list(SLOT_SIZE), "columns": COLUMNS, "rows": ROWS}


if __name__ == "__main__":
    try:
        main()
    except ValueError as error:
        sys.exit(f"Import stopped: {error}")
