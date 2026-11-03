class_name LaptopText
extends RefCounted
## Every word the laptop shows that's story or help, in one place to
## rewrite. All of it is placeholder until the story is written.

## The message box a New Game opens on. Clicking OK closes the laptop and
## starts the game.
const WELCOME_TITLE := "Welcome, collector!"
const WELCOME := "This installation of CollectOS 93 has been successfully configured for your use!\nOpen Instructions.txt to get started."

## Instructions: what to do, for a first game.
const README_TITLE := "Instructions.txt"
const README := """HOW THIS WORKS

1. Buy some cards in the Card Shop. Three packs from the current set have been delivered to get you started, but you'll need to buy some new ones for tomorrow. Your orders will be dropped off next to the door.

2. Open packs! The fun part. Pick up a pack by clicking on it. You can press F to inspect the pack more closely, and hold Space to rip it open.

3. Sort your cards. You've been provided with a binder for every set, with numbered pockets. Filling those binders up with all the cards from a set will give you Mana which will unlock new sets, upgrades, and rewards.

4. Sell extra cards. Prepare them for shipping, and they'll be picked up in the morning. Use the money you earn to buy more packs or upgrade your operation.

Rinse, repeat! There are currently over 30,000 unique cards in Magic the Gathering, not counting alternate arts or treatments. This is going to take a while..."""

## The story so far: entries in order, each shown once Cards Organized
## reaches its "after". The first is there from the start.
const STORY_TITLE := "To Do.txt"
const STORY := [
	{"after": 0, "title": "Let's Get Started!",
		"text": "Congratulations! Your purchase of a starter set from CollectCo has given you everything you need to start your very own Magic the Gathering collection. This device, running the latest version of CollectOS, will be your go-to tool to purchase cards, upgrade your operation, and ultimately achieve all of your collecting dreams!"},
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
