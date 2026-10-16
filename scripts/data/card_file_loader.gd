class_name CardFileLoader
extends RefCounted
## Reads a card data file. Placeholder data and (later) the Scryfall importer
## both write this format:
##
## {
##   "format": 1,
##   "sets":  [{"code", "name", "release_date", "accent_color"}],
##   "cards": [[set_code, collector_number, name, rarity, colors, type_line], ...]
## }
##
## Cards are compact arrays because the full game has ~30,000 of them.

const FORMAT_VERSION := 1


class Result:
	var error: Error = OK
	var sets: Array[SetData] = []
	var cards: Array[CardData] = []


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

	var counts := {}
	for entry in json["sets"]:
		var set_data := SetData.new()
		set_data.code = entry["code"]
		set_data.name = entry["name"]
		set_data.release_date = entry["release_date"]
		set_data.accent_color = Color.html(entry.get("accent_color", "#808080"))
		result.sets.append(set_data)
		counts[set_data.code] = 0

	for row in json["cards"]:
		var card := CardData.new()
		card.id = result.cards.size()
		card.set_code = row[0]
		card.collector_number = int(row[1])
		card.name = row[2]
		card.rarity = CardData.rarity_from_string(row[3])
		card.colors = PackedStringArray(row[4])
		card.type_line = row[5]
		if not counts.has(card.set_code):
			push_error("CardFileLoader: card %s references unknown set %s" % [card.name, card.set_code])
			result.error = ERR_INVALID_DATA
			return result
		counts[card.set_code] += 1
		result.cards.append(card)

	for set_data in result.sets:
		set_data.card_count = counts[set_data.code]
	return result
