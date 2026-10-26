extends Node
## Achievements (autoload: Achievements). Every upgrade in the M7 tree is
## named after a real Magic card, and filing that card (locking it into its
## own pocket, by hand or by Teleport) unlocks its achievement. Most of these
## cards come from sets beyond Khans of Tarkir, so they arrive with the
## bigger import (M8).
##
## Then one for each rare card (RareCards), unlocked when it goes in its
## shadow box in the display cabinets, and one more for putting all of them
## there; their titles and lines are in RARE.
##
## Unlocked achievements belong to the player, not to one game: they're kept
## in user://achievements.cfg, apart from save files, and New Game doesn't
## clear them.

signal unlocked(index: int)

const SAVE_PATH := "user://achievements.cfg"
const ICON_PATH := "res://assets/achievements/achievement%03d%s.png"
const LOCKED_TITLE := "???"
const LOCKED_TEXT := "This achievement is locked."

## Every achievement, one per card the upgrade tree is named after, by colour
## (white, blue, black, red, green) and in each colour in buying order:
## [card name, colour]. Icons are numbered in this order, from 001.
const LIST := [
	["Remember the Fallen", 0],
	["Enlightened Tutor", 0],
	["Tithe", 0],
	["Serra's Blessing", 0],
	["Snap", 1],
	["Teleport", 1],
	["Brainstorm", 1],
	["Demonic Tutor", 2],
	["Unmask", 2],
	["Demonic Consultation", 2],
	["Fervor", 3],
	["Chain Lightning", 3],
	["Shunt", 3],
	["Spider Climb", 4],
	["Harmonize", 4],
	["Abundance", 4],
]

## The rare card achievements, in RareCards order, then the one for all of
## them: [title, line shown once unlocked]. Placeholders, yours to write.
## Icons carry on numbering after LIST's (017 is the first rare card's).
const RARE := [
	["Rare Card 01", "Put Rare Card 01 on display."],
	["Rare Card 02", "Put Rare Card 02 on display."],
	["Rare Card 03", "Put Rare Card 03 on display."],
	["Rare Card 04", "Put Rare Card 04 on display."],
	["Rare Card 05", "Put Rare Card 05 on display."],
	["Rare Card 06", "Put Rare Card 06 on display."],
	["Rare Card 07", "Put Rare Card 07 on display."],
	["Rare Card 08", "Put Rare Card 08 on display."],
	["Rare Card 09", "Put Rare Card 09 on display."],
	["Rare Card 10", "Put Rare Card 10 on display."],
	["Rare Card 11", "Put Rare Card 11 on display."],
	["Rare Card 12", "Put Rare Card 12 on display."],
	["Rare Card 13", "Put Rare Card 13 on display."],
	["Rare Card 14", "Put Rare Card 14 on display."],
	["Rare Card 15", "Put Rare Card 15 on display."],
	["Rare Card 16", "Put Rare Card 16 on display."],
	["Rare Card 17", "Put Rare Card 17 on display."],
	["Rare Card 18", "Put Rare Card 18 on display."],
	["Rare Card 19", "Put Rare Card 19 on display."],
	["Rare Card 20", "Put Rare Card 20 on display."],
	["Rare Card 21", "Put Rare Card 21 on display."],
	["Rare Card 22", "Put Rare Card 22 on display."],
	["Rare Card 23", "Put Rare Card 23 on display."],
	["Rare Card 24", "Put Rare Card 24 on display."],
	["Rare Card 25", "Put Rare Card 25 on display."],
	["Rare Card 26", "Put Rare Card 26 on display."],
	["Rare Card 27", "Put Rare Card 27 on display."],
	["Rare Card 28", "Put Rare Card 28 on display."],
	["Rare Card 29", "Put Rare Card 29 on display."],
	["Rare Card 30", "Put Rare Card 30 on display."],
	["Rare Card 31", "Put Rare Card 31 on display."],
	["Rare Card 32", "Put Rare Card 32 on display."],
	["Rare Card 33", "Put Rare Card 33 on display."],
	["Rare Card 34", "Put Rare Card 34 on display."],
	["Rare Card 35", "Put Rare Card 35 on display."],
	["Rare Card 36", "Put Rare Card 36 on display."],
	["Collector", "Put every rare card on display."],
]
## colour() of the rare card achievements, which belong to no colour.
const RARE_GROUP := -1

