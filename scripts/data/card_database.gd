extends Node
## Autoload. The ONLY way game code gets card data (plan §2). Loads the real
## cards written by tools/import_scryfall.py (Khans of Tarkir for now) if
## they're there, else the placeholder collection. Run with
## `-- --placeholder` to force the placeholders (e.g. for the full-scale
## benchmark). The rare cards for the display cabinets (RareCards) are
## added to whichever it loads, as one more set, after every other card.

const REAL_PATH := "res://data/real/cards.json"
const PLACEHOLDER_PATH := "res://data/placeholder/cards.json"

## Where the loaded data came from ("" for placeholders).
var source := ""
## Small faces for the floor, or null to draw placeholder faces.
var face_atlas: FaceAtlas
## The real card back, or null to draw the placeholder back.
var card_back: Texture2D
## The rare cards' own back (RareCards.BACK_PATH), or null if they share
## card_back.
var rare_back: Texture2D

var _cards: Array[CardData] = []
var _sets: Dictionary = {} # code -> SetData
var _sets_in_shelf_order: Array[SetData] = []
var _cards_by_set: Dictionary = {} # code -> Array[CardData], by collector number
var _rare_set: SetData


func _ready() -> void:
	var path := PLACEHOLDER_PATH
	if FileAccess.file_exists(REAL_PATH) and not "--placeholder" in OS.get_cmdline_user_args():
		path = REAL_PATH
	var error := load_file(path)
	if error != OK:
		push_error("CardDatabase: could not load %s (%s)" % [path, error_string(error)])


## Replaces all loaded data with the contents of a card data file.
func load_file(path: String) -> Error:
	var result := CardFileLoader.load_file(path)
	if result.error != OK:
		return result.error
	_cards = result.cards
	source = result.source
	face_atlas = FaceAtlas.load_pages(result.faces) if not result.faces.is_empty() else null
	if face_atlas == null:
		for card in _cards:
			card.face_index = -1
	card_back = _load_back(result.back)
	rare_back = _load_back(RareCards.BACK_PATH) if ResourceLoader.exists(RareCards.BACK_PATH) or FileAccess.file_exists(RareCards.BACK_PATH) else null
	CardView.clear_cache()
	_sets.clear()
	_cards_by_set.clear()
	for set_data in result.sets:
		set_data.build_binder()
		_sets[set_data.code] = set_data
		_cards_by_set[set_data.code] = [] as Array[CardData]
	if _sets.has(RareCards.SET_CODE):
		push_error("CardDatabase: %s already has a set %s; the rare cards replace it" % [path, RareCards.SET_CODE])
	for card in _cards:
		_cards_by_set[card.set_code].append(card)
	# The rare cards: a set with no binder, so never on the shelf.
	_rare_set = RareCards.make_set()
	_sets[_rare_set.code] = _rare_set
	var rare := RareCards.make_cards(_cards.size())
	_cards.append_array(rare)
	_cards_by_set[_rare_set.code] = rare
	for code in _cards_by_set:
		_cards_by_set[code].sort_custom(func(a: CardData, b: CardData) -> bool:
			return a.collector_number < b.collector_number)
	_sets_in_shelf_order.assign(_sets.values().filter(func(set_data: SetData) -> bool: return set_data != _rare_set))
	_sets_in_shelf_order.sort_custom(CardSort.compare_sets)
	return OK


static func _load_back(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var image := FaceAtlas.load_image(path)
	if image == null:
		push_warning("CardDatabase: missing card back %s; drawing the placeholder back" % path)
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## Hands the card back to a shader that includes card_face.gdshaderinc:
## the rare cards' own back for a `rare` card, if there is one.
func apply_back(material: ShaderMaterial, rare := false) -> void:
	var back := rare_back if rare and rare_back != null else card_back
	material.set_shader_parameter("has_back", back != null)
	material.set_shader_parameter("back_texture", back)


## True when real cards are loaded rather than the placeholders.
func is_real_data() -> bool:
	return not source.is_empty()


func card_count() -> int:
	return _cards.size()


## Sets with binders (not counting the rare cards).
func set_count() -> int:
	return _sets_in_shelf_order.size()


func get_card(id: int) -> CardData:
	return _cards[id]


func get_set(code: String) -> SetData:
	return _sets.get(code)


## Every set, in release-date order: the order of the shelves.
func sets_in_shelf_order() -> Array[SetData]:
	return _sets_in_shelf_order


## Every set with a binder in shelf order, then the rare cards: the order
## a save lists cards in.
func all_sets() -> Array[SetData]:
	var sets := _sets_in_shelf_order.duplicate()
	sets.append(_rare_set)
	return sets


## The rare cards for the display cabinets, by number (RareCards).
func rare_cards() -> Array[CardData]:
	return cards_in_set(RareCards.SET_CODE)


func is_rare(id: int) -> bool:
	return RareCards.is_rare(_cards[id])


func cards_in_set(code: String) -> Array[CardData]:
	return _cards_by_set.get(code, [] as Array[CardData])


## Every binder in the store (one per set), in shelf order.
func all_binders() -> Array[BinderRange]:
	var binders: Array[BinderRange] = []
	for set_data in _sets_in_shelf_order:
		binders.append(set_data.binder)
	return binders


## The binder a card belongs in (null for a rare card).
func binder_for(card: CardData) -> BinderRange:
	if RareCards.is_rare(card):
		return null
	return get_set(card.set_code).binder_for(card.collector_number)
