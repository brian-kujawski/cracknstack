"""Offline checks for import_scryfall.py: the base-version filter, the card
file format, the per-set cache and atlas packing. No network. Run from the project root:

  python3 -m unittest discover -s tools -p "test_*.py"
"""

import json
import tempfile
import unittest
from pathlib import Path

import import_scryfall as importer


def printing(number, **fields):
    """A minimal Scryfall card object for set TST."""
    card = {
        "set": "tst", "collector_number": str(number), "name": f"Card {number}", "lang": "en",
        "rarity": "common", "colors": ["G"], "type_line": "Creature — Bear", "games": ["paper"],
        "artist": "Some Artist", "image_uris": {"normal": f"https://example.invalid/{number}.jpg"},
    }
    card.update(fields)
    return card


class SelectBaseCards(unittest.TestCase):
    def test_keeps_one_printing_per_number_in_order(self):
        printings = [printing(3), printing(1), printing(2)]
        kept, _ = importer.select_base_cards(printings, 3)
        self.assertEqual([c["collector_number"] for c in kept], ["1", "2", "3"])

    def test_drops_variants_promos_and_extras(self):
        printings = [printing(n) for n in range(1, 4)] + [
            printing("2a"), printing("★3"), printing(4),  # lettered, starred, past the printed size
            printing(1, promo=True), printing(2, variation=True), printing(3, border_color="borderless"),
            printing(1, frame_effects=["showcase"]), printing(2, lang="ja"), printing(3, digital=True),
        ]
        kept, report = importer.select_base_cards(printings, 3)
        self.assertEqual(len(kept), 3)
        self.assertTrue(all(importer.is_plain(c) and c["lang"] == "en" for c in kept))
        self.assertIn("kept 3 base cards of 12 printings", report)

    def test_variant_listed_first_does_not_win(self):
        kept, _ = importer.select_base_cards([printing(1, promo=True, name="Promo"), printing(1)], 1)
        self.assertEqual(kept[0]["name"], "Card 1")

    def test_lettered_cards_fill_their_number(self):
        # Fallen Empires style: every number 2 is an alternate art, 2a to 2c.
        printings = [printing(1), printing("2c", name="C"), printing("2a", name="A"), printing("2b", name="B")]
        kept, _ = importer.select_base_cards(printings, 2)
        self.assertEqual([c["name"] for c in kept], ["Card 1", "A"])
        self.assertEqual(importer.card_row(kept[1])[1], 2)
        self.assertEqual(importer.image_path(kept[1]), "images/tst/2.jpg")

    def test_special_version_inside_the_main_run_is_kept(self):
        # Full-art basics and the odd borderless main-set card have no plain printing.
        kept, _ = importer.select_base_cards([printing(1), printing(2, border_color="borderless", frame_effects=["inverted"])], 2)
        self.assertEqual(len(kept), 2)

    def test_gap_stops_the_import(self):
        with self.assertRaisesRegex(ValueError, "1 of 3 collector numbers have no printing: 2"):
            importer.select_base_cards([printing(1), printing(3)], 3)


class MainRun(unittest.TestCase):
    def test_printed_size_wins(self):
        self.assertEqual(importer.main_run_size([printing(n) for n in range(1, 6)], 4), 4)

    def test_without_printed_size_the_extras_after_a_gap_are_cut(self):
        printings = [printing(n) for n in range(1, 11)] + [
            printing(n, border_color="borderless", promo_types=["boosterfun"]) for n in range(11, 20)] + [
            printing(n) for n in range(25, 28)]  # plain-looking extras after the gap
        self.assertEqual(importer.main_run_size(printings), 10)

    def test_extras_numbered_straight_after_the_run_are_cut(self):
        printings = [printing(n) for n in range(1, 11)] + [
            printing(11, promo_types=["planeswalkerdeck"]), printing(12, promo=True, promo_types=["buyabox"]),
            printing(13, promo_types=["starterdeck"])]
        self.assertEqual(importer.main_run_size(printings), 10)

    def test_numbers_never_printed_at_the_end_are_cut(self):
        # Eighth Edition's printed size counts cards numbered elsewhere.
        kept, report = importer.select_base_cards([printing(n) for n in range(1, 4)], 5)
        self.assertEqual(len(kept), 3)
        self.assertIn("numbers 4-5 were never printed", report)

    def test_cards_printed_only_in_another_language_are_kept(self):
        # Kamigawa: Neon Dynasty's last basics exist only in Japanese.
        printings = [printing(n) for n in range(1, 4)] + [printing(n, lang="ja") for n in range(4, 6)] + [
            printing(2, lang="ja", name="Japanese 2")]
        kept, report = importer.select_base_cards(printings, 5)
        self.assertEqual([c["lang"] for c in kept], ["en", "en", "en", "ja", "ja"])
        self.assertIn("2 printed only in another language: 4-5", report)

    def test_other_languages_are_fetched_only_when_needed(self):
        class Client:
            queries = []

            def search_set(self, code, extra=""):
                self.queries.append(extra)
                return [printing(4, lang="ja"), printing(4)]

        client = Client()
        english = [printing(n) for n in range(1, 4)]
        self.assertEqual(importer.fetch_other_languages(client, "tst", english, 3), [])
        self.assertEqual(importer.fetch_other_languages(client, "tst", english, None), [])
        self.assertEqual([c["lang"] for c in importer.fetch_other_languages(client, "tst", english, 4)], ["ja"])
        self.assertEqual(client.queries, [" cn>=4 cn<=4 lang:any"])


