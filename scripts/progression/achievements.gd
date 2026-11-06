extends Node
## Achievements (autoload: Achievements). One for each rare card (RareCards), unlocked when it goes in its
## shadow box in the display cabinets, and one more for putting all of them
## there; their titles and lines are in RARE.
##
## Last, one for each frame of wall art (WallArt), unlocked when its card is
## locked into its own pocket and its art goes up on the wall.
##
## And two for the seven cards Wizards of the Coast banned from every format
## in 2020 for racist content (BANNED_CARDS): one for finding the first of
## them, one for finding all seven. Found means a copy came out of a pack or
## a bulk box (cards_found). Which of the seven have been found is kept with
## the unlocks, so the second one can span games.
##
## Then the odd ones out, in OTHER: tossing the laptop, so far.
##
## Icons 001 to 016 are free: they were the old upgrade tree's sixteen card
## achievements, taken out with the tree. The rest kept their numbers, so
## the first rare card's icon is still 017 (FIRST_ICON).
##
## Unlocked achievements belong to the player, not to one game: they're kept
## in user://achievements.cfg, apart from save files, and New Game doesn't
## clear them.

signal unlocked(index: int)

const SAVE_PATH := "user://achievements.cfg"
const ICON_PATH := "res://assets/achievements/achievement%03d%s.png"
const LOCKED_TITLE := "???"
const LOCKED_TEXT := "This achievement is locked."

## Icon number of the first achievement (index 0); see the note above.
const FIRST_ICON := 17

## The rare card achievements, in RareCards order, then the one for all of
## them: [title, line shown once unlocked]. Placeholders, yours to write.
## Their icons start at 017 (FIRST_ICON).
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
## The seven cards Wizards of the Coast banned in 2020 for racist content,
## by name (every printing counts).
const BANNED_CARDS := [
	"Crusade",
	"Cleanse",
	"Imprison",
	"Invoke Prejudice",
	"Jihad",
	"Pradesh Gypsies",
	"Stone-Throwing Devils",
]
## Their two achievements, for the first found and for all seven: [title,
## line shown once unlocked]. Placeholders, yours to write. Icons carry on
## after the wall art's (066, 067).
const BANNED := [
	["Banned Card", "Found one of the seven cards Wizards of the Coast banned from every format in 2020 for racist imagery or text."],
	["All Seven", "Found all seven cards Wizards of the Coast banned in 2020 for racist content. They stay in this game as part of Magic's history."],
]
## The odd ones out: [key, title, line shown once unlocked]. Icons carry on
## after the banned cards' (068 on). The lines are placeholders, yours to
## write.
const OTHER := [
	["other:laptop_toss", "Hey, That's Expensive", "Tossed the laptop."],
]

## Key ("rare:NN" / "rare:all", "art:NN", "banned:first" / "banned:all" or
## an OTHER key) -> [set name it was filed from (""), date unlocked
## "YYYY-MM-DD"]. Keys from removed achievements (the old tree's card names)
## are kept but never shown.
var _unlocked := {}
## Names of the BANNED_CARDS found so far -> true.
var _banned_found := {}
var _path := SAVE_PATH


func _ready() -> void:
	load_from(SAVE_PATH)


func count() -> int:
	return _other_start() + OTHER.size()


## The achievement's name: a rare card's, the wall art's or its own title.
func card_name(index: int) -> String:
	if is_other(index):
		return OTHER[index - _other_start()][1]
	if is_banned(index):
		return BANNED[index - _banned_start()][0]
	if is_wall_art(index):
		return WallArt.LIST[index - _wall_art_start()][0]
	return RARE[index][0]


func is_rare(index: int) -> bool:
	return index >= 0 and index < _wall_art_start()


func is_wall_art(index: int) -> bool:
	return index >= _wall_art_start() and index < _banned_start()


func is_banned(index: int) -> bool:
	return index >= _banned_start() and index < _other_start()


func is_other(index: int) -> bool:
	return index >= _other_start() and index < count()


## The achievement for rare card `number` (from 1), and the one for all of
## them.
func rare_index(number: int) -> int:
	return number - 1


