class_name BinderRange
extends RefCounted
## One set's binder: the run of collector numbers it holds.
## The same label is printed on the binder's spine and on its shelf space.

var set_code: String
var first: int
var last: int
var label: String


func card_capacity() -> int:
	return last - first + 1


func contains(collector_number: int) -> bool:
	return collector_number >= first and collector_number <= last


## The set code and number range as printed on the binder, e.g. "KTK #001-269".
func numbers_text() -> String:
	var set_data := CardDatabase.get_set(set_code)
	return "%s #%s-%s" % [set_code, set_data.number_text(first), set_data.number_text(last)]
