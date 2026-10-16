class_name SetData
extends RefCounted
## One set, plus the binder volumes its cards are filed into.

var code: String
var name: String
## ISO date, "YYYY-MM-DD". Sorting on the string sorts by date.
var release_date: String
var card_count: int
var accent_color: Color
## One entry per binder volume, in shelf order.
var binder_ranges: Array[BinderRange] = []


func build_binder_ranges(capacity: int) -> void:
	binder_ranges.clear()
	var volume_count := ceili(float(card_count) / capacity)
	for v in volume_count:
		var binder := BinderRange.new()
		binder.set_code = code
		binder.volume = v + 1
		binder.first = v * capacity + 1
		binder.last = mini((v + 1) * capacity, card_count)
		if volume_count == 1:
			binder.label = "%s, %d–%d" % [name, binder.first, binder.last]
		else:
			binder.label = "%s, Vol. %d (%d–%d)" % [name, binder.volume, binder.first, binder.last]
		binder_ranges.append(binder)


## The binder volume holding this collector number, or null if out of range.
func binder_for(collector_number: int) -> BinderRange:
	for binder in binder_ranges:
		if collector_number >= binder.first and collector_number <= binder.last:
			return binder
	return null
