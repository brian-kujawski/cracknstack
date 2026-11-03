class_name SaveGame
extends RefCounted
## One save file on disk: its format, and writing and reading it safely
## (plan: save-system-plan.md §6). A save is three Godot values written one
## after another into a Zstandard-compressed file with store_var (no
## objects, so nothing in a save can run code):
##   1. the header: magic, SAVE_VERSION, game version, data fingerprint;
##   2. the summary: what the Load list shows (time, play time, progress);
##   3. the shop: everything ShopSave puts back.
## The Load list reads only the first two.
##
## Writes never leave a half-written save: the new file goes to .tmp, its
## header is read back, the old file becomes .bak, and the new one is
## renamed into place. A save that won't read falls back to its .bak.

const MAGIC := "PKUP"
## Bump whenever a change makes older saves unreadable or wrong: a field
## added, removed, or meaning something new. Saves from any other version
## are listed as "From an older version" and can't be loaded (§7.1).
## 2: cards saved as copies (card-copies-plan.md).
const SAVE_VERSION := 2
const EXTENSION := ".save"

## Where a save stands, for the menus.
enum Status { EMPTY, OK, OLD_VERSION, UNREADABLE }


## Writes a save to `path` (see the class notes). Safe to call off the main
## thread: it touches nothing but its arguments and the file system.
static func write(path: String, summary: Dictionary, shop: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var temporary := path + ".tmp"
	var file := FileAccess.open_compressed(temporary, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(header())
	file.store_var(summary)
	file.store_var(shop)
	file.close()
	if read_summary(temporary).is_empty():
		DirAccess.remove_absolute(temporary)
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(temporary, path)


## The header written at the top of every save made by this build.
static func header() -> Dictionary:
	return {
		"magic": MAGIC,
		"version": SAVE_VERSION,
		"game": str(ProjectSettings.get_setting("application/config/version", "")),
		"data": fingerprint(),
	}


## A short hash of every set code and card count, so a save can tell when
## the card data has changed since (an import, a removed card). Only for
## information: ShopSave carries saves across data changes by set and number.
static func fingerprint() -> String:
	var text := ""
	for set_data in CardDatabase.sets_in_shelf_order():
		text += "%s:%d;" % [set_data.code, CardDatabase.cards_in_set(set_data.code).size()]
	return text.md5_text().left(12)


## The header and summary of a save, merged ({} if it won't read, or isn't
## a save): "version" tells whether it can be loaded.
static func read_summary(path: String) -> Dictionary:
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return {}
	var found: Variant = file.get_var()
	if not found is Dictionary or found.get("magic") != MAGIC:
		return {}
	var summary: Variant = file.get_var()
	if not summary is Dictionary:
		return {}
	var merged: Dictionary = summary.duplicate()
	merged.merge(found)
	return merged


## The whole save: {"summary": ..., "shop": ...}, or {} if it can't be
## loaded (missing, unreadable, or from another SAVE_VERSION). An unreadable
## save falls back to its .bak.
static func read(path: String) -> Dictionary:
	if read_summary(path).is_empty():
		return _read_file(path + ".bak")
	return _read_file(path)


static func _read_file(path: String) -> Dictionary:
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return {}
	var found: Variant = file.get_var()
	if not found is Dictionary or found.get("magic") != MAGIC or found.get("version") != SAVE_VERSION:
		return {}
	var summary: Variant = file.get_var()
	var shop: Variant = file.get_var()
	if not summary is Dictionary or not shop is Dictionary:
		return {}
	return {"summary": summary, "shop": shop}


## Whether there's a save at `path`, and whether this build can load it.
## An unreadable save whose .bak reads counts as that .bak.
static func status(path: String) -> Status:
	var summary := read_summary(path)
	if summary.is_empty():
		if not FileAccess.file_exists(path):
			return Status.EMPTY
		var backup := read_summary(path + ".bak")
		if backup.is_empty():
			return Status.UNREADABLE
		summary = backup
	return Status.OK if summary.get("version") == SAVE_VERSION else Status.OLD_VERSION


## A save as JSON, for checking by eye and for bug reports
## (`-- --dump-save <file>` in developer builds).
static func dump(path: String) -> String:
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return ""
	var parts := []
	while file.get_position() < file.get_length():
		parts.append(file.get_var())
	return JSON.stringify(parts, "  ")
