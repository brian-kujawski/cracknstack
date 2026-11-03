# Pickup

A collector's room with an empty binder for every Magic: The Gathering set on the shelf, and no cards yet. Every card comes from sealed product you open: booster packs, booster boxes and bulk boxes. Walk the room in first person, rip packs, file every card into its 9-pocket page in collector-number order, and keep the binders shelved in release-date order. Duplicates turn up; each physical card is its own copy (`Collection`), and saves list copies by set code and collector number.

The full design and milestones are in the development plan (kept in the project's shared files, `plan/pickup-development-plan.md`).

> Pickup is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC.

Pickup is free and always will be.

## Running it

1. Install [Godot 4.7](https://godotengine.org/download) (standard build, not .NET).
2. Open `project.godot` in Godot and press **Play** (F5). The game opens on the title screen: press any key for the main menu, then **New Game** shows the intro (the Fan Content disclaimer, on black) and fades in on the laptop's screen, with a welcome message; its OK leaves you on the desktop with Instructions picked out, and closing the laptop drops you into the room. Credits unlocks on the menu once you have started a game. (While developing, `godot --path . -- --skip-title` goes straight into the shop, and the pause menu's **Play Ending** button plays the ending without filing every card.) Filing every card and shelving every binder fades out into the credits. You start just inside the door of the store's one cramped room: a two-shelf binder shelf along the back wall, raised on legs, whose top works like a table (the timeline runs left to right, top shelf first) and four work tables in the middle.

**Booster packs (prototype):** a stand of sealed packs by the door, three sets at a time. Click it with empty hands to take the front pack of a column (click again to put it back, until it starts to tear). F brings it up close and R turns it over, like a card. Hold Space to rip it open: it trembles, tears across the top and the room goes dark, then it bursts with a flash and its 15 cards are in your hand up close, commons first and the rare slot last. They come out the size they were in the pack and quickly come up to full size. Press Space to show each next card; a rare or mythic glows as it comes up, and Space once more lowers the stack into your hand. Each pack makes 15 new cards (any card of the set, so you get duplicates), and the stand restocks itself for free when it's empty, until buying exists. **Boxes:** a booster box (about 6" x 5" x 4" tall, in its set's colours for now) and a bulk box (a white cardboard box about 12" x 10" x 8" with a printed "LEA Bulk" label) can be picked up and put down like a binder. Press Space with one in hand, or aimed at one lying on the floor or a table, to open it: a booster box tips its 36 packs out in a heap, to be picked up (and put down) and ripped like any pack; a bulk box tips its 1,000 cards out onto the floor, or onto the table it's on (up to 200 stay on the table, the rest spill onto the floor). Opening a set's product unlocks its binder on the shelf. Until buying exists, the debug pause menu's **Booster Box** and **Bulk Box** buttons put a box of a random set on the floor in front of you. Wrapper art goes in `assets/packs/` (see the README there).

**The laptop:** an open 90s notebook sits on the front left work table. Pick it up and put it down anywhere like a box; E, aimed at it or with it in hand, opens its screen, a mid-90s desktop (`scripts/laptop/`). The game stops while it's open; Esc or Start > Close Laptop goes back into the room. Its programs: **Card Shop** (every set, newest first: order a booster pack, booster box or bulk box; free for now, and an order turns up on the floor just inside the door at once, until money and next-morning deliveries exist), **My Collection** (Mana, Cards Organized, each unlocked set's binder, and a placeholder for levels), **To Do** (story entries that appear as Cards Organized grows) and **Instructions** (how to play; a New Game points you to it first). All its words are placeholders in `scripts/laptop/laptop_text.gd`.

Controls:

