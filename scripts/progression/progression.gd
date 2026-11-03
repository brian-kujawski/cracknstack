extends Node
## Mana and the upgrades it buys (autoload: Progression). Every card locked
## into its own pocket pays 1 Mana; finishing a binder, standing a binder in
## its own shelf space and lighting up a shelf pay bonuses, each once. Mana
## is spent on the upgrade tree in /mnt/project-files/plan/m7-upgrade-tree.md:
## five colours, each a row of seven unlocks bought in order. Code that an
## unlock changes asks rank() for it. Unlocks get built a step at a time
## across the colours; ones not built yet are bought but do nothing.
##
## Sorceries also recharge here. A cast starts its cooldown; every card you
## file by hand takes a little off every recharge, but never below a minimum
## share of the cooldown, so sorceries can't feed each other into a spiral.

signal mana_changed(mana: int)
signal unlocked(colour: int, step: int)
## A sorcery was cast or finished recharging.
signal sorceries_changed
## A set was unlocked: the shop delivers its binder and starter packs.
signal set_unlocked(code: String)

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
		["Enlightened Tutor", 1, "See the set of any card on the floor or a table."],
		["Tithe", 1, "Cast: 5 missing cards for this binder glow for 5 s."],
		["Enlightened Tutor", 2, "See the set, number and name of any card on the floor or a table."],
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

## Each sorcery's cooldown in seconds, by rank (I, II, III). Tuning guesses.
const COOLDOWNS := {
	"Tithe": [20.0, 20.0, 20.0],
	"Teleport": [30.0, 30.0],
	"Demonic Tutor": [60.0, 40.0, 20.0],
	"Chain Lightning": [60.0, 45.0, 30.0],
	"Abundance": [45.0, 30.0, 20.0],
}
## Seconds each card filed by hand takes off every recharge in progress.
const FILING_SPEEDUP := 2.0
## No recharge, however much you file, finishes sooner than this share of
## its cooldown.
const MIN_RECHARGE_SHARE := 0.5

var mana := 0
## Debug builds can buy past what they can afford, into negative Mana, so
## every unlock can be tried while testing.
var allow_debt := OS.is_debug_build()

## Steps bought in each colour; the next one to buy is at this index.
var _bought: Array[int] = []
## Bonuses already paid, so none can be farmed by taking a binder down and
## putting it back.
var _paid := {}
## Sorceries recharging: node -> [seconds left, seconds before filing can't
## cut it any shorter].
var _recharging := {}
## Sorceries cast and waiting for something to set them off (Chain
## Lightning waits for your next lock-in).
var _armed := {}
## Sets unlocked so far: code -> true. A locked set's binder waits out of
## sight on the shelf, with no plate, and can't be bought or taken down;
## unlocking delivers it with a few packs (Main). Until levels unlock sets,
## the Card Shop's Unlock button does.
var _unlocked_sets := {}
## Whether sets lock at all. Checks written before set locking turn it off.
var locks_sets := true


func _init() -> void:
	reset()


## Back to a new game: no Mana, nothing bought.
func reset() -> void:
	mana = 0
	_bought.assign(COLOURS.map(func(_c) -> int: return 0))
	_paid.clear()
	_recharging.clear()
	_armed.clear()
	_unlocked_sets.clear()
	mana_changed.emit(mana)
	sorceries_changed.emit()


## Whether a set's binder can be taken down and used.
func is_set_unlocked(code: String) -> bool:
	return not locks_sets or _unlocked_sets.has(code)


## Unlocks a set. Returns whether it was locked.
func unlock_set(code: String) -> bool:
	if _unlocked_sets.has(code):
		return false
	_unlocked_sets[code] = true
	set_unlocked.emit(code)
	return true


## Everything here, for a save (ShopSave). Bought steps are kept by name
## (step_name), not by position, so a reordered tree keeps what was bought.
func save_state() -> Dictionary:
	var bought := []
	for colour in COLOURS.size():
		var names := PackedStringArray()
		for step in _bought[colour]:
			names.append(step_name(colour, step))
		bought.append(names)
	var recharging := {}
	for node in _recharging:
		recharging[node] = PackedFloat32Array(_recharging[node])
	return {"mana": mana, "bought": bought, "paid": PackedStringArray(_paid.keys()),
		"recharging": recharging, "armed": PackedStringArray(_armed.keys()),
		"sets": PackedStringArray(_unlocked_sets.keys())}


## Puts back what save_state() kept. Each colour keeps the steps bought, in
## order, for as long as they match the tree; any saved step that no longer
## does is refunded at its price.
func restore_state(saved: Dictionary) -> void:
	reset()
	mana = int(saved.get("mana", 0))
	var bought: Array = saved.get("bought", [])
	for colour in mini(bought.size(), COLOURS.size()):
		var names: PackedStringArray = bought[colour]
		var kept := 0
		while kept < names.size() and kept < PRICES.size() and step_name(colour, kept) == names[kept]:
			kept += 1
		_bought[colour] = kept
		for step in range(kept, names.size()):
			mana += PRICES[mini(step, PRICES.size() - 1)]
	for key in saved.get("paid", PackedStringArray()):
		_paid[key] = true
	var recharging: Dictionary = saved.get("recharging", {})
	for node in recharging:
		var timer := Array(recharging[node])
		if COOLDOWNS.has(node) and rank(node) > 0 and timer.size() == 2:
			_recharging[node] = timer
	for node in saved.get("armed", PackedStringArray()):
		if rank(node) > 0:
			_armed[node] = true
	for code in saved.get("sets", PackedStringArray()):
		_unlocked_sets[code] = true
	mana_changed.emit(mana)
	sorceries_changed.emit()


func _process(delta: float) -> void:
	tick(delta)


## Runs every recharge on by `seconds`. Stops with the game while paused.
func tick(seconds: float) -> void:
	if _recharging.is_empty():
		return
	for node in _recharging.keys():
		var timer: Array = _recharging[node]
		timer[0] -= seconds
		timer[1] -= seconds
		if timer[0] <= 0.0:
			_recharging.erase(node)
			sorceries_changed.emit()


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


## Whether a sorcery has been learned and is ready to cast.
func can_cast(node: String) -> bool:
	return rank(node) > 0 and not _recharging.has(node)


## Seconds until a sorcery can be cast again (0 when ready).
func recharge_left(node: String) -> float:
	return maxf(_recharging[node][0], 0.0) if _recharging.has(node) else 0.0


## Spends a cast: the sorcery starts recharging. Returns false if it can't be
## cast now.
func cast(node: String) -> bool:
	if not can_cast(node):
		return false
	var cooldown: float = COOLDOWNS[node][rank(node) - 1]
	_recharging[node] = [cooldown, cooldown * MIN_RECHARGE_SHARE]
	sorceries_changed.emit()
	return true


## A card filed by your own hand (not by a sorcery) speeds every recharge.
func card_filed_by_hand() -> void:
	for node in _recharging.keys():
		var timer: Array = _recharging[node]
		timer[0] = maxf(timer[0] - FILING_SPEEDUP, timer[1])
	tick(0.0)


## Casts a sorcery that waits for a trigger: it starts recharging now and
## stays armed until fire() is called. Returns false if it can't be cast.
func arm(node: String) -> bool:
	if not cast(node):
		return false
	_armed[node] = true
	sorceries_changed.emit()
	return true


func is_armed(node: String) -> bool:
	return _armed.has(node)


## Sets off an armed sorcery. Returns whether it was armed.
func fire(node: String) -> bool:
	if not _armed.erase(node):
		return false
	sorceries_changed.emit()
	return true
