class_name LaptopText
extends RefCounted
## Every word the laptop shows that's story or help, in one place to
## rewrite. All of it is placeholder until the story is written.

## The message box a New Game opens on. Clicking OK closes the laptop and
## starts the game.
const WELCOME_TITLE := "Welcome, collector!"
const WELCOME := "This installation of CollectOS 93 has been successfully validated and configured for your use! Open Instructions.txt to get started."

## Instructions: what to do, for a first game.
const README_TITLE := "Instructions.txt"
const README := """HOW THIS WORKS

1. Buy cards here, in the Card Shop: booster packs, booster boxes, and bulk boxes of a thousand cards. Your orders turn up inside the door.

2. Open them. Hold Space with a pack in hand to rip it. A box opens with Space too: a booster box tips out its packs, a bulk box tips its cards out on the floor or the table under it.

3. Sort. Every set has its own binder on the shelf, with nine pockets a page in collector number order. A card in its own pocket locks in with a chime and earns Mana. Anywhere else it glows red.

4. Shelve finished binders in their spaces. A shelf whose binders are all complete lights up.

Every set you open product of unlocks its binder on the shelf.

The laptop goes wherever you like: pick it up and put it down like anything else, and use it from there."""

## The story so far: entries in order, each shown once Cards Organized
## reaches its "after". The first is there from the start.
const STORY_TITLE := "To Do.txt"
const STORY := [
	{"after": 0, "title": "Day one",
		"text": "(Placeholder) The room is finally finished: shelves along the back wall, a binder for every set ever printed, and not a single card in any of them. Time to change that."},
	{"after": 1, "title": "The first card",
		"text": "(Placeholder) One card down. Only a few tens of thousands to go."},
	{"after": 100, "title": "A hundred",
		"text": "(Placeholder) A hundred cards filed. The binders are starting to feel heavy in a good way."},
	{"after": 1000, "title": "A thousand",
		"text": "(Placeholder) A thousand cards in their pockets. Somewhere out there, the oldest sets are waiting."},
]


## The story entries unlocked at `organized` Cards Organized, in order.
static func story_entries(organized: int) -> Array:
	return STORY.filter(func(entry: Dictionary) -> bool: return organized >= entry.after)