## Key (a card name, or "rare:NN" / "rare:all") -> [set name it was filed
## from ("" for rare cards), date unlocked "YYYY-MM-DD"].
var _unlocked := {}
var _path := SAVE_PATH


func _ready() -> void:
	load_from(SAVE_PATH)


func count() -> int:
	return LIST.size() + RARE.size()


## The achievement's name: the card it's named after, or a rare one's title.
func card_name(index: int) -> String:
	return LIST[index][0] if index < LIST.size() else RARE[index - LIST.size()][0]


## Its colour in the upgrade tree, or RARE_GROUP.
func colour(index: int) -> int:
	return LIST[index][1] if index < LIST.size() else RARE_GROUP


func is_rare(index: int) -> bool:
	return index >= LIST.size()


## The achievement for rare card `number` (from 1), and the one for all of
## them.
func rare_index(number: int) -> int:
	return LIST.size() + number - 1


func all_rare_index() -> int:
	return count() - 1


## What an unlock is saved under: the card's name, or for the rare cards
## their number ("rare:07") or "rare:all", so renaming them loses nothing.
func key(index: int) -> String:
	if index < LIST.size():
		return LIST[index][0]
	if index == all_rare_index():
		return "rare:all"
	return "rare:%02d" % (index - LIST.size() + 1)


func is_unlocked(index: int) -> bool:
	return _unlocked.has(key(index))


## The tile's title: the card's name once unlocked, ??? until then.
func title(index: int) -> String:
	return card_name(index) if is_unlocked(index) else LOCKED_TITLE


## The tile's explainer: "Filed Tithe from Visions." once unlocked (a rare
## one's own line).
func description(index: int) -> String:
	if not is_unlocked(index):
		return LOCKED_TEXT
	if is_rare(index):
		return RARE[index - LIST.size()][1]
	return "Filed %s from %s." % [card_name(index), _unlocked[key(index)][0]]


## The icon for the achievement's state. A missing pair falls back to 001's.
func icon(index: int) -> Texture2D:
	return load(icon_path(index + 1, is_unlocked(index)))


## achievementNNN.png or achievementNNN_locked.png, or 001's if that number
## has no icon yet.
static func icon_path(number: int, unlocked: bool) -> String:
	var suffix := "" if unlocked else "_locked"
	var path := ICON_PATH % [number, suffix]
	return path if ResourceLoader.exists(path) else ICON_PATH % [1, suffix]


## Rare card `number` went in its shadow box; with `all_displayed`, it was
## the last of them, and that has its own achievement too.
func rare_card_displayed(number: int, all_displayed: bool) -> void:
	unlock(rare_index(number), "")
	if all_displayed:
		unlock(all_rare_index(), "")


func index_of(name: String) -> int:
	for index in LIST.size():
		if LIST[index][0] == name:
			return index
	return -1


## A card was locked into its own pocket. Matched by name, whichever set's
## printing it is.
func card_filed(card: CardData) -> void:
	var index := index_of(card.name)
	if index >= 0 and not is_unlocked(index):
		unlock(index, CardDatabase.get_set(card.set_code).name)


func unlock(index: int, set_name: String) -> void:
	if is_unlocked(index):
		return
	_unlocked[key(index)] = [set_name, Time.get_date_string_from_system()]
	save()
	unlocked.emit(index)


func save(path := _path) -> void:
	var file := ConfigFile.new()
	for name in _unlocked:
		file.set_value("unlocked", name, _unlocked[name])
	file.save(path)


## Reads unlocked achievements from `path`, which later saves go to too.
## Names no longer in LIST are kept, in case they come back.
func load_from(path: String) -> void:
	_path = path
	_unlocked.clear()
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section("unlocked"):
		return
	for name in file.get_section_keys("unlocked"):
		var entry = file.get_value("unlocked", name)
		if entry is Array and entry.size() == 2:
			_unlocked[name] = entry