func all_rare_index() -> int:
	return _wall_art_start() - 1


## The achievement for wall art frame `index` (from 0, in WallArt order).
func wall_art_index(index: int) -> int:
	return _wall_art_start() + index


## The achievement for finding the first banned card, and all seven.
func first_banned_index() -> int:
	return _banned_start()


func all_banned_index() -> int:
	return _banned_start() + 1


## The OTHER achievement saved under `other_key`, or -1.
func other_index(other_key: String) -> int:
	for i in OTHER.size():
		if OTHER[i][0] == other_key:
			return _other_start() + i
	return -1


func _wall_art_start() -> int:
	return RARE.size()


func _banned_start() -> int:
	return _wall_art_start() + WallArt.count()


func _other_start() -> int:
	return _banned_start() + BANNED.size()


## What an unlock is saved under: for the rare cards their number
## ("rare:07") or "rare:all", for the wall art its frame's ("art:03"), the
## banned cards' "banned:first" and "banned:all", and OTHER's own keys, so
## renaming them loses nothing.
func key(index: int) -> String:
	if is_other(index):
		return OTHER[index - _other_start()][0]
	if is_banned(index):
		return "banned:first" if index == first_banned_index() else "banned:all"
	if is_wall_art(index):
		return "art:%02d" % (index - _wall_art_start() + 1)
	if index == all_rare_index():
		return "rare:all"
	return "rare:%02d" % (index + 1)


func is_unlocked(index: int) -> bool:
	return _unlocked.has(key(index))


## The tile's title: its name once unlocked, ??? until then.
func title(index: int) -> String:
	return card_name(index) if is_unlocked(index) else LOCKED_TITLE


## The tile's explainer, once unlocked.
func description(index: int) -> String:
	if not is_unlocked(index):
		return LOCKED_TEXT
	if is_rare(index):
		return RARE[index][1]
	if is_wall_art(index):
		return WallArt.LIST[index - _wall_art_start()][1]
	if is_banned(index):
		return BANNED[index - _banned_start()][1]
	return OTHER[index - _other_start()][2]


## The number on the achievement's icon files (017 for index 0).
static func icon_number(index: int) -> int:
	return index + FIRST_ICON


## The icon for the achievement's state. A missing pair falls back to 001's.
func icon(index: int) -> Texture2D:
	return load(icon_path(icon_number(index), is_unlocked(index)))


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


## Wall art frame `index`'s card was filed, and its art went up.
func wall_art_hung(index: int) -> void:
	unlock(wall_art_index(index), "")


## New copies came out of a pack or a bulk box: any of the BANNED_CARDS
## among them count as found.
func cards_found(copies) -> void:
	for copy: int in copies:
		var name := Collection.card(copy).name
		if name in BANNED_CARDS:
			banned_card_found(name)


## How many of the BANNED_CARDS have been found.
func banned_found_count() -> int:
	return _banned_found.size()


func banned_card_found(name: String) -> void:
	if _banned_found.has(name):
		return
	_banned_found[name] = true
	save()
	unlock(first_banned_index(), "")
	if _banned_found.size() == BANNED_CARDS.size():
		unlock(all_banned_index(), "")


## The laptop went flying (Hands.toss_held).
func laptop_tossed() -> void:
	unlock(other_index("other:laptop_toss"), "")


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
	if not _banned_found.is_empty():
		file.set_value("found", "banned", PackedStringArray(_banned_found.keys()))
	file.save(path)


## Reads unlocked achievements from `path`, which later saves go to too.
## Keys no achievement uses any more are kept, in case they come back.
func load_from(path: String) -> void:
	_path = path
	_unlocked.clear()
	_banned_found.clear()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for name in file.get_value("found", "banned", PackedStringArray()):
		if name in BANNED_CARDS:
			_banned_found[name] = true
	if not file.has_section("unlocked"):
		return
	for name in file.get_section_keys("unlocked"):
		var entry = file.get_value("unlocked", name)
		if entry is Array and entry.size() == 2:
			_unlocked[name] = entry