| Input | Does |
|---|---|
| WASD, mouse | Walk, look |
| Ctrl or C | Crouch (hold). You shrink enough to get under the work tables, and stay down until there's room to stand |
| Left-click | Context sensitive. Empty-handed: pick up the card under the crosshair (from the floor or a table), or pick up a closed binder (from the floor, a table or a shelf). Holding a card: file it into its own pocket if that is the one you're looking at (any other pocket refuses it), or put it down where you're looking (on the floor it rejoins the pile). Carrying a binder: put it down where you're looking, or stand it in the shelf space you're looking at. |
| Left-click and hold | When putting something down: a ghost shows where it will go and follows your aim; let go to put it there. Holding cards with room for more (Harmonize), a quick click on another card picks it up too, and holding puts the top card down |
| Right-click | Toss the held card back onto the pile, or the carried binder, which tumbles past other binders and lands on its cover or its back. Empty-handed, aimed at the pile: flip it, tossing a few of the top cards there up so they land face up or down at random |
| E | Open or close the binder you're looking at. Aimed at the laptop, or with it in hand: open the laptop |
| Mouse wheel | Turn the pages of the open binder you're looking at. Holding several cards (Harmonize), aimed anywhere else: cycle which card is on top |
| F | Bring the held card up close to inspect it (the view holds still and the mouse tilts the card; F again lowers it). Empty-handed, aimed at a card in an open binder or a display cabinet: bring that card up close the same way; F again sends it back |
| R | Turn the card up close over to look at its back (R again turns it face up; lowering it with F always does) |
| T | Turn the card up close a quarter turn clockwise, to read split cards printed sideways (T again turns it upright; lowering it with F always does) |
| Esc | Pause menu: Resume (or Esc again), Save/Load, Achievements, Settings, Exit Game (to the main menu or the desktop, saving first or not) |
| Tab | Upgrade menu: spend Mana on upgrades (Tab or Esc to go back in) |
| Space | Hold with a booster pack in hand to rip it open. With several cards in hand, show the next one (the top card goes to the back) |
| 1 | Cast Tithe, once learned: holding or looking at a binder, some of its missing cards light up wherever they lie in the pile |
| 2 | Cast Teleport, once learned: the top card in hand flies to its own binder, wherever it is, and files itself |
| 3 | Cast Demonic Tutor, once learned: aimed at an empty pocket of an open binder, its card flies up out of the pile into your hand. It then recharges (shown under your Mana); filing cards by hand speeds that up |
| 4 | Cast Chain Lightning, once learned: your next lock-in makes a missing card from that page glow where it lies in the pile |
| 5 | Cast Abundance, once learned (needs Harmonize): holding a card, the next unfiled cards after it in its set fly into your hand behind it |

These are the defaults. Every binding is defined in one place, `scripts/input/controls.gd` (the `Controls` autoload), and the hints on screen read their key names from it. The Settings page (main menu or pause) lists them for reference; they aren't rebindable in game.

**Settings** has four tabs: Audio (Master, Effects, Ambience and Music volume, mute in background), Controls (mouse sensitivity, invert Y, crouch Hold/Toggle, the key list), Gameplay (day length or a stopped clock, how often to autosave, interface size) and Graphics (window mode, vsync, frame limit, field of view, brightness, and a Low/Medium/High quality preset over render scale, shadows, anti-aliasing and card detail). Changes apply at once and are saved to `user://settings.cfg` (the `Settings` autoload, `scripts/settings/settings.gd`).

**Saves:** one autosave and three slots, in `user://saves/` (the `Saves` autoload, `scripts/save/`). The autosave is written when a New Game's intro ends, every 5 minutes of play by default, when the ending starts and by Save And Quit; slots are written from the pause menu's Save/Load page. Continue loads the newest save; Load Game lists them all. Achievements and settings are kept apart and never touched by a save or New Game. A change that breaks old saves bumps `SaveGame.SAVE_VERSION`, and older saves then show as *From an older version* and can't be loaded; card data changes (a new import) carry over without that. In developer builds, `godot --path . -- --dump-save <file>` prints a save as JSON.

A card in its own pocket locks in with a chime and a gold edge; anywhere else it glows red, makes no sound and can be taken back out. A binder in its own shelf space locks in with a chime; in another binder's space it glows red. A shelf lights up when every binder on it is in its own space and complete.

## Benchmark

The floor can hold one copy of every card (~30,000) at once. To measure frame rate at that scale (the benchmark tips one copy of every card out first), run the scripted walk-through on the placeholder collection; it prints average fps and 1% lows after 20 seconds:

```sh
godot --path . -- --benchmark --placeholder
godot --path . -- --benchmark --crouched    # at crouched eye height, with real data: counts near faces that arrived late
```

The target is 60 fps on a mid-range laptop.

## Card data

All game code reads cards through the `CardDatabase` autoload (`scripts/data/card_database.gd`). It loads real cards from `data/real/cards.json` when that file exists, and otherwise falls back to the placeholder collection (150 fake sets, about 30,000 cards) with a note in the corner of the screen.

### Real cards from Scryfall

