class_name Chapters
extends RefCounted
## The chapters: which sets the game unlocks together, read from one text
## file (data/chapters.txt) so they're easy to rearrange. A new game opens
## Chapter 1: every set in it unlocks, each with a sealed booster box
## (Main.open_chapter). Once every one of its binders is complete, the next
## chapter opens the same way.
##
## The game plays the chapters over the sets that are loaded (playable): a
## set the file lists but the data doesn't have is left out, and a loaded
## set the file doesn't list gets a chapter of its own after the file's, so
## nothing is out of reach (the placeholder sets play one at a time).
##
## The file: a line starting with "Chapter" begins a chapter (the rest of
## the line is its name); then one set code per line. "#" starts a comment.

const PATH := "res://data/chapters.txt"

## Each chapter: {"name": String, "sets": PackedStringArray}, in order.
static var _chapters: Array[Dictionary] = []
static var _loaded := false
## playable()'s last answer, and the sets it was for.
static var _playable: Array[PackedStringArray] = []
static var _playable_for := PackedStringArray()
static var _playable_ready := false


## All chapters, in order (read from PATH the first time).
static func all() -> Array[Dictionary]:
	if not _loaded:
		use_text(FileAccess.get_file_as_string(PATH) if FileAccess.file_exists(PATH) else "")
	return _chapters


## Reads chapters from `text` instead of the file (tests, and the loader).
static func use_text(text: String) -> void:
	_chapters = parse(text)
	_loaded = true
	_playable_ready = false


## Goes back to reading the file.
static func reload() -> void:
	_loaded = false
	_playable_ready = false


## Chapters from the file's text. Set codes are upper-cased; a set listed
## twice keeps only its first place.
static func parse(text: String) -> Array[Dictionary]:
	var chapters: Array[Dictionary] = []
	var seen := {}
	for raw in text.split("\n"):
		var line := raw.get_slice("#", 0).strip_edges()
		if line.is_empty():
			continue
		if line.to_lower().begins_with("chapter"):
			chapters.append({"name": line, "sets": PackedStringArray()})
			continue
		var code := line.get_slice(" ", 0).get_slice("\t", 0).to_upper()
		if chapters.is_empty():
			push_warning("%s: %s is listed before any Chapter line, left out" % [PATH, code])
			continue
		if seen.has(code):
			push_warning("%s: %s is listed twice, kept in %s" % [PATH, code, seen[code]])
			continue
		seen[code] = chapters.back().name
		chapters.back().sets.append(code)
	return chapters


## The chapter set `code` is in, counting from 1; 0 when it's in none.
static func chapter_of(code: String) -> int:
	var chapters := all()
	for i in chapters.size():
		if code.to_upper() in chapters[i].sets:
			return i + 1
	return 0


## The chapters the game plays, as each one's set codes, for the loaded
## sets `codes` (the order unlisted sets' chapters come in): see the top.
static func playable(codes: PackedStringArray) -> Array[PackedStringArray]:
	var listed := all()
	if _playable_ready and codes == _playable_for:
		return _playable
	var loaded := {}
	for code in codes:
		loaded[code.to_upper()] = true
	var chapters: Array[PackedStringArray] = []
	var placed := {}
	for chapter in listed:
		var sets := PackedStringArray()
		for code in chapter.sets:
			if loaded.has(code):
				sets.append(code)
				placed[code] = true
		if not sets.is_empty():
			chapters.append(sets)
	for code in codes:
		if not placed.has(code.to_upper()):
			chapters.append(PackedStringArray([code.to_upper()]))
	_playable = chapters
	_playable_for = codes.duplicate()
	_playable_ready = true
	return chapters


## The chapter set `code` is played in, counting from 1, among
## playable(`codes`); 0 when it's in none.
static func number_in(code: String, codes: PackedStringArray) -> int:
	var chapters := playable(codes)
	for i in chapters.size():
		if code.to_upper() in chapters[i]:
			return i + 1
	return 0


## The chapters this game plays: playable() over the sets the Card Shop
## sells, newest first.
static func game() -> Array[PackedStringArray]:
	return playable(shop_codes())


## The chapter set `code` is played in (number_in over shop_codes()).
static func game_number(code: String) -> int:
	return number_in(code, shop_codes())


static func shop_codes() -> PackedStringArray:
	var codes := PackedStringArray()
	for set_data in LaptopScreen.shop_sets():
		codes.append(set_data.code)
	return codes
