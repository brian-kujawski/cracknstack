extends Node
## Mana, levels and money (autoload: Progression). Every card locked into its
## own pocket pays 1 Mana; finishing a binder, standing a binder in its own
## shelf space and lighting up a shelf pay bonuses, each once. Mana is never
## spent: the total earned sets your level (LEVELS), and each level opens the
## abilities listed for it in ABILITIES
## (/mnt/project-files/plan/upgrade-tracks-spitball.md). Code that an ability
## changes asks rank() for it.
##
## Money is kept here too, in cents: it comes from selling cards (ShippingBox)
## and goes on product from the Card Shop (Prices). It's a separate currency
## from Mana.
##
## Sorceries (abilities with a key) also recharge here. A cast starts its
## cooldown; every card you file by hand takes a little off every recharge,
## but never below a minimum share of the cooldown, so sorceries can't feed
## each other into a spiral.

signal mana_changed(mana: int)
## Money went up or down; `cents` is the new balance.
signal money_changed(cents: int)
## A sorcery was cast or finished recharging.
signal sorceries_changed
## A set was unlocked: the shop delivers its binder and starter packs.
signal set_unlocked(code: String)
## A tool arrived.
signal tools_changed
## The level went up; `level` is the new one.
signal level_changed(level: int)

const CARD_LOCKED := 1
## Finishing a binder pays this share of its card count (rounded up).
const BINDER_COMPLETE_SHARE := 0.1
const BINDER_SHELVED := 5
const SECTION_LIT := 25

## Total Mana earned to reach each level: Level L at 85 × (L − 1)², up to
## Level 20. LEVELS[L - 1] is Level L's threshold.
const LEVELS := [0, 85, 340, 765, 1360, 2125, 3060, 4165, 5440, 6885,
	8500, 10285, 12240, 14365, 16660, 19125, 21760, 24565, 27540, 30685]

## What each level opens: [level, node, rank, title, what it does]. rank()
## gives a node's highest rank whose level you've reached. Levels with no
## ability open tools on the laptop instead (later).
const ABILITIES := [
	[2, "Fact or Fiction", 1, "Fact or Fiction", "You will now remember whether you have already collected a copy of a given card."],
	[3, "Shunt", 1, "Shunt I", "Click anywhere on the open pages to file a card."],
	[4, "Tithe", 1, "Tithe", "Hold a Needed card and its binder glows. Take it out and it opens at the card's page."],
	[5, "Howling Mine", 1, "Howling Mine I", "Three free packs arrive every morning."],
	[6, "Snap", 2, "Snap", "Cards and binders move twice as fast."],
	[7, "Burning Wish", 1, "Burning Wish I", "A set's singles go on sale at 90% collected, at 1.3x value."],
	[8, "Black Market", 1, "Black Market", "Sales pay 10% more."],
	[10, "Shunt", 3, "Shunt II", "Click the right binder anywhere, open or closed, to file a card."],
	[11, "Lucky Clover", 1, "Lucky Clover", "Mythics turn up 1 time in 6 instead of 1 in 8."],
	[12, "Quicken", 1, "Quicken", "The first order each day arrives within the hour."],
	[14, "Demonic Tutor", 1, "Demonic Tutor", "Each pack slot is a little more likely to be a card you still need."],
	[15, "Teleport", 2, "Teleport", "Cast: the cards in your hand fly to their binders and file themselves."],
	[16, "Howling Mine", 2, "Howling Mine II", "A free booster box arrives every seventh morning too."],
	[17, "Ancestral Recall", 1, "Ancestral Recall", "1 pack in 15 has a bonus extra rare."],
	[18, "Burning Wish", 2, "Burning Wish II", "Singles go on sale at 80% collected, at 1.2x value."],
]

## Each sorcery's cooldown in seconds, by rank. Tuning guesses.
const COOLDOWNS := {
	"Teleport": [30.0, 30.0],
}
## Seconds each card filed by hand takes off every recharge in progress.
const FILING_SPEEDUP := 2.0
## No recharge, however much you file, finishes sooner than this share of
## its cooldown.
const MIN_RECHARGE_SHARE := 0.5
## All the Mana earned. It's never spent: it sets the level.
var mana := 0
## Money, in cents.
var money := 0
## Bonuses already paid, so none can be farmed by taking a binder down and
## putting it back.
var _paid := {}
## Sorceries recharging: node -> [seconds left, seconds before filing can't
## cut it any shorter].
var _recharging := {}
## Sets unlocked so far: code -> true. A locked set's binder waits out of
## sight on the shelf, with no plate, and can't be bought or taken down;
## unlocking delivers it with a few packs (Main). Until levels unlock sets,
## the Card Shop's Unlock button does.
var _unlocked_sets := {}
## One-time messages already shown in this game: key -> true (the sale
## confirmation's first, shorter wording).
var _notes := {}
## Tools bought from the laptop (Tools): id -> true once delivered, and
## ids paid for and waiting for the morning.
var _tools := {}
var _tools_ordered := {}
## Whether sets lock at all. Checks written before set locking turn it off.
var locks_sets := true


func _init() -> void:
	reset()


## Back to a new game: no Mana, Level 1.
func reset() -> void:
	mana = 0
	money = 0
	_paid.clear()
	_recharging.clear()
	_tools.clear()
	_tools_ordered.clear()
	_unlocked_sets.clear()
	_notes.clear()
	mana_changed.emit(mana)
	money_changed.emit(money)
	sorceries_changed.emit()


## Adds `cents` to the money (a sale).
func earn_money(cents: int) -> void:
	money += maxi(cents, 0)
	money_changed.emit(money)


