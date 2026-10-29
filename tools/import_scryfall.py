#!/usr/bin/env python3
"""Imports real card data from Scryfall into data/real/, one set at a time (plan §5).

Each run adds the named sets to a local collection, then rebuilds the game's
files from every set imported so far:

  data/real/sets/<set>.json      cached Scryfall data for one set (small)
  data/real/images/<set>/N.jpg   large faces for the inspect view
  data/real/cards.json           the same card data format as the placeholder
                                 file, plus face atlas, image paths and credits
  data/real/faces/page_N.png     small faces packed into atlas pages
  data/real/back.jpg             the card back, one image for every card

Only the base version of each card is kept: one printing per collector
number, plain whole numbers from 1 to the set's printed size, no promos,
variants, showcase or borderless frames (plan §3.3). A set whose kept cards
don't run 1..N with no gaps is reported and left out.

--list and --all cover the core and expansion sets and the four Un- sets
(Unglued, Unhinged, Unstable, Unfinity); any other set can still be added
by its code. Unstable's and Unfinity's lettered variants (3a-3f) keep only
their first version, like any other lettered card.

Usage, from the project root:

  python3 -m pip install pillow                  # once, for packing the atlas
  python3 tools/import_scryfall.py --list        # sets not yet added, their size and estimated download
  python3 tools/import_scryfall.py --listadded   # sets already in the game
  python3 tools/import_scryfall.py --listall     # both
  python3 tools/import_scryfall.py ktk --dry-run # card data only, then what the images would cost
  python3 tools/import_scryfall.py ktk           # import one set (asks before downloading images)
  python3 tools/import_scryfall.py ktk frf dtk   # import several sets in one go (asks once)
  python3 tools/import_scryfall.py --all         # import every set --list shows (asks once)
  python3 tools/import_scryfall.py               # rebuild cards.json and the atlas, no network

Built for a metered connection: nothing is downloaded twice (card data is
cached per set, images are skipped when already on disk, an interrupted
download leaves no half-written image), card data is fetched gzipped, and
every run ends with how many bytes it actually used. We follow Scryfall's
API guidelines: a descriptive User-Agent, at least 100 ms between requests,
everything cached, the card images used whole (artist credit and copyright
line intact), and no paywall.
"""

import argparse
import gzip
import importlib.util
import io
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://api.scryfall.com"
USER_AGENT = "Pickup/0.1 (free private fan game; https://github.com/brian-kujawski/pickup)"
REQUEST_GAP = 0.1  # seconds between requests to Scryfall
RETRIES = 3
WRITE_RETRIES = 6  # tries to replace a file another program has open
FORMAT_VERSION = 1
# The game reads res://data/real, so the default doesn't depend on the
# folder the importer is run from.
DEFAULT_OUT = Path(__file__).resolve().parent.parent / "data" / "real"

# Atlas layout: 2048 px square pages of 128 × 179 px slots (a card's 63:88
# shape), 16 across and 11 down.
PAGE_SIZE = 2048
SLOT_SIZE = (128, 179)
COLUMNS = PAGE_SIZE // SLOT_SIZE[0]
ROWS = PAGE_SIZE // SLOT_SIZE[1]

# The standard Magic card back (Scryfall's card_back_id for every normal
# card), at the same "normal" size as the faces.
BACK_URL = "https://backs.scryfall.io/normal/0/a/0aeebaf5-8c7d-4636-9e82-8c27447861f7.jpg"
BACK_PATH = "back.jpg"

# Until some images are on disk to measure, a "normal" face is guessed at
# this size (Khans of Tarkir averaged about 150 KB).
DEFAULT_IMAGE_BYTES = 150_000
# Set types shown by --list unless --types says otherwise.
DEFAULT_LIST_TYPES = ("core", "expansion")
# Sets of other types that --list shows too: the Un- sets (Scryfall calls
# them "funny", along with playtest cards and convention giveaways we don't
# want).
DEFAULT_LIST_EXTRAS = ("ugl", "unh", "ust", "unf")
SET_LIST_PATH = "scryfall-sets.json"
SET_LIST_MAX_AGE = 7 * 24 * 3600  # seconds before --list fetches the set list again

