class_name ShelfLayout
extends RefCounted
## Where each binder's space is on a shelving unit (plan §3.2, Layer 2).
## Binders go in shelf order (release date): left to right along the top
## shelf, then the next one down, like a book. They're shared out as evenly
## as possible between all the bays of all the shelves, so every bay holds
## about the same width of binders, and none straddles a bay divider. Each
## space is as wide as its binder plus at least SPACE_GAP; whatever room a
## bay has left over is spread between its spaces, so no shelf ends in an
## empty run.

## Room around a binder in its space, at least, so its label fits under it
## and it's easy to aim at.
const SPACE_GAP := 0.03

## Per space, in shelf order: the binder that belongs there, which shelf
## (0 = top) it's on, and its left edge and width along the shelf (in metres
## from the unit's inside left edge).
var binders: Array[BinderRange] = []
var shelves := PackedInt32Array()
var lefts := PackedFloat32Array()
var widths := PackedFloat32Array()


static func space_width(binder: BinderRange) -> float:
	return BinderLayout.thickness(binder) + SPACE_GAP


## Which of `bay_count` bays (all shelves', in reading order) each binder
## falls in when they're shared out evenly: a binder goes in the bay its
## middle falls in, if every bay held exactly its share.
static func even_bays(all: Array[BinderRange], bay_count: int) -> PackedInt32Array:
	var total := 0.0
	for binder in all:
		total += space_width(binder)
	var share := total / bay_count
	var bays := PackedInt32Array()
	var filled := 0.0
	for binder in all:
		var width := space_width(binder)
		bays.append(mini(floori((filled + width / 2) / share), bay_count - 1) if share > 0.0 else 0)
		filled += width
	return bays


## The narrowest a bay can be for `all` to fit `bay_count` bays shared out
## evenly, binders at their tightest: the widest bay's binders.
static func fit_bay_width(all: Array[BinderRange], bay_count: int) -> float:
	var sums := PackedFloat32Array()
	sums.resize(bay_count)
	var bays := even_bays(all, bay_count)
	for i in all.size():
		sums[bays[i]] += space_width(all[i])
	var widest := 0.0
	for sum in sums:
		widest = maxf(widest, sum)
	return widest


## Lays `all` out over `shelf_count` shelves split into bays, given as the
## (start, end) of each bay along the shelf (the same on every shelf).
## Binders that don't fit are left out, with an error.
static func plan(all: Array[BinderRange], shelf_count: int, bays: Array[Vector2]) -> ShelfLayout:
	var layout := ShelfLayout.new()
	var bay_count := shelf_count * bays.size()
	var wanted := even_bays(all, bay_count)
	# Each bay's binders, in order. A bay too full for its share spills over
	# into the next one.
	var contents: Array = []
	var used := PackedFloat32Array()
	for i in bay_count:
		contents.append([])
		used.append(0.0)
	var bay := 0
	for i in all.size():
		var width := space_width(all[i])
		bay = maxi(bay, wanted[i])
		while bay < bay_count and used[bay] + width > _bay_length(bays, bay) + 0.0001:
			bay += 1
		if bay == bay_count:
			push_error("ShelfLayout: no room for %s" % all[i].label)
			bay = bay_count - 1
			continue
		contents[bay].append(all[i])
		used[bay] += width

	for b in bay_count:
		var span := bays[b % bays.size()]
		var spare := 0.0
		if not contents[b].is_empty():
			spare = (span.y - span.x - used[b]) / contents[b].size()
		var cursor := span.x
		for binder: BinderRange in contents[b]:
			var width := space_width(binder) + spare
			layout.binders.append(binder)
			layout.shelves.append(b / bays.size())
			layout.lefts.append(cursor)
			layout.widths.append(width)
			cursor += width
	return layout


static func _bay_length(bays: Array[Vector2], bay: int) -> float:
	var span := bays[bay % bays.size()]
	return span.y - span.x
