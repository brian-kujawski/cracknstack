class_name BinderRange
extends RefCounted
## One set's binder: the run of collector numbers it holds.
## Its label names it in messages (e.g. "Khans of Tarkir, 1–269").

var set_code: String
var first: int
var last: int
var label: String


func card_capacity() -> int:
	return last - first + 1


func contains(collector_number: int) -> bool:
	return collector_number >= first and collector_number <= last