## Takes `cents` off the money, if there's enough. Returns whether it paid.
func spend_money(cents: int) -> bool:
	if cents < 0 or cents > money:
		return false
	money -= cents
	money_changed.emit(money)
	return true


## Money as it's written everywhere: "$1,234.56".
static func money_text(cents: int) -> String:
	var dollars := str(absi(cents) / 100)
	var grouped := ""
	while dollars.length() > 3:
		grouped = "," + dollars.right(3) + grouped
		dollars = dollars.left(dollars.length() - 3)
	return "%s$%s%s.%02d" % ["-" if cents < 0 else "", dollars, grouped, absi(cents) % 100]


## Whether tool `id` (Tools.LIST) is yours.
func has_tool(id: String) -> bool:
	return _tools.has(id)


## Whether tool `id` is paid for and on its way.
func is_tool_ordered(id: String) -> bool:
	return _tools_ordered.has(id)


func mark_tool_ordered(id: String) -> void:
	_tools_ordered[id] = true


## Tool `id` has arrived (or is given outright, in tests): it's yours.
func give_tool(id: String) -> void:
	_tools_ordered.erase(id)
	_tools[id] = true
	tools_changed.emit()


## Whether one-time message `key` has been shown in this game.
func has_note(key: String) -> bool:
	return _notes.has(key)


## Remembers that one-time message `key` has been shown.
func mark_note(key: String) -> void:
	_notes[key] = true


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


## Everything here, for a save (ShopSave). Levels aren't kept: they come
## from the Mana.
func save_state() -> Dictionary:
	var recharging := {}
	for node in _recharging:
		recharging[node] = PackedFloat32Array(_recharging[node])
	return {"mana": mana, "money": money, "paid": PackedStringArray(_paid.keys()),
		"recharging": recharging, "sets": PackedStringArray(_unlocked_sets.keys()),
		"notes": PackedStringArray(_notes.keys()), "tools": PackedStringArray(_tools.keys()),
		"tools_ordered": PackedStringArray(_tools_ordered.keys())}


## Puts back what save_state() kept. Saves from the old upgrade tree, where
## Mana was spent, count everything they earned ("mana_earned").
func restore_state(saved: Dictionary) -> void:
	reset()
	mana = maxi(int(saved.get("mana", 0)), int(saved.get("mana_earned", 0)))
	money = int(saved.get("money", 0))
	for key in saved.get("paid", PackedStringArray()):
		_paid[key] = true
	var recharging: Dictionary = saved.get("recharging", {})
	for node in recharging:
		var timer := Array(recharging[node])
		if COOLDOWNS.has(node) and rank(node) > 0 and timer.size() == 2:
			_recharging[node] = timer
	for code in saved.get("sets", PackedStringArray()):
		_unlocked_sets[code] = true
	for key in saved.get("notes", PackedStringArray()):
		_notes[key] = true
	for id in saved.get("tools", PackedStringArray()):
		_tools[id] = true
	for id in saved.get("tools_ordered", PackedStringArray()):
		_tools_ordered[id] = true
	mana_changed.emit(mana)
	money_changed.emit(money)
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


## Adds earned Mana. Each level it crosses is announced (level_changed).
func earn(amount: int) -> void:
	if amount <= 0:
		return
	var before := level()
	mana += amount
	mana_changed.emit(mana)
	for reached in range(before + 1, level() + 1):
		level_changed.emit(reached)


## The level the Mana earned has reached, 1 to 20.
func level() -> int:
	return level_at(mana)


static func level_at(earned: int) -> int:
	var reached := 1
	while reached < LEVELS.size() and earned >= LEVELS[reached]:
		reached += 1
	return reached


static func max_level() -> int:
	return LEVELS.size()


## Mana earned since this level began.
func level_progress() -> int:
	return mana - LEVELS[level() - 1]


## Mana from this level to the next (0 at the top level).
func level_span() -> int:
	var reached := level()
	return LEVELS[reached] - LEVELS[reached - 1] if reached < LEVELS.size() else 0


## Debug and tests: earns just enough Mana to reach `target` (never lowers it).
func reach_level(target: int) -> void:
	target = clampi(target, 1, LEVELS.size())
	earn(LEVELS[target - 1] - mana)


## Debug: one level up (the pause menu's Level +1).
func debug_level_up() -> void:
	reach_level(level() + 1)


## The abilities that `at` opens, as ABILITIES rows.
static func abilities_at(at: int) -> Array:
	return ABILITIES.filter(func(row: Array) -> bool: return row[0] == at)


## The next level, above the current one, that opens an ability, with its
## rows; [] at the end.
func next_unlock() -> Array:
	for at in range(level() + 1, LEVELS.size() + 1):
		var rows := abilities_at(at)
		if not rows.is_empty():
			return [at, rows]
	return []


## Pays a bonus the first time `key` earns it; later calls do nothing.
func earn_once(key: String, amount: int) -> void:
	if _paid.has(key):
		return
	_paid[key] = true
	earn(amount)


static func binder_complete_bonus(card_count: int) -> int:
	return ceili(card_count * BINDER_COMPLETE_SHARE)


## The rank reached of a node, e.g. rank("Shunt") is 3 from Level 10.
## Nodes with a single rank report 1. 0 means not reached yet.
func rank(node: String) -> int:
	var reached := level()
	var owned := 0
	for row in ABILITIES:
		if row[1] == node and row[0] <= reached:
			owned = maxi(owned, row[2])
	return owned


static func ability_level(node: String, at_rank := 1) -> int:
	for row in ABILITIES:
		if row[1] == node and row[2] >= at_rank:
			return row[0]
	return 0


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
