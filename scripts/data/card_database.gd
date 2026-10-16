extends Node
## Autoload. The ONLY way game code gets card data (plan §2). Today it reads
## the placeholder file; the real-data milestone swaps the path, not the API.

const PLACEHOLDER_PATH := "res://data/placeholder/cards.json"

var _cards: Array[CardData] = []
var _sets: Dictionary = {} # code -> SetData
var _sets_in_shelf_order: Array[SetData] = []
var _cards_by_set: Dictionary = {} # code -> Array[CardData], by collector number


func _ready() -> void:
	var error := load_file(PLACEHOLDER_PATH)
	if error != OK:
		push_error("CardDatabase: could not load %s (%s)" % [PLACEHOLDER_PATH, error_string(error)])


## Replaces all loaded data with the contents of a card data file.
func load_file(path: String) -> Error:
	var result := CardFileLoader.load_file(path)
	if result.error != OK:
		return result.error
	_cards = result.cards
	_sets.clear()
	_cards_by_set.clear()
	for set_data in result.sets:
		set_data.build_binder_ranges(BinderLayout.BINDER_CAPACITY)
		_sets[set_data.code] = set_data
		_cards_by_set[set_data.code] = [] as Array[CardData]
	for card in _cards:
		_cards_by_set[card.set_code].append(card)
	for code in _cards_by_set:
		_cards_by_set[code].sort_custom(func(a: CardData, b: CardData) -> bool:
			return a.collector_number < b.collector_number)
	_sets_in_shelf_order.assign(_sets.values())
	_sets_in_shelf_order.sort_custom(CardSort.compare_sets)
	return OK


func card_count() -> int:
	return _cards.size()


func set_count() -> int:
	return _sets.size()


func get_card(id: int) -> CardData:
	return _cards[id]


func get_set(code: String) -> SetData:
	return _sets.get(code)


## Every set, in release-date order: the order of the shelves.
func sets_in_shelf_order() -> Array[SetData]:
	return _sets_in_shelf_order


func cards_in_set(code: String) -> Array[CardData]:
	return _cards_by_set.get(code, [] as Array[CardData])


## Every binder volume in the store, in shelf order.
func all_binders() -> Array[BinderRange]:
	var binders: Array[BinderRange] = []
	for set_data in _sets_in_shelf_order:
		binders.append_array(set_data.binder_ranges)
	return binders


## The binder volume a card belongs in.
func binder_for(card: CardData) -> BinderRange:
	return get_set(card.set_code).binder_for(card.collector_number)
