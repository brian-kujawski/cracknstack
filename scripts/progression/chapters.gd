class_name Chapters
extends RefCounted
## The chapters: which sets the game unlocks together, read from one text
## file (data/chapters.txt) so they're easy to rearrange. The first set of
## each chapter comes with a sealed booster box when it unlocks; the rest
## come with LaptopScreen.STARTER_PACKS packs (Main._on_set_unlocked).
##
## The file: a line starting with "Chapter" begins a chapter (the rest of
## the line is its name); then one set code per line. "#" starts a comment.

const PATH := "res://data/chapters.txt"

## Each chapter: {"name": String, "sets": PackedStringArray}, in order.
static var _chapters: Array[Dictionary] = []
static var _loaded := false


## All chapters, in order (read from PATH the first time).
static func all() -> Array[Dictionary]:
	if not _loaded:
		use_text(FileAccess.get_file_as_string(PATH) if FileAccess.file_exists(PATH) else "")
	return _chapters


## Reads chapters from `text` instead of the file (tests, and the loader).
static func use_text(text: String) -> void:
	_chapters = parse(text)
	_loaded = true


## Goes back to reading the file.
static func reload() -> void:
	_loaded = false


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


## Whether `code` is the first set of its chapter (it comes with a box).
static func opens_chapter(code: String) -> bool:
	for chapter in all():
		if not chapter.sets.is_empty() and chapter.sets[0] == code.to_upper():
			return true
	return false
