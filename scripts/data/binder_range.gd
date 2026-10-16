class_name BinderRange
extends RefCounted
## One binder volume: a contiguous run of collector numbers from one set.
## The same label is printed on the binder's spine and on its shelf space.

var set_code: String
var volume: int
var first: int
var last: int
var label: String


func card_capacity() -> int:
	return last - first + 1


func contains(collector_number: int) -> bool:
	return collector_number >= first and collector_number <= last
