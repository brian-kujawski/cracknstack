extends Node
## Autoload. Every physical card in the game: the copies (plan:
## card-copies-plan.md). A card (CardData) is one printing, one of each,
## loaded from the data; a copy is one card you own, and there can be any
## number of copies of a card, or none. Everything physical (the pile,
## tables, hands, binder pockets, cards in flight) holds copy ids; ask here
## which card a copy is.
##
## Copies are made as product is opened (PackContents) and numbered in order
## from 0. An id is never reused within a game. The collection is emptied
## for a new game and filled again from a save (ShopSave).

## Per-copy flags (one byte each). Foil is for later: nothing makes a foil
## copy yet.
const FOIL := 1

var _cards := PackedInt32Array()
var _flags := PackedByteArray()
## Card id -> PackedInt32Array of its copies, in the order they were made.
var _copies_of := {}


## Empties the collection (a new game, or before a save is loaded).
func reset() -> void:
	_cards = PackedInt32Array()
	_flags = PackedByteArray()
	_copies_of.clear()


## How many copies there are (every copy id is below this).
func count() -> int:
	return _cards.size()


## Makes a new copy of card `card_id`. Returns its copy id.
func add(card_id: int, flags := 0) -> int:
	var copy := _cards.size()
	_cards.append(card_id)
	_flags.append(flags)
	var copies: PackedInt32Array = _copies_of.get(card_id, PackedInt32Array())
	copies.append(copy)
	_copies_of[card_id] = copies
	return copy


## Makes one new copy of each card in `card_ids`, in order. Returns their
## copy ids.
func add_all(card_ids: PackedInt32Array) -> PackedInt32Array:
	var first := _cards.size()
	var made := PackedInt32Array()
	made.resize(card_ids.size())
	for i in card_ids.size():
		var copy := first + i
		_cards.append(card_ids[i])
		_flags.append(0)
		var copies: PackedInt32Array = _copies_of.get(card_ids[i], PackedInt32Array())
		copies.append(copy)
		_copies_of[card_ids[i]] = copies
		made[i] = copy
	return made


## The card a copy is.
func card(copy: int) -> CardData:
	return CardDatabase.get_card(_cards[copy])


func card_id(copy: int) -> int:
	return _cards[copy]


func flags(copy: int) -> int:
	return _flags[copy]


func is_foil(copy: int) -> bool:
	return _flags[copy] & FOIL != 0


## Whether a copy is one of the rare cabinet cards (RareCards).
func is_rare(copy: int) -> bool:
	return RareCards.is_rare(card(copy))


## Every copy of card `card_id`, in the order they were made (copied).
func copies_of(card_id: int) -> PackedInt32Array:
	return _copies_of.get(card_id, PackedInt32Array())


## Every copy's card id, by copy id (copied on write), for a save.
func card_ids() -> PackedInt32Array:
	return _cards


func all_flags() -> PackedByteArray:
	return _flags
