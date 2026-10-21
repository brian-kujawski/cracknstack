extends Node
## Achievements (autoload: Achievements). Every upgrade in the M7 tree is
## named after a real Magic card, and filing that card (locking it into its
## own pocket, by hand or by Teleport) unlocks its achievement. Most of these
## cards come from sets beyond Khans of Tarkir, so they arrive with the
## bigger import (M8).
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

## Card name -> [set name it was filed from, date unlocked "YYYY-MM-DD"].
var _unlocked := {}
var _path := SAVE_PATH


func _ready() -> void:
	load_from(SAVE_PATH)


func count() -> int:
	return LIST.size()


func card_name(index: int) -> String:
	return LIST[index][0]


func colour(index: int) -> int:
	return LIST[index][1]


func is_unlocked(index: int) -> bool:
	return _unlocked.has(card_name(index))


## The tile's title: the card's name once unlocked, ??? until then.
func title(index: int) -> String:
	return card_name(index) if is_unlocked(index) else LOCKED_TITLE


## The tile's explainer: "Filed Tithe from Visions." once unlocked.
func description(index: int) -> String:
	if not is_unlocked(index):
		return LOCKED_TEXT
	return "Filed %s from %s." % [card_name(index), _unlocked[card_name(index)][0]]


## The icon for the achievement's state. A missing pair falls back to 001's.
func icon(index: int) -> Texture2D:
	return load(icon_path(index + 1, is_unlocked(index)))


## achievementNNN.png or achievementNNN_locked.png, or 001's if that number
## has no icon yet.
static func icon_path(number: int, unlocked: bool) -> String:
	var suffix := "" if unlocked else "_locked"
	var path := ICON_PATH % [number, suffix]
	return path if ResourceLoader.exists(path) else ICON_PATH % [1, suffix]


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
	_unlocked[card_name(index)] = [set_name, Time.get_date_string_from_system()]
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