class CardFile(unittest.TestCase):
    def test_rows_match_the_game_format(self):
        double = printing(2, colors=None, type_line=None, card_faces=[
            {"type_line": "Creature — Human", "colors": ["W"], "artist": "A"},
            {"type_line": "Creature — Werewolf", "colors": ["R"], "artist": "B"}])
        self.assertEqual(importer.card_row(printing(1, colors=["U", "W"])),
                         ["TST", 1, "Card 1", "common", ["W", "U"], "Creature — Bear"])
        self.assertEqual(importer.card_row(double)[4:], [["W", "R"], "Creature — Human // Creature — Werewolf"])

    def test_written_file_round_trips(self):
        info = {"code": "tst", "name": "Test Set", "released_at": "2014-09-26", "card_count": 2}
        cards = [printing(1, artist="Zed"), printing(2, artist="amy")]
        data = importer.build_card_file([importer.set_entry(info)], cards)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "cards.json"
            importer.write_card_file(data, path)
            loaded = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(loaded["format"], 1)
        self.assertEqual(loaded["sets"][0]["code"], "TST")
        self.assertEqual(loaded["sets"][0]["release_date"], "2014-09-26")
        self.assertEqual(loaded["sets"][0]["artists"], ["amy", "Zed"])
        self.assertEqual(loaded["cards"][1], ["TST", 2, "Card 2", "common", ["G"], "Creature — Bear"])

    def test_known_set_keeps_its_accent(self):
        info = {"code": "ktk", "name": "Khans of Tarkir", "released_at": "2014-09-26", "card_count": 269}
        self.assertEqual(importer.set_entry(info)["accent_color"], importer.SET_ACCENTS["ktk"])
        self.assertRegex(importer.derived_accent("abc"), r"^#[0-9a-f]{6}$")


