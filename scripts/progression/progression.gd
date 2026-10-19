extends Node
## Mana and the upgrades it buys (autoload: Progression). Every card locked
## into its own pocket pays 1 Mana; finishing a binder, standing a binder in
## its own shelf space and lighting up a shelf pay bonuses, each once. Mana
## is spent on the upgrade tree in /mnt/project-files/plan/m7-upgrade-tree.md:
## five colours, each a row of seven unlocks bought in order. Unlocks are
## recorded here but do nothing yet; each gets built one at a time.

signal mana_changed(mana: int)
signal unlocked(colour: int, step: int)

const CARD_LOCKED := 1
## Finishing a binder pays this share of its card count (rounded up).
const BINDER_COMPLETE_SHARE := 0.1
const BINDER_SHELVED := 5
const SECTION_LIT := 25

## Every colour's row uses the same prices, step by step.
const PRICES := [20, 40, 90, 200, 400, 900, 2000]

## Each colour's row of unlocks in buying order: [node, rank, what it does].
## A rank of 0 marks a node that's bought once, with no numeral.
const COLOURS := [
	{"name": "White", "steps": [
		["Remember the Fallen", 0, "Remember the name and number of every card you've held."],
		["Enlightened Tutor", 1, "See the set of any card on the floor."],
		["Tithe", 1, "Cast: 5 missing cards for this binder glow for 5 s."],
		["Enlightened Tutor", 2, "See the set, number and name of any card on the floor."],
		["Tithe", 2, "Tithe lights 10 missing cards for 10 s."],
		["Tithe", 3, "Tithe lights every missing card for 15 s."],
		["Serra's Blessing", 0, "Tithe is always on for the binder you're using."]]},
	{"name": "Blue", "steps": [
		["Snap", 1, "Cards and binders move 50% faster."],
		["Teleport", 1, "Cast: the held card flies to its binder and files itself."],
		["Snap", 2, "Cards and binders move twice as fast."],
		["Brainstorm", 1, "Finishing a page by hand pulls in 1 missing card for that binder."],
		["Teleport", 2, "Teleport sends your whole hand."],
		["Brainstorm", 2, "Brainstorm pulls in 3 cards."],
		["Brainstorm", 3, "Brainstorm pulls in 9 cards."]]},
	{"name": "Black", "steps": [
		["Demonic Tutor", 1, "Cast: the card for the aimed pocket comes to your hand. 60 s cooldown."],
		["Unmask", 1, "Pile flips toss 8 cards, most landing face up."],
		["Demonic Tutor", 2, "Demonic Tutor's cooldown drops to 40 s."],
		["Unmask", 2, "Pile flips toss 16 cards, all face up."],
		["Demonic Consultation", 1, "Flipped cards for an open binder hover for 5 s."],
		["Demonic Tutor", 3, "Demonic Tutor's cooldown drops to 20 s."],
		["Demonic Consultation", 2, "Flipped cards hover for 15 s."]]},
	{"name": "Red", "steps": [
		["Fervor", 0, "Walk and crouch-walk 50% faster."],
		["Chain Lightning", 1, "Cast: your next filed card lights 1 missing card from its page. 60 s cooldown."],
		["Shunt", 1, "Click anywhere on the right open pages to file a card."],
		["Chain Lightning", 2, "Chain Lightning lights 3 cards. 45 s cooldown."],
		["Shunt", 2, "Click anywhere on the right binder to file a card."],
		["Chain Lightning", 3, "Chain Lightning lights the whole page. 30 s cooldown."],
		["Shunt", 3, "File into the right binder even when it's closed."]]},
	{"name": "Green", "steps": [
		["Spider Climb", 0, "Reach 30% further."],
		["Harmonize", 1, "Hold 3 cards at once."],
		["Abundance", 1, "Cast: the next unfiled cards after the held one come to your hand."],
		["Harmonize", 2, "Hold 7 cards at once."],
		["Abundance", 2, "Abundance's cooldown gets shorter."],
		["Harmonize", 3, "Hold 15 cards at once."],
		["Abundance", 3, "Abundance's cooldown gets shorter still."]]},
]

const NUMERALS := ["", "I", "II", "III"]

var mana := 0
## Debug builds can buy past what they can afford, into negative Mana, so
## every unlock can be tried while testing.
var allow_debt := OS.is_debug_build()

## Steps bought in each colour; the next one to buy is at this index.
var _bought: Array[int] = []
## Bonuses already paid, so none can be farmed by taking a binder down and
## putting it back.
var _paid := {}


func _init() -> void:
	reset()


## Back to a new game: no Mana, nothing bought.
func reset() -> void:
	mana = 0
	_bought.assign(COLOURS.map(func(_c) -> int: return 0))
	_paid.clear()
	mana_changed.emit(mana)


func earn(amount: int) -> void:
	mana += amount
	mana_changed.emit(mana)


## Pays a bonus the first time `key` earns it; later calls do nothing.
func earn_once(key: String, amount: int) -> void:
	if _paid.has(key):
		return
	_paid[key] = true
	earn(amount)


static func binder_complete_bonus(card_count: int) -> int:
	return ceili(card_count * BINDER_COMPLETE_SHARE)


static func step_name(colour: int, step: int) -> String:
	var entry: Array = COLOURS[colour].steps[step]
	return entry[0] if entry[1] == 0 else "%s %s" % [entry[0], NUMERALS[entry[1]]]


## What an unlock does, in one line for the menu.
static func step_effect(colour: int, step: int) -> String:
	return COLOURS[colour].steps[step][2]


static func price(step: int) -> int:
	return PRICES[step]


func bought_count(colour: int) -> int:
	return _bought[colour]


func is_bought(colour: int, step: int) -> bool:
	return step < _bought[colour]


## Only a colour's next step can be bought, and only with the Mana for it
## (unless debt is allowed).
func can_buy(colour: int, step: int) -> bool:
	return step == _bought[colour] and step < PRICES.size() and (allow_debt or mana >= price(step))


func buy(colour: int, step: int) -> bool:
	if not can_buy(colour, step):
		return false
	_bought[colour] += 1
	earn(-price(step))
	unlocked.emit(colour, step)
	return true


## The rank owned of a node, e.g. rank("Tithe") is 2 once Tithe II is bought.
## Nodes bought once (no numeral) report 1.
func rank(node: String) -> int:
	var owned := 0
	for colour in COLOURS.size():
		var steps: Array = COLOURS[colour].steps
		for step in _bought[colour]:
			if steps[step][0] == node:
				owned = maxi(owned, maxi(steps[step][1], 1))
	return owned