# Binder cover colour per set. Anything not listed gets a colour derived
# from its code.
SET_ACCENTS = {
    "ktk": "#a8783c",  # Tarkir's desert sand
}

# Frames and promo types that mark a printing as an extra version rather than
# part of the set's main run. ("inverted" isn't one: full-art lands use it.)
VARIANT_FRAME_EFFECTS = {"showcase", "extendedart", "etched"}
EXTRA_PROMO_TYPES = {"boosterfun", "planeswalkerdeck", "starterdeck", "buyabox", "bundle", "serialized", "promopack"}
# Without a printed size from Scryfall, a set's main run ends at the last
# plain printing before a gap of at least this many numbers.
MAIN_RUN_GAP = 3
COLOR_ORDER = "WUBRG"

# The parts of a Scryfall card object the importer uses; the rest isn't cached.
CARD_FIELDS = ("set", "collector_number", "name", "lang", "digital", "games", "promo", "variation",
               "oversized", "border_color", "frame_effects", "promo_types", "rarity", "colors", "type_line", "artist")
CACHE_VERSION = 2  # bumped when the cached fields change; older set files are fetched again
FACE_FIELDS = ("type_line", "colors", "artist")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("sets", nargs="*", help="Scryfall set codes to add, e.g. ktk")
    listing = parser.add_mutually_exclusive_group()
    listing.add_argument("--list", dest="listing", action="store_const", const="todo",
                         help="list the sets not yet added, with their size and estimated download, then stop")
    listing.add_argument("--listadded", dest="listing", action="store_const", const="added",
                         help="list the sets already added, then stop")
    listing.add_argument("--listall", dest="listing", action="store_const", const="all",
                         help="list every set, added or not, then stop")
    parser.add_argument("--all", action="store_true",
                        help="add every set --list shows (core, expansion and the Un- sets unless --types says otherwise)")
    parser.add_argument("--types",
                        help="set types for the lists, comma separated, or 'all' (default: core,expansion"
                             " and the Un- sets)")
    parser.add_argument("--dry-run", action="store_true", help="fetch card data only and say what the images would cost")
    parser.add_argument("--yes", action="store_true", help="download without asking first")
    parser.add_argument("--refetch", action="store_true", help="fetch card data again even if it is cached")
    parser.add_argument("--bulk", type=Path, help="card data from a downloaded Scryfall Default Cards bulk file instead")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT,
                        help="output folder (default: the project's data/real, wherever this is run from)")
    parser.add_argument("--no-images", action="store_true", help="write card data only; no image downloads, no atlas")
    args = parser.parse_args(argv)
    codes = [code.lower() for code in args.sets]
    out = args.out
    client = Scryfall()
    started = time.monotonic()
    if args.all and not args.listing:
        codes += [s["code"] for s in released_sets(client, out, args.types, args.refetch)
                  if set_status(out, s["code"]) != "in game" and s["code"] not in codes]
        print(f"Adding {len(codes)} sets: {', '.join(codes)}" if codes else "Every set is already in the game.")

    if args.listing:
        list_sets(client, out, args.types, args.refetch, args.listing)
        print(usage_line(client, started))
        return 0

    # Every run that isn't a dry run ends by packing the atlas; stop before
    # downloading anything rather than leave cards.json from the last run.
    if not args.no_images and not args.dry_run and importlib.util.find_spec("PIL") is None:
        sys.exit("Packing the atlas needs Pillow: python3 -m pip install pillow")

    failed = []
    bulk = load_bulk(args.bulk, codes) if args.bulk and codes else None
    for code in codes:
        try:
            cached = fetch_set(client, code, out, bulk, args.refetch)
        except ValueError as problem:
            # One set Scryfall can't give us shouldn't stop the rest of the queue.
            failed.append(code)
            print(f"{code.upper()}: left out, {problem}")
            continue
        try:
            _, report = select_base_cards(cached["printings"], cached.get("printed_size"))
            print(f"{code.upper()} {cached['set']['name']}: {report}")
        except ValueError as problem:
            failed.append(code)
            print(f"{code.upper()} {cached['set']['name']}: left out, {problem}")

    wanted = [code for code in codes if code not in failed]
    if not args.no_images and wanted:
        missing = [card for code in wanted for card in base_cards_of(load_cached_set(out, code))[0]
                   if not has_file(out / image_path(card))]
        estimate = len(missing) * average_image_bytes(out)
        print(f"Images: {len(missing)} to download, about {megabytes(estimate)}"
              + ("" if missing else " (all already on disk)"))
        if args.dry_run:
            print(usage_line(client, started))
            return 1 if failed else 0
        if missing and not args.yes and sys.stdin.isatty():
            if input(f"Download about {megabytes(estimate)} now? [y/N] ").strip().lower() not in ("y", "yes"):
                print("Nothing downloaded. Card data stays cached for next time.")
                print(usage_line(client, started))
                return 1
        if missing:
            download_images(client, missing, out)
    elif args.dry_run:
        print(usage_line(client, started))
        return 1 if failed else 0

    rebuild(client, out, args.no_images)
    print(usage_line(client, started))
    return 1 if failed else 0


