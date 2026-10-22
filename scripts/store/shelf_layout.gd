class_name ShelfLayout
extends RefCounted
## Where each binder's space is on a shelving unit (plan §3.2, Layer 2).
## Binders go in shelf order (release date): left to right along the top
## shelf, then the next one down, like a book. They're split as evenly as
## possible between the shelves, so every shelf ends with the same room to
## spare. Each space is as wide as its binder plus SPACE_GAP, and none
## straddles a bay divider.

## Room around a binder in its space, so its label fits under it and it's
## easy to aim at.
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


## Lays `all` out over `shelf_count` shelves split into bays, given as the
## (start, end) of each bay along the shelf. Binders that don't fit are left
## out, with an error.
static func plan(all: Array[BinderRange], shelf_count: int, bays: Array[Vector2]) -> ShelfLayout:
	var layout := ShelfLayout.new()
	var total := 0.0
	for binder in all:
		total += space_width(binder)
	var share := total / shelf_count
	var shelf := 0
	var bay := 0
	var cursor := bays[0].x
	var filled := 0.0
	for binder in all:
		var width := space_width(binder)
		# A binder goes on the shelf its middle falls on, if the shelves were
		# filled to exactly their share.
		var wanted := mini(floori((filled + width / 2) / share), shelf_count - 1) if share > 0.0 else 0
		filled += width
		if wanted > shelf:
			shelf = wanted
			bay = 0
			cursor = bays[0].x
		while bay < bays.size() and cursor + width > bays[bay].y:
			bay += 1
			cursor = bays[bay].x if bay < bays.size() else 0.0
		if bay == bays.size():
			# This shelf's full: carry on along the next one, if there is one.
			if shelf == shelf_count - 1:
				push_error("ShelfLayout: no room for %s" % binder.label)
				continue
			shelf += 1
			bay = 0
			cursor = bays[0].x
		layout.binders.append(binder)
		layout.shelves.append(shelf)
		layout.lefts.append(cursor)
		layout.widths.append(width)
		cursor += width
	return layout
