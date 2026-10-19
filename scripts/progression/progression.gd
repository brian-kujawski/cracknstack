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

## Each colour's row of unlocks in buying order: [node, rank]. A rank of 0
## marks a node that's bought once, with no numeral.
const COLOURS := [
	{"name": "White", "steps": [
		["Remember the Fallen", 0], ["Enlightened Tutor", 1], ["Tithe", 1], ["Enlightened Tutor", 2],
		["Tithe", 2], ["Tithe", 3], ["Serra's Blessing", 0]]},
	{"name": "Blue", "steps": [
		["Snap", 1], ["Teleport", 1], ["Snap", 2], ["Brainstorm", 1],
		["Teleport", 2], ["Brainstorm", 2], ["Brainstorm", 3]]},
	{"name": "Black", "steps": [
		["Demonic Tutor", 1], ["Unmask", 1], ["Demonic Tutor", 2], ["Unmask", 2],
		["Demonic Consultation", 1], ["Demonic Tutor", 3], ["Demonic Consultation", 2]]},
	{"name": "Red", "steps": [
		["Fervor", 0], ["Chain Lightning", 1], ["Shunt", 1], ["Chain Lightning", 2],
		["Shunt", 2], ["Chain Lightning", 3], ["Shunt", 3]]},
	{"name": "Green", "steps": [
		["Spider Climb", 0], ["Harmonize", 1], ["Abundance", 1], ["Harmonize", 2],
		["Abundance", 2], ["Harmonize", 3], ["Abundance", 3]]},
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
