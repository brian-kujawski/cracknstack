class_name BinderContents
extends RefCounted
## What's in one binder's pockets (plan §3.2). Pocket i holds collector
## number binder.first + i. A card in its own pocket locks in for good; a card
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


## The card id in a pocket, or -1.
func card_at(pocket: int) -> int:
	return _cards[pocket] if pocket >= 0 and pocket < _cards.size() else -1


func is_locked(pocket: int) -> bool:
	return pocket >= 0 and pocket < _locked.size() and _locked[pocket] == 1


## True if this card's home is exactly this pocket of this binder.
func belongs(card_id: int, pocket: int) -> bool:
	var card := CardDatabase.get_card(card_id)
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
