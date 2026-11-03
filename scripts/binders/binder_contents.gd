class_name BinderContents
extends RefCounted
## What's in one binder's pockets (plan §3.2). Pocket i holds collector
## number binder.first + i. Pockets hold copy ids (Collection): any copy of
## a card belongs in its pocket, and once one is locked in, the others have
## nowhere to go here. A card in its own pocket locks in for good; a card
## anywhere else stays put, unlocked, until the player takes it back out.

enum Result {
	LOCKED, ## Right pocket: locked in.
	MISPLACED, ## Wrong pocket (or wrong binder): sits there unlocked.
	OCCUPIED, ## Pocket already holds a card; nothing happened.
	INVALID, ## No such pocket.
}

var binder: BinderRange
var locked_count := 0

var _cards := PackedInt32Array()
var _locked := PackedByteArray()


func _init(range_data: BinderRange) -> void:
	binder = range_data
	_cards.resize(binder.card_capacity())
	_cards.fill(-1)
	_locked.resize(binder.card_capacity())


func capacity() -> int:
	return _cards.size()


## The copy id in a pocket, or -1.
func card_at(pocket: int) -> int:
	return _cards[pocket] if pocket >= 0 and pocket < _cards.size() else -1


func is_locked(pocket: int) -> bool:
	return pocket >= 0 and pocket < _locked.size() and _locked[pocket] == 1


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
	_cards[pocket] = card_id
	if belongs(card_id, pocket):
		_locked[pocket] = 1
		locked_count += 1
		return Result.LOCKED
	return Result.MISPLACED


## Takes an unlocked card back out. Returns its id, or -1 if the pocket is
## empty or locked.
func take(pocket: int) -> int:
	if pocket < 0 or pocket >= _cards.size() or _locked[pocket] == 1:
		return -1
	var id := _cards[pocket]
	_cards[pocket] = -1
	return id


## Each pocket's card id (-1 for empty), and whether it's locked in, for a
## save (copied on write).
func pocket_cards() -> PackedInt32Array:
	return _cards


func pocket_locks() -> PackedByteArray:
	return _locked


## Fills the pockets from a save (ShopSave): `cards` holds a card id per
## pocket (-1 for empty) and `locked` whether it was locked in. A card only
## locks in again if it still belongs there, so a binder whose numbers
## changed since keeps what it can. Cards that no longer fit (past the last
## pocket, or a duplicate) are returned, to go back on the floor.
func restore(cards: PackedInt32Array, locked: PackedByteArray) -> PackedInt32Array:
	_cards.fill(-1)
	_locked.fill(0)
	locked_count = 0
	var left := PackedInt32Array()
	# Cards that belong somewhere here go there first; misplaced ones after,
	# into the pocket they were in if it's still free.
	for pocket in cards.size():
		var id := cards[pocket]
		if id < 0 or pocket >= locked.size() or locked[pocket] == 0:
			continue
		var home := Collection.card(id).collector_number - binder.first
		if Collection.card(id).set_code == binder.set_code and binder.contains(binder.first + home) \
				and _cards[home] < 0:
			insert(home, id)
		else:
			left.append(id)
	for pocket in cards.size():
		var id := cards[pocket]
		if id < 0 or (pocket < locked.size() and locked[pocket] == 1):
			continue
		if pocket < _cards.size() and _cards[pocket] < 0 and not belongs(id, pocket):
			_cards[pocket] = id
		elif pocket < _cards.size() and _cards[pocket] < 0:
			insert(pocket, id)
		else:
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
		if _locked[pocket] == 0:
			return false
	return true
