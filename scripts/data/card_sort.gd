class_name CardSort
extends RefCounted
## The one place the sorting rule lives (plan §3.3): set release date, then
## set code, then collector number.


## True if a sorts before b. Usable with Array.sort_custom.
static func compare(a: CardData, b: CardData) -> bool:
	if a.set_code != b.set_code:
		var set_a := CardDatabase.get_set(a.set_code)
		var set_b := CardDatabase.get_set(b.set_code)
		return compare_sets(set_a, set_b)
	return a.collector_number < b.collector_number


## True if set a goes on the shelves before set b.
static func compare_sets(a: SetData, b: SetData) -> bool:
	if a.release_date != b.release_date:
		return a.release_date < b.release_date
	return a.code < b.code