class Atlas(unittest.TestCase):
    def setUp(self):
        try:
            from PIL import Image  # noqa: F401
        except ImportError:
            self.skipTest("Pillow not installed")

    def test_faces_land_in_their_slots(self):
        from PIL import Image
        per_page = importer.COLUMNS * importer.ROWS
        cards = [printing(n) for n in range(1, per_page + 3)]
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder)
            # JPEG is lossy, so colours are compared within a few steps.
            for n, card in enumerate(cards):
                path = out / importer.image_path(card)
                path.parent.mkdir(parents=True, exist_ok=True)
                Image.new("RGB", (488, 680), (n * 7 % 256, 40, 200)).save(path)
            faces = importer.pack_atlas(cards, out)
            self.assertEqual(faces["pages"], ["faces/page_0.png", "faces/page_1.png"])
            with Image.open(out / faces["pages"][0]) as page:
                self.assertEqual(page.size, (importer.PAGE_SIZE, importer.PAGE_SIZE))
                # Card 18 (index 17) is the second slot of the second row.
                w, h = importer.SLOT_SIZE
                self.assertAlmostEqual(page.getpixel((w + w // 2, h + h // 2))[0], 17 * 7, delta=3)
            with Image.open(out / faces["pages"][1]) as page:
                self.assertAlmostEqual(page.getpixel((importer.SLOT_SIZE[0] + 5, 5))[0], (per_page + 1) * 7 % 256, delta=3)

            # Packing the same cards again leaves the pages alone; fewer cards drop the spare page.
            stamp = (out / faces["pages"][0]).stat().st_mtime_ns
            importer.pack_atlas(cards, out)
            self.assertEqual((out / faces["pages"][0]).stat().st_mtime_ns, stamp)
            # A page replaced behind the manifest's back (an old copy, say) is packed again.
            Image.new("RGB", (importer.PAGE_SIZE, importer.PAGE_SIZE), (0, 0, 0)).save(out / faces["pages"][1])
            importer.pack_atlas(cards, out)
            with Image.open(out / faces["pages"][1]) as page:
                self.assertAlmostEqual(page.getpixel((importer.SLOT_SIZE[0] + 5, 5))[0], (per_page + 1) * 7 % 256, delta=3)
            self.assertEqual(importer.pack_atlas(cards[:per_page], out)["pages"], ["faces/page_0.png"])
            self.assertFalse((out / "faces/page_1.png").exists())


class Collection(unittest.TestCase):
    """The per-set cache that lets sets be imported one run at a time."""

    def cache(self, out, code, released, size, numbers):
        cards = [printing(n, set=code) for n in numbers]
        cached = {"set": importer.set_entry({"code": code, "name": code.upper(), "released_at": released}),
                  "version": importer.CACHE_VERSION, "printed_size": size, "printings": [importer.trim_card(c) for c in cards]}
        path = importer.set_cache_path(out, code)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(cached), encoding="utf-8")
        return cards

    def test_sets_join_oldest_first_and_unusable_ones_stay_out(self):
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder)
            self.cache(out, "new", "2020-01-01", 2, [1, 2])
            self.cache(out, "old", "1999-01-01", 1, [1])
            self.cache(out, "gap", "2005-01-01", 3, [1, 3])
            sets, cards = importer.collection(out, with_images=False)
        self.assertEqual([s["code"] for s in sets], ["OLD", "NEW"])
        self.assertEqual([importer.card_row(c)[:2] for c in cards], [["OLD", 1], ["NEW", 1], ["NEW", 2]])

    def test_a_set_waits_for_all_its_images(self):
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder)
            cards = self.cache(out, "tst", "2014-09-26", 2, [1, 2])
            path = out / importer.image_path(cards[0])
            path.parent.mkdir(parents=True)
            path.write_bytes(b"jpeg")
            self.assertEqual(importer.collection(out)[0], [])
            self.assertEqual(importer.set_status(out, "tst"), "1 images to go")
            (out / importer.image_path(cards[1])).write_bytes(b"jpeg")
            self.assertEqual(len(importer.collection(out)[1]), 2)
            self.assertEqual(importer.set_status(out, "tst"), "in game")

    def test_cached_set_is_not_fetched_again(self):
        class Offline:
            def get_json(self, url):
                raise AssertionError("no network expected: " + url)

        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder)
            self.cache(out, "tst", "2014-09-26", 1, [1])
            self.assertEqual(importer.fetch_set(Offline(), "tst", out)["printed_size"], 1)

    def test_trimmed_card_keeps_what_the_game_needs(self):
        card = printing(1, prices={"usd": "1.00"}, oracle_text="Long text", card_faces=[
            {"type_line": "A", "colors": ["W"], "artist": "X", "image_uris": {"normal": "u", "large": "v"}, "flavor_text": "f"}])
        trimmed = importer.trim_card(card)
        self.assertNotIn("prices", trimmed)
        self.assertEqual(trimmed["card_faces"], [{"type_line": "A", "colors": ["W"], "artist": "X", "image_uris": {"normal": "u"}}])
        self.assertEqual(importer.card_row(trimmed), importer.card_row(card))
        self.assertEqual(importer.image_url(trimmed), importer.image_url(card))


class SetList(unittest.TestCase):
    SETS = [
        {"code": "ktk", "name": "Khans of Tarkir", "set_type": "expansion", "released_at": "2014-09-26", "digital": False},
        {"code": "ust", "name": "Unstable", "set_type": "funny", "released_at": "2017-12-08", "digital": False},
        {"code": "h17", "name": "HasCon 2017", "set_type": "funny", "released_at": "2017-09-20", "digital": False},
        {"code": "cmr", "name": "Commander Legends", "set_type": "draft_innovation", "released_at": "2020-11-20", "digital": False},
    ]

    def listed(self, types=None):
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder)
            (out / importer.SET_LIST_PATH).write_text(json.dumps(self.SETS), encoding="utf-8")
            return [s["code"] for s in importer.released_sets(None, out, types)]

    def test_default_list_has_the_un_sets_but_no_other_funny_sets(self):
        self.assertEqual(self.listed(), ["ktk", "ust"])

    def test_chosen_types_list_only_those(self):
        self.assertEqual(self.listed("expansion"), ["ktk"])
        self.assertEqual(self.listed("funny"), ["h17", "ust"])
        self.assertEqual(len(self.listed("all")), 4)


class CardBack(unittest.TestCase):
    def test_back_is_fetched_once(self):
        class Client:
            urls = []

            def get(self, url):
                self.urls.append(url)
                return b"jpeg bytes"

        client = Client()
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder)
            self.assertEqual(importer.download_back(client, out), "back.jpg")
            self.assertEqual(importer.download_back(client, out), "back.jpg")
            self.assertEqual((out / "back.jpg").read_bytes(), b"jpeg bytes")
        self.assertEqual(client.urls, [importer.BACK_URL])


if __name__ == "__main__":
    unittest.main()
