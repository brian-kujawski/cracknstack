"""Offline checks for package_alpha.py. Run from the project root:

  python3 -m unittest discover -s tools -p "test_*.py"
"""

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

import package_alpha as package


def write_fixture(root):
    """A tiny imported collection (sets AAA and CON, two cards each, CON in
    its Windows-safe folder con_) and an exported game."""
    from PIL import Image

    data = root / "real"
    rows = []
    for code, folder in (("AAA", "aaa"), ("CON", "con_")):
        for number in (1, 2):
            image = f"images/{folder}/{number}.jpg"
            (data / image).parent.mkdir(parents=True, exist_ok=True)
            Image.new("RGB", (48, 66), (200, 40 * number, 0)).save(data / image)
            near = data / f"near/{folder}/{number}.dds.gz"
            near.parent.mkdir(parents=True, exist_ok=True)
            near.write_bytes(b"near")
            rows.append([code, number, f"{code} {number}", "common", [], "Land", image, 0.1, None])
    Image.new("RGB", (48, 66)).save(data / "back.jpg")
    cards = {
        "format": 1, "source": "test",
        "sets": [{"code": "AAA", "name": "A"}, {"code": "CON", "name": "Conflux"}],
        "faces": {"pages": ["faces/page_0.dds.gz"], "near": "near/{set}/{number}.dds.gz", "near_size": [256, 356]},
        "back": "back.jpg", "cards": rows,
    }
    (data / "cards.json").write_text(json.dumps(cards), encoding="utf-8")
    game = root / "windows"
    game.mkdir()
    (game / "Pickup.exe").write_bytes(b"exe")
    return data, game


class ParseChapters(unittest.TestCase):
    def test_same_rules_as_the_game(self):
        text = "# comment\nChapter 1: Start\nfra  # Reality Fracture\n\nChapter 2\nAAA\nbbb\nFRA\n"
        self.assertEqual(package.parse_chapters(text), [["FRA"], ["AAA", "BBB"]])


class Package(unittest.TestCase):
    def run_package(self, root, *extra):
        data, game = root / "real", root / "windows"
        with contextlib.redirect_stdout(io.StringIO()) as out:
            package.main(["--chapters", "1", "--data", str(data), "--game", str(game), "--out", str(root / "alpha"), *extra])
        return out.getvalue()

    def test_ships_only_the_chosen_chapters(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_fixture(root)
            package.CHAPTERS = root / "chapters.txt"
            package.CHAPTERS.write_text("Chapter 1\nCON\nChapter 2\nAAA\n", encoding="utf-8")
            self.run_package(root, "--name", "Alpha")
            real = root / "alpha" / "data" / "real"
            cards = json.loads((real / "cards.json").read_text(encoding="utf-8"))
            self.assertEqual([s["code"] for s in cards["sets"]], ["CON"])
            self.assertEqual([row[:2] for row in cards["cards"]], [["CON", 1], ["CON", 2]])
            self.assertEqual(cards["build"], "Alpha")
            self.assertEqual(cards["faces"]["pages"], ["faces/page_0.dds.gz"])
            self.assertEqual(cards["faces"]["near"], "near/{set}/{number}.dds.gz")
            self.assertTrue((real / "faces" / "page_0.dds.gz").exists())
            self.assertTrue((real / "images" / "con_" / "2.jpg").exists())
            self.assertTrue((real / "near" / "con_" / "1.dds.gz").exists())
            self.assertFalse((real / "images" / "aaa").exists())
            self.assertTrue((real / "back.jpg").exists())
            self.assertTrue((root / "alpha" / "Pickup.exe").exists())

            # A second run copies nothing it already has.
            self.assertIn("0 files copied, 5 already there", self.run_package(root, "--zip"))
            self.assertTrue((root / "alpha.zip").exists())
            package.CHAPTERS = package.ROOT / "data" / "chapters.txt"

    def test_needs_an_export(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_fixture(root)
            (root / "windows" / "Pickup.exe").unlink()
            with self.assertRaises(SystemExit):
                self.run_package(root)


if __name__ == "__main__":
    unittest.main()