Card data and images come from [Scryfall](https://scryfall.com) and stay out of git (`data/real/` is ignored). The importer adds one set at a time, so a metered connection can take it in steps:

```sh
python3 -m pip install pillow numpy             # once, for packing the card faces
python3 tools/import_scryfall.py --list         # core and expansion sets not yet added, their size and estimated download
python3 tools/import_scryfall.py --listadded    # sets already in the game (--listall shows both)
python3 tools/import_scryfall.py ktk --dry-run  # fetch one set's card data (a few hundred KB) and price its images
python3 tools/import_scryfall.py ktk            # import it; asks before downloading the images
python3 tools/import_scryfall.py ktk frf dtk    # several sets in one run (one question for all their images)
python3 tools/import_scryfall.py --all          # every set --list shows, for an unmetered connection
```

Each import fetches a set's card data once (cached in `data/real/sets/`), downloads the large face images it doesn't already have (`data/real/images/<set>/`, about 135 KB a card, 40 MB for Khans of Tarkir), then rebuilds `data/real/cards.json`, the far faces packed into atlas pages (`data/real/faces/`), each card's near face (`data/real/near/<set>/`) and the card back (`data/real/back.jpg`) from every set imported so far, oldest first. Faces are written BC1-compressed with their mipmaps (`.dds`), so the game sends them to the GPU as they are; only new or changed ones are packed again. Every run ends with the bytes and time it actually used. An interrupted download keeps what it finished; run the same command to carry on. Running with no set code rebuilds the game files without touching the network.

Only each set's main run is kept: one printing per collector number, from 1 to the set's printed size (or, when Scryfall doesn't know it, to where the showcase, borderless and other extra versions start). A plain printing wins over an alternate art (1 over 1a) and a lettered one over a special version. A set with a hole inside that run is reported and left out of the game; `--list` and `--listall` mark it. Cards printed only in another language, like Neon Dynasty's Japanese basics and All Will Be One's Phyrexian ones, are kept in that language (one extra small request for those sets). `--types all` with any of the lists shows every set type, `--yes` skips the question, and `--no-images` writes card data only. To drop a set from the game, delete its file in `data/real/sets/` and run the importer with no set code.

**Card faces at full scale**: every card's far face (64 × 88 px) is always loaded, about 130 MB of video memory for ~34,000 cards. Cards close to your eyes (crouched, or right at your feet) get their near face (256 × 356 px), streamed into a fixed pool in the background (`NearFaces`) and faded in. Cards on tables and in binders show the near face too; the card in your hand shows the full large image. Settings → Graphics → Card detail: Low draws far faces one size smaller and keeps fewer near faces, for less video memory. In debug builds the pause menu has a button that switches the floor between near faces, far faces only, and late near faces tinted red.

The importer puts a `.gdignore` in `data/real/`, so the Godot editor doesn't import the ~34,000 images (the game reads them straight from disk). If the editor imported them before, delete `.godot/imported/` once to get the space back.

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
godot --headless res://tests/test_runner.tscn -- --smoke   # just the quick batch
python3 -m unittest discover -s tools -p "test_*.py"   # the importer, offline
```

Exits non-zero if any check fails, and prints how long each group took. CI runs the smoke batch (`SMOKE` in `tests/test_runner.gd`) on pull requests, and the full suite on main, on pull requests labelled `full-tests`, and when run by hand from the Actions tab.

## Layout

```
data/placeholder/   generated placeholder card data
data/real/          imported Scryfall data and images (not in git)
scenes/             main scene, player
scripts/binders/    Binder (open, turn pages, file, carry, shelve), BinderContents, LooseCard (a card set down on a table)
scripts/data/       CardData, SetData, BinderRange, BinderLayout, CardSort, CardDatabase, CardFileLoader
scripts/input/      Controls: every bindable action, its defaults, rebinds and key names
scripts/feedback/   placeholder sounds, synthesised in code
scripts/player/     first-person controller and Hands (everything you do with a card or binder)
scripts/pile/       the card pile: PileWorld (packed arrays + chunked MultiMeshes), scatter, picking, far faces (FaceAtlas) and near faces (NearFaces)
scripts/store/      graybox room builder, shelf units, shelf layout (binders split evenly across the three wall shelves)
scripts/ui/         credits, pause screen
shaders/            card faces (real images, or placeholders drawn procedurally) and binder pages
tests/              headless checks for the data layer, shelving and pile
tools/              placeholder generator and the Scryfall importer
```