class Scryfall:
    """Talks to Scryfall politely: one request at a time, REQUEST_GAP apart,
    asking for gzip, and counting the bytes that came over the wire."""

    def __init__(self):
        self._last = 0.0
        self.requests = 0
        self.bytes = 0

    def get(self, url):
        for attempt in range(RETRIES):
            wait = self._last + REQUEST_GAP - time.monotonic()
            if wait > 0:
                time.sleep(wait)
            request = urllib.request.Request(url, headers={
                "User-Agent": USER_AGENT,
                "Accept": "application/json;q=0.9,*/*;q=0.8",
                "Accept-Encoding": "gzip",
            })
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    body = response.read()
                    encoding = response.headers.get("Content-Encoding", "")
                self.requests += 1
                self.bytes += len(body)
                return gzip.decompress(body) if encoding == "gzip" else body
            except urllib.error.HTTPError as error:
                # 429 (too many requests) and server errors are worth waiting out.
                if error.code != 429 and error.code < 500 or attempt == RETRIES - 1:
                    raise
                time.sleep(2 ** attempt)
            finally:
                self._last = time.monotonic()

    def get_json(self, url):
        return json.loads(self.get(url))

    def search_set(self, code, extra=" lang:en"):
        """Every English paper printing in a set, following Scryfall's pages."""
        query = urllib.parse.urlencode({
            "q": f"e:{code}{extra}",
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


# --- Card data, cached per set ---

def set_cache_path(out, code):
    return out / "sets" / f"{code}.json"


def load_cached_set(out, code):
    path = set_cache_path(out, code)
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else None


def cached_codes(out):
    folder = out / "sets"
    return sorted(p.stem for p in folder.glob("*.json")) if folder.is_dir() else []


def fetch_set(client, code, out, bulk=None, refetch=False):
    """A set's info and printings, from the cache if there, else from Scryfall
    (about two requests and a few hundred KB, gzipped)."""
    cached = None if refetch else load_cached_set(out, code)
    if cached and cached.get("version") == CACHE_VERSION:
        return cached
    try:
        info = client.get_json(f"{API}/sets/{code}")
    except urllib.error.HTTPError as error:
        if error.code == 404:
            raise ValueError(f"Scryfall has no set '{code}' (see --list)")
        raise
    try:
        printings = bulk[code] if bulk is not None else client.search_set(code)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            raise ValueError(f"{info['name']} has no English cards")
        raise
    printings += fetch_other_languages(client, code, printings, info.get("printed_size"))
    cached = {
        "version": CACHE_VERSION,
        "set": set_entry(info),
        "printed_size": info.get("printed_size"),
        "fetched": time.strftime("%Y-%m-%d"),
        "printings": [trim_card(card) for card in printings],
    }
    path = set_cache_path(out, code)
    path.parent.mkdir(parents=True, exist_ok=True)
    write_whole(path, json.dumps(cached, ensure_ascii=False).encode("utf-8"))
    return cached


def fetch_other_languages(client, code, printings, printed_size):
    """Printings in any language for the numbers at the end of the main run
    that have no English one (Neon Dynasty's Japanese and All Will Be One's
    Phyrexian basics): one small extra request, only for sets that need it."""
    size = main_run_size(printings, printed_size)
    if not printed_size or size >= printed_size:
        return []
    try:
        found = client.search_set(code, f" cn>={size + 1} cn<={printed_size} lang:any")
    except urllib.error.HTTPError as error:
        if error.code == 404:  # nothing in any language: the printed size is just too big
            return []
        raise
    return [card for card in found if card.get("lang") != "en"]


def trim_card(card):
    """Just the fields the importer reads, so the cache stays small."""
    trimmed = {k: card[k] for k in CARD_FIELDS if k in card}
    if card.get("image_uris"):
        trimmed["image_uris"] = {"normal": card["image_uris"]["normal"]}
    if card.get("card_faces"):
        trimmed["card_faces"] = []
        for face in card["card_faces"]:
            kept = {k: face[k] for k in FACE_FIELDS if k in face}
            if face.get("image_uris"):
                kept["image_uris"] = {"normal": face["image_uris"]["normal"]}
            trimmed["card_faces"].append(kept)
    return trimmed


def base_cards_of(cached):
    """(kept cards, None) for a usable set, or ([], what's wrong)."""
    try:
        kept, _ = select_base_cards(cached["printings"], cached.get("printed_size"))
        return kept, None
    except ValueError as error:
        return [], str(error)


def card_number(card):
    """(number, letter) for "123" or "123a"; None for stars, dashes and the like."""
    match = re.fullmatch(r"(\d+)([a-z]?)", card.get("collector_number", ""))
    return (int(match.group(1)), match.group(2)) if match else None


def is_paper(card):
    return not card.get("digital") and "paper" in card.get("games", ["paper"])


def is_english_paper(card):
    return card.get("lang", "en") == "en" and is_paper(card)


def is_plain(card):
    """Not a promo, variant or special frame: how a main-run card looks."""
    if card.get("promo") or card.get("variation") or card.get("oversized"):
        return False
    if card.get("border_color") == "borderless" or EXTRA_PROMO_TYPES.intersection(card.get("promo_types") or []):
        return False
    return not VARIANT_FRAME_EFFECTS.intersection(card.get("frame_effects") or [])


def main_run_size(printings, printed_size=None):
    """Where a set's main run ends. Scryfall's printed size when it has one,
    else the last plain printing before a gap of MAIN_RUN_GAP numbers (the
    showcase, borderless and other extra versions are numbered after the
    main run). Numbers at the end with no printing at all are cut."""
    numbers = {card_number(c)[0] for c in printings if card_number(c) and is_paper(c)}
    size = printed_size
    if not size:
        size = 0
        for n in sorted({card_number(c)[0] for c in printings if card_number(c) and is_english_paper(c) and is_plain(c)}):
            if n - size > MAIN_RUN_GAP:
                break
            size = n
    while size and size not in numbers:
        size -= 1
    return size


def select_base_cards(printings, printed_size=None):
    """One printing per collector number of the set's main run, in number
    order. English wins, then a plain printing over a lettered one (1 over
    1a, 1a over 1b) and a lettered one over a special version; a card printed
    only in another language is kept in that language. Raises ValueError if a
    number inside the main run has no printing at all."""
    size = main_run_size(printings, printed_size)
    by_number = {}
    for card in printings:
        number = card_number(card)
        if number and 1 <= number[0] <= size and is_paper(card):
            by_number.setdefault(number[0], []).append(card)
    missing = [n for n in range(1, size + 1) if n not in by_number]
    if missing or not size:
        shown = ", ".join(str(n) for n in missing[:20]) + (" …" if len(missing) > 20 else "")
        raise ValueError(f"{len(missing)} of {size} collector numbers have no printing: {shown}" if size
                         else "no numbered cards")
    rank = lambda card: (not is_english_paper(card), not is_plain(card), card_number(card)[1])
    kept = [min(by_number[n], key=rank) for n in range(1, size + 1)]
    report = f"kept {len(kept)} base cards of {len(printings)} printings"
    foreign = [card_number(c)[0] for c in kept if not is_english_paper(c)]
    if foreign:
        report += f" ({len(foreign)} printed only in another language: {foreign[0]}-{foreign[-1]})"
    if printed_size and size < printed_size:
        report += f" (numbers {size + 1}-{printed_size} were never printed)"
    return kept, report


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


# --- The game's card file ---

def card_colors(card):
    colors = set(card.get("colors") or [])
    for face in card.get("card_faces", []):
        colors.update(face.get("colors") or [])
    return [c for c in COLOR_ORDER if c in colors]


def card_row(card):
    """[set_code, collector_number, name, rarity, colors, type_line]."""
    type_line = card.get("type_line") or " // ".join(f.get("type_line", "") for f in card.get("card_faces", []))
    return [card["set"].upper(), card_number(card)[0], card["name"], card["rarity"], card_colors(card), type_line]


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


def collection(out, with_images=True):
    """Every cached set that can go in the game, oldest first, and their
    cards in order. A set is left out (with a note) if its numbers have gaps,
    or, when images are wanted, while any of its images are still missing."""
    sets, cards, waiting = [], [], []
    entries = [load_cached_set(out, code) for code in cached_codes(out)]
    for cached in sorted(entries, key=lambda c: (c["set"]["release_date"], c["set"]["code"])):
        kept, problem = base_cards_of(cached)
        if problem:
            continue
        absent = sum(1 for card in kept if not has_file(out / image_path(card))) if with_images else 0
        if absent:
            waiting.append(cached["set"]["code"])
            continue
        sets.append(cached["set"])
        cards.extend(kept)
    if waiting:
        print(f"Not in the game until their images are downloaded: {', '.join(waiting)}")
    return sets, cards


def rebuild(client, out, no_images=False):
    """Writes cards.json (and the atlas) from every set in the collection."""
    sets, cards = collection(out, with_images=not no_images)
    if not sets:
        raise ValueError("no sets imported yet; try --list, then import one set by its code")
    data = build_card_file(sets, cards)
    out.mkdir(parents=True, exist_ok=True)
    if not no_images:
        data["faces"] = pack_atlas(cards, out)
        data["back"] = download_back(client, out)
        for row, card in zip(data["cards"], cards):
            row.append(image_path(card))
    write_card_file(data, out / "cards.json")
    names = ", ".join(s["code"] for s in sets)
    print(f"Wrote {len(sets)} sets ({names}), {len(cards)} cards to {out / 'cards.json'}")


# --- Images ---

def image_path(card):
    return f"images/{card['set']}/{card_number(card)[0]}.jpg"


def image_url(card):
    """The 488 × 680 "normal" image; a double-faced card uses its front face."""
    uris = card.get("image_uris") or card["card_faces"][0]["image_uris"]
    return uris["normal"]


def file_stamp(path):
    """A file's size and modified time, to tell whether it changed since."""
    info = path.stat()
    return [info.st_size, info.st_mtime_ns]


def has_file(path):
    return path.exists() and path.stat().st_size > 0


def write_whole(path, data):
    """Writes via a temporary file so an interrupted run never leaves a
    half-written file that looks finished."""
    part = path.with_name(path.name + ".part")
    part.write_bytes(data)
    # On Windows a file another program has open (the Godot editor
    # reimporting it, a virus scan, a sync client) can't be replaced for a
    # moment, so try again for a few seconds before giving up.
    for attempt in range(WRITE_RETRIES):
        try:
            os.replace(part, path)
            return
        except OSError:
            if attempt == WRITE_RETRIES - 1:
                part.unlink(missing_ok=True)
                sys.exit(f"Couldn't write {path}: another program has it open. "
                         "Close the Godot editor (and pause any sync or virus scan of the project), then run again.")
            time.sleep(0.5 * (attempt + 1))


def download_images(client, cards, out):
    """Downloads the given cards' images, skipping any already on disk."""
    fetched, before = 0, client.bytes
    for i, card in enumerate(cards):
        path = out / image_path(card)
        if has_file(path):
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        write_whole(path, client.get(image_url(card)))
        fetched += 1
        print(f"\rimages: {i + 1}/{len(cards)}, {megabytes(client.bytes - before)}", end="", flush=True)
    print(f"\rimages: {fetched} downloaded ({megabytes(client.bytes - before)}), {len(cards) - fetched} already on disk")


def download_back(client, out):
    """The card back, fetched once; returns its path in the card file."""
    path = out / BACK_PATH
    if not has_file(path):
        write_whole(path, client.get(BACK_URL))
    return BACK_PATH


def average_image_bytes(out):
    """The mean size of the face images already on disk, or a fair guess."""
    sizes = [p.stat().st_size for p in (out / "images").glob("*/*.jpg")] if (out / "images").is_dir() else []
    return sum(sizes) // len(sizes) if sizes else DEFAULT_IMAGE_BYTES


def pack_atlas(cards, out):
    """Packs every card's face, shrunk to one slot, into atlas pages in card
    order: card i is page i // (COLUMNS × ROWS), slot i % (COLUMNS × ROWS),
    slots running left to right, top to bottom. A page whose cards haven't
    changed since the last run is left as it is, as long as the file is still
    the one this packed (same size and modified time); anything else on disk
    under that name is packed again."""
    try:
        from PIL import Image
    except ImportError:
        sys.exit("Packing the atlas needs Pillow: python3 -m pip install pillow")
    per_page = COLUMNS * ROWS
    pages = []
    (out / "faces").mkdir(exist_ok=True)
    manifest_path = out / "faces" / "manifest.json"
    old = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    manifest = {}
    for first in range(0, len(cards), per_page):
        name = f"faces/page_{len(pages)}.png"
        contents = [image_path(card) for card in cards[first:first + per_page]]
        pages.append(name)
        previous = old.get(name)
        if isinstance(previous, dict) and previous.get("cards") == contents \
                and has_file(out / name) and previous.get("file") == file_stamp(out / name):
            manifest[name] = previous
            continue
        page = Image.new("RGB", (PAGE_SIZE, PAGE_SIZE), (0, 0, 0))
        for slot, path in enumerate(contents):
            with Image.open(out / path) as face:
                small = face.convert("RGB").resize(SLOT_SIZE, Image.LANCZOS)
            page.paste(small, ((slot % COLUMNS) * SLOT_SIZE[0], (slot // COLUMNS) * SLOT_SIZE[1]))
        encoded = io.BytesIO()
        page.save(encoded, "PNG", optimize=True)
        write_whole(out / name, encoded.getvalue())
        manifest[name] = {"cards": contents, "file": file_stamp(out / name)}
    for stale in (out / "faces").glob("page_*.png"):
        if f"faces/{stale.name}" not in manifest:
            stale.unlink()
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    return {"pages": pages, "page_size": PAGE_SIZE, "slot_size": list(SLOT_SIZE), "columns": COLUMNS, "rows": ROWS}


# --- Listing sets ---

def fetch_set_list(client, out, refetch=False):
    """Scryfall's list of every set, cached for a week (one small request)."""
    path = out / SET_LIST_PATH
    if not refetch and has_file(path) and time.time() - path.stat().st_mtime < SET_LIST_MAX_AGE:
        return json.loads(path.read_text(encoding="utf-8"))
    sets, url = [], f"{API}/sets"
    while url:
        page = client.get_json(url)
        sets.extend(page["data"])
        url = page.get("next_page") if page.get("has_more") else None
    keep = ("code", "name", "set_type", "released_at", "card_count", "printed_size", "digital")
    sets = [{k: s.get(k) for k in keep} for s in sets]
    path.parent.mkdir(parents=True, exist_ok=True)
    write_whole(path, json.dumps(sets, ensure_ascii=False).encode("utf-8"))
    return sets


def set_status(out, code):
    """What's on disk for a set: 'in game', 'N images to go', 'left out', or ''."""
    cached = load_cached_set(out, code)
    if not cached:
        return ""
    kept, problem = base_cards_of(cached)
    if problem:
        return "left out: numbering gaps"
    absent = sum(1 for card in kept if not has_file(out / image_path(card)))
    return f"{absent} images to go" if absent else "in game"


def released_sets(client, out, types=None, refetch=False):
    """The paper sets of the given types (comma separated, or 'all') released
    so far, oldest first. With no types: core and expansion sets and the
    DEFAULT_LIST_EXTRAS."""
    wanted = None if types == "all" else {t.strip() for t in (types or ",".join(DEFAULT_LIST_TYPES)).split(",")}
    extras = () if types else DEFAULT_LIST_EXTRAS
    today = time.strftime("%Y-%m-%d")
    sets = [s for s in fetch_set_list(client, out, refetch)
            if not s["digital"] and (wanted is None or s["set_type"] in wanted or s["code"] in extras)
            and (s["released_at"] or "9999") <= today]
    sets.sort(key=lambda s: (s["released_at"], s["code"]))
    return sets


def list_sets(client, out, types, refetch=False, show="all"):
    """Prints the sets to add ("todo"), the sets in the game ("added"), or both ("all")."""
    sets = released_sets(client, out, types, refetch)
    per_image = average_image_bytes(out)
    shown = added = total_cards = total_bytes = 0
    print(f"{'code':<6} {'released':<10} {'type':<16} {'cards':>5} {'download':>9}  name")
    for s in sets:
        cached = load_cached_set(out, s["code"])
        kept = base_cards_of(cached)[0] if cached else None
        size = len(kept) if kept else s["printed_size"] or s["card_count"]
        status = set_status(out, s["code"])
        in_game = status == "in game"
        added += in_game
        if show == "todo" and in_game or show == "added" and not in_game:
            continue
        shown += 1
        if in_game:
            # What it actually took, from the images on disk.
            size_bytes = sum((out / image_path(card)).stat().st_size for card in kept)
        else:
            size_bytes = size * per_image
            total_cards += size
            total_bytes += size_bytes
        note = f"  [{status}]" if status and show != "added" else ""
        print(f"{s['code']:<6} {s['released_at']:<10} {s['set_type']:<16} {size:>5} {megabytes(size_bytes):>9}  {s['name']}{note}")
    if show == "added":
        print(f"{added} of {len(sets)} sets in the game.")
    else:
        print(f"{shown} sets shown, {added} of {len(sets)} in the game. Still to add: {total_cards} cards,"
              f" about {megabytes(total_bytes)} of images (at {per_image // 1000} KB each).")


def megabytes(n):
    return f"{n / 1_000_000:.1f} MB"


def usage_line(client, started):
    return f"Used {megabytes(client.bytes)} in {client.requests} requests, {time.monotonic() - started:.0f} s."


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ValueError as error:
        sys.exit(f"Import stopped: {error}")
    except KeyboardInterrupt:
        sys.exit("\nStopped. Everything downloaded so far is kept; run the same command again to carry on.")
