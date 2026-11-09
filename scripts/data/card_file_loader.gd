class_name CardFileLoader
extends RefCounted
## Reads a card data file. Placeholder data and the Scryfall importer
## (tools/import_scryfall.py) both write this format:
##
## {
##   "format": 1,
##   "source": "...",                                       (real data only)
##   "sets":  [{"code", "name", "release_date", "accent_color", "artists"}],
##   "faces": {"pages", "page_size", "slot_size", "columns", "rows",   (real data only)
##             "near", "near_size"},
##   "back": "back.jpg",                                     (real data only)
##   "build": "Alpha",                    (cut-down playtest builds only)
##   "cards": [[set_code, collector_number, name, rarity, colors, type_line, image], ...]
## }
##
## Cards are compact arrays because the full game has ~30,000 of them. The
## seventh column (a large face image) and "faces" (the small-face atlas,
## card i in slot i) and "back" (the card back image) only come with real data. Their paths are relative to
## the data file. "near" is where each card's near face is (NearFaces), with
## {set} for the lower-case set code and {number} for the collector number.

const FORMAT_VERSION := 1


class Result:
	var error: Error = OK
	var source := ""
	var sets: Array[SetData] = []
	var cards: Array[CardData] = []
	## "faces" from the file with its page paths made absolute; empty if none.
	var faces: Dictionary = {}
	## The card back image, or "" to draw the placeholder back.
	var back := ""
	## A cut-down playtest build's name (tools/package_alpha.py), or "".
	var build := ""


static func load_file(path: String) -> Result:
	var result := Result.new()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		result.error = FileAccess.get_open_error()
		if result.error == OK:
			result.error = ERR_FILE_CORRUPT
		return result
	var json = JSON.parse_string(text)
	if typeof(json) != TYPE_DICTIONARY or int(json.get("format", 0)) != FORMAT_VERSION:
		result.error = ERR_PARSE_ERROR
		return result
	var folder := path.get_base_dir()
	result.source = json.get("source", "")
	result.build = str(json.get("build", ""))
	if not str(json.get("back", "")).is_empty():
		result.back = folder.path_join(json["back"])

	var counts := {}
	for entry in json["sets"]:
		var set_data := SetData.new()
		set_data.code = entry["code"]
		set_data.name = entry["name"]
		set_data.release_date = entry["release_date"]
		set_data.accent_color = Color.html(entry.get("accent_color", "#808080"))
		set_data.artists = PackedStringArray(entry.get("artists", []))
		result.sets.append(set_data)
		counts[set_data.code] = 0

	var has_faces: bool = json.has("faces")
	if has_faces:
		result.faces = json["faces"].duplicate()
		var pages := PackedStringArray()
		for page in json["faces"]["pages"]:
			pages.append(folder.path_join(page))
		result.faces["pages"] = pages

	for row in json["cards"]:
		var card := CardData.new()
		card.id = result.cards.size()
		card.set_code = row[0]
		card.collector_number = int(row[1])
		card.name = row[2]
		card.rarity = CardData.rarity_from_string(row[3])
		card.colors = PackedStringArray(row[4])
		card.type_line = row[5]
		if row.size() > 6 and not str(row[6]).is_empty():
			card.image_large = folder.path_join(row[6])
		# Then the real prices, US dollars, null for none (tools/import_scryfall.py).
		if row.size() > 7 and row[7] != null:
			card.price = float(row[7])
		if row.size() > 8 and row[8] != null:
			card.foil_price = float(row[8])
		if has_faces:
			card.face_index = card.id
			if result.faces.has("near"):
				card.image_near = folder.path_join(str(result.faces["near"]).format(
						{"set": folder_name(card.set_code), "number": card.collector_number}))
		if not counts.has(card.set_code):
			push_error("CardFileLoader: card %s references unknown set %s" % [card.name, card.set_code])
			result.error = ERR_INVALID_DATA
			return result
		counts[card.set_code] += 1
		result.cards.append(card)

	for set_data in result.sets:
		set_data.card_count = counts[set_data.code]
	return result


## Names Windows keeps for devices (a file or folder called "con" can't be
## opened there; Conflux's code is CON). Same list as the importer's
## RESERVED_NAMES.
const RESERVED_NAMES := ["con", "prn", "aux", "nul", "com0", "com1", "com2", "com3", "com4", "com5", "com6",
	"com7", "com8", "com9", "lpt0", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9"]


## A set's folder name on disk, as tools/import_scryfall.py writes it: its
## code in lower case, with "_" after a name Windows reserves.
static func folder_name(code: String) -> String:
	var name := code.to_lower()
	return name + "_" if name in RESERVED_NAMES else name
