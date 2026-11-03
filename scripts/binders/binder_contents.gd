class_name BinderContents
extends RefCounted
## What's in one binder's pockets (plan §3.2). Pocket i holds collector
## number binder.first + i. Pockets hold copy ids (Collection): any copy of
## a card belongs in its pocket, and once one is locked in, the others have
## nowhere to go here. A card goes only into its own pocket, and locks in
## for good; every other pocket refuses it.

enum Result {
	LOCKED, ## Right pocket: locked in.
	WRONG_POCKET, ## Not this card's pocket (or binder); nothing happened.
	OCCUPIED, ## Pocket already holds a card; nothing happened.
	INVALID, ## No such pocket.
}

var binder: BinderRange
var locked_count := 0

var _cards := PackedInt32Array()


func _init(range_data: BinderRange) -> void:
	binder = range_data
	_cards.resize(binder.card_capacity())
	_cards.fill(-1)


func capacity() -> int:
	return _cards.size()


## The copy id in a pocket, or -1.
func card_at(pocket: int) -> int:
	return _cards[pocket] if pocket >= 0 and pocket < _cards.size() else -1


## Every card in a pocket is locked in: only its own card goes in.
func is_locked(pocket: int) -> bool:
	return card_at(pocket) >= 0


## True if this card's home is exactly this pocket of this binder.
func belongs(card_id: int, pocket: int) -> bool:
	var card := Collection.card(card_id)
	return card.set_code == binder.set_code and binder.contains(card.collector_number) \
		and card.collector_number - binder.first == pocket


func insert(pocket: int, card_id: int) -> Result:
	if pocket < 0 or pocket >= _cards.size():
		return Result.INVALID
	if _cards[pocket] >= 0:
		return Result.OCCUPIED
	if not belongs(card_id, pocket):
		return Result.WRONG_POCKET
	_cards[pocket] = card_id
	locked_count += 1
	return Result.LOCKED


## Each pocket's card id (-1 for empty), for a save (copied on write).
func pocket_cards() -> PackedInt32Array:
	return _cards


## Fills the pockets from a save (ShopSave): `cards` holds a card id per
## pocket (-1 for empty). Each card goes into its own pocket, so a binder
## whose numbers changed since keeps what it can. Cards that no longer fit
## (not this binder's, or a duplicate) are returned, to go back on the
## floor; so are cards an older save left misplaced in a wrong pocket.
func restore(cards: PackedInt32Array) -> PackedInt32Array:
	_cards.fill(-1)
	locked_count = 0
	var left := PackedInt32Array()
	for id in cards:
		if id < 0:
			continue
		var card := Collection.card(id)
		if card.set_code != binder.set_code or not binder.contains(card.collector_number) \
				or insert(card.collector_number - binder.first, id) != Result.LOCKED:
			left.append(id)
	return left


func is_complete() -> bool:
	return locked_count == _cards.size()


## True when every pocket on the page that has a number is locked.
func is_page_complete(page: int) -> bool:
	var first := page * BinderLayout.POCKETS_PER_PAGE
	if first < 0 or first >= _cards.size():
		return false
	for pocket in range(first, mini(first + BinderLayout.POCKETS_PER_PAGE, _cards.size())):
		if _cards[pocket] < 0:
			return false
	return true
