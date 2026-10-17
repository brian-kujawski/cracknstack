"""Offline checks for import_scryfall.py: the base-version filter, the card
file format and atlas packing. No network. Run from the project root:

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
            printing("2a"), printing("★3"), printing(4),  # suffixed, starred, past the printed size
            printing(1, promo=True), printing(2, variation=True), printing(3, border_color="borderless"),
            printing(1, frame_effects=["showcase"]), printing(2, lang="ja"), printing(3, digital=True),
        ]
        kept, report = importer.select_base_cards(printings, 3)
        self.assertEqual(len(kept), 3)
        self.assertTrue(all(not c.get("promo") and not c.get("variation") for c in kept))
        self.assertIn("kept 3 base cards of 12 printings", report)

    def test_variant_listed_first_does_not_win(self):
        kept, _ = importer.select_base_cards([printing(1, promo=True, name="Promo"), printing(1)], 1)
        self.assertEqual(kept[0]["name"], "Card 1")

    def test_gap_stops_the_import(self):
        with self.assertRaisesRegex(ValueError, "1 of 3 collector numbers have no base printing: 2"):
            importer.select_base_cards([printing(1), printing(3)], 3)

    def test_expected_size_prefers_printed_size(self):
        self.assertEqual(importer.expected_size({"card_count": 280, "printed_size": 269}), 269)
        self.assertEqual(importer.expected_size({"card_count": 269}), 269)


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
