class_name SetData
extends RefCounted
## One set, plus the binder its cards are filed into.

var code: String
var name: String
## ISO date, "YYYY-MM-DD". Sorting on the string sorts by date.
var release_date: String
var card_count: int
var accent_color: Color
## Artists credited for this set's card images (real data only).
var artists: PackedStringArray
## The set's one binder, however many cards it has (plan §3.2).
var binder: BinderRange


func build_binder() -> void:
	binder = BinderRange.new()
	binder.set_code = code
	binder.first = 1
	binder.last = card_count
	binder.label = "%s, %d–%d" % [name, binder.first, binder.last]


## A collector number as printed on the cards: zero-padded to three digits,
## or to however many the set's size needs.
func number_text(collector_number: int) -> String:
	return str(collector_number).pad_zeros(maxi(3, str(card_count).length()))


## The set's binder if it holds this collector number, else null.
func binder_for(collector_number: int) -> BinderRange:
	return binder if binder.contains(collector_number) else null
