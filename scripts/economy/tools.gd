class_name Tools
extends RefCounted
## The money track: tools bought from the laptop's Tools app, each opened
## by a level and paid for with money (plan: upgrade-tracks-spitball.md,
## "The money track"). An order arrives the next morning like any other
## (Main), and from then the tool is yours for the rest of the game
## (Progression.has_tool). Code a tool changes asks has_tool() for it.
##
## The card sorter (CardSorter) and its upgrades are tools too; the
## hoppers come in a later step.

## Every tool: [id, name, level, price in cents, what it does].
const LIST := [
	["sorting_tray", "Sorting Tray", 1, 2500, "A wooden sorting box for your table. Stand up to 250 duplicates in it, then sell them at a shipping box in one click."],
	["pack_knife", "Pack Knife", 2, 4000, "Ripping a pack takes about a third of the time."],
	["boxes_100", "Bigger Shipping Boxes", 2, 6000, "New shipping boxes hold 100 cards."],
	["sorter", "Card Sorter", 3, 15000, "A machine for the table by the shipping corner. Feed it cards: it sorts them into Needed and Surplus."],
	["surplus_chute", "Surplus Chute", 4, 30000, "The sorter sells Surplus straight into a shipping box set at its side."],
	["boxes_300", "Bulk Shipping Boxes", 4, 40000, "New shipping boxes hold 300 cards."],
	["listings", "Online Listings", 5, 80000, "Sales pay 1.1x."],
	["sorter_mk2", "Sorter Mk II", 6, 120000, "Sorts twice as fast, and keeps Needed to one set at a time, in number order."],
	["bulk_account", "Bulk Account", 9, 300000, "Booster boxes cost 10% less."],
	["storefront", "Storefront", 12, 1500000, "Sales pay 1.2x (in place of Online Listings)."],
]

## Tool icons: <id>.png in colour, <id>_locked.png the grey outline
## (assets/tools/README.txt).
const ICON_PATH := "res://assets/tools/%s%s.png"

## Tools that need another one first: [tool, the one it needs].
const NEEDS := {"surplus_chute": "sorter", "sorter_mk2": "sorter"}

## A tool more than this many levels away shows as "???" in the shop.
const HIDDEN_BEYOND := 1


static func row(id: String) -> Array:
	for entry in LIST:
		if entry[0] == id:
			return entry
	return []


static func tool_name(id: String) -> String:
	var entry := row(id)
	return entry[1] if not entry.is_empty() else id


static func level_of(id: String) -> int:
	var entry := row(id)
	return entry[2] if not entry.is_empty() else 0


static func price_cents(id: String) -> int:
	var entry := row(id)
	return entry[3] if not entry.is_empty() else 0


## The tools that `level` opens, as LIST rows.
static func opened_at(level: int) -> Array:
	return LIST.filter(func(entry: Array) -> bool: return entry[2] == level)


## Whether the shop names tool `id` yet: at most HIDDEN_BEYOND levels away.
static func is_named(id: String) -> bool:
	return level_of(id) <= Progression.level() + HIDDEN_BEYOND


## The tool `id` needs first (owned or on order), or "" for none.
static func needs(id: String) -> String:
	return NEEDS.get(id, "")


## Whether what tool `id` needs is owned or on its way.
static func has_needed(id: String) -> bool:
	var need := needs(id)
	return need == "" or Progression.has_tool(need) or Progression.is_tool_ordered(need)


## Whether tool `id` can be ordered now: its level reached, what it needs
## owned or on order, not owned or already on order itself, and affordable.
static func can_order(id: String) -> bool:
	return not row(id).is_empty() and Progression.level() >= level_of(id) and has_needed(id) \
		and not Progression.has_tool(id) and not Progression.is_tool_ordered(id) and price_cents(id) <= Progression.money


## Tool `id`'s picture: in colour once `unlocked`, else its grey outline.
## Null if the file is missing.
static func icon(id: String, unlocked: bool) -> Texture2D:
	var path := ICON_PATH % [id, "" if unlocked else "_locked"]
	return load(path) if ResourceLoader.exists(path) else null
