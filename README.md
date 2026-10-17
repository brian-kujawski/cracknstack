# Pickup

A game store's entire Magic: The Gathering collection has been dumped on the floor: about 30,000 cards plus every set's binder. Walk the store in first person, dig out binders, file every card into its 9-pocket page in collector-number order, and shelve the binders in release-date order.

The full design and milestones are in the development plan (kept in the project's shared files, `plan/pickup-development-plan.md`).

> Pickup is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC.

Pickup is free and always will be.

## Running it

1. Install [Godot 4.7](https://godotengine.org/download) (standard build, not .NET).
2. Open `project.godot` in Godot and press **Play** (F5). You start just inside the door of the store's one cramped room: three wall-length binder shelves (left, back, right; the timeline runs round the room in that order) and four work tables in the middle.

Controls:

| Input | Does |
|---|---|
| WASD, mouse | Walk, look |
| Ctrl or C | Crouch |
| Left-click | Context sensitive. Empty-handed: pick up the card under the crosshair (from the floor, a stack, or a misplaced card in an open binder), or pick up a closed binder (from the floor, a table or a shelf). Holding a card: file it into the pocket you're looking at, add it to the stack you're looking at, or else bring it up close. Carrying a binder: set it down on the floor or a table, or stand it in the shelf space you're looking at. |
| Right-click | Toss the held card back onto the pile |
| E | Open or close the binder you're looking at |
| Mouse wheel | Turn the pages of the open binder you're looking at |
| F | Put the held card on an unsorted stack (starts a new one where you're looking) |
| Tab | Show or hide the credits |
| Esc | Free the mouse (click to capture it again) |

A card in its own pocket locks in with a chime and a gold edge; anywhere else it glows red, makes no sound and can be taken back out. A binder in its own shelf space locks in with a chime; in another binder's space it glows red. A shelf lights up when every binder on it is in its own space and complete.

## Benchmark

The full game puts the whole collection (~30,000 cards) on the floor at once. To measure frame rate at that scale, run the scripted walk-through on the placeholder collection; it prints average fps and 1% lows after 20 seconds:

```sh
godot --path . -- --benchmark --placeholder
```

The target is 60 fps on a mid-range laptop.

## Card data

All game code reads cards through the `CardDatabase` autoload (`scripts/data/card_database.gd`). It loads real cards from `data/real/cards.json` when that file exists, and otherwise falls back to the placeholder collection (150 fake sets, about 30,000 cards) with a note in the corner of the screen.

### Real cards: Khans of Tarkir

The first real build is Khans of Tarkir only: its 269 cards and one binder. Card data and images come from [Scryfall](https://scryfall.com) and stay out of git (`data/real/` is ignored), so import them once:

```sh
python3 -m pip install pillow           # once, for packing the face atlas
python3 tools/import_scryfall.py        # Khans of Tarkir (about 270 requests, under a minute)
```

That writes `data/real/cards.json`, the small faces packed into atlas pages (`data/real/faces/`), and a large image per card for the hand and the binders (`data/real/images/ktk/`, about 40 MB), and the card back (`data/real/back.jpg`). It keeps only each card's base printing, numbered 1 to the set's printed size, and stops if any number is missing. Re-running only downloads images that aren't there yet. Other sets work the same way (`python3 tools/import_scryfall.py ktk frf`); for many sets, pass Scryfall's Default Cards bulk file with `--bulk`.

To play with the placeholders again, delete `data/real/` or run with `-- --placeholder`.

### Placeholder cards

```sh
godot --headless --script res://tools/gen_placeholder_sets.gd
```

The output (`data/placeholder/cards.json`) is deterministic and committed. CI checks that it matches the generator. The tests and the full-scale benchmark use it.

## Tests

```sh
godot --headless --import            # once, to build the class cache
godot --headless res://tests/test_runner.tscn
python3 -m unittest discover -s tools -p "test_*.py"   # the importer, offline
```

Exits non-zero if any check fails. CI runs the same thing on every pull request.

## Layout

```
data/placeholder/   generated placeholder card data
data/real/          imported Scryfall data and images (not in git)
scenes/             main scene, player
scripts/binders/    Binder (open, turn pages, file, carry, shelve), BinderContents, UnsortedStack
scripts/data/       CardData, SetData, BinderRange, BinderLayout, CardSort, CardDatabase, CardFileLoader
scripts/feedback/   placeholder sounds, synthesised in code
scripts/player/     first-person controller and Hands (everything you do with a card or binder)
scripts/pile/       the card pile: PileWorld (packed arrays + chunked MultiMeshes), scatter, picking, gap fill, face atlas
scripts/store/      graybox room builder, shelf units, shelf layout (binders split evenly across the three wall shelves)
scripts/ui/         credits
shaders/            card faces (real images, or placeholders drawn procedurally) and binder pages
tests/              headless checks for the data layer, shelving and pile
tools/              placeholder generator and the Scryfall importer
```
