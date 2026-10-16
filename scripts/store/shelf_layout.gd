class_name ShelfLayout
extends RefCounted
## Which shelf space each binder belongs in. Spaces are read like a book:
## left to right along a shelf, top shelf first, then on to the next unit.
## Binders fill spaces in shelf order (release date, then volume), so the
## finished wall reads as the game's timeline (plan §3.2, Layer 2).

const SHELVES_PER_UNIT := 5
const SPACES_PER_SHELF := 12
const SPACES_PER_UNIT := SHELVES_PER_UNIT * SPACES_PER_SHELF


## The (unit, shelf, space) slot for a position in shelf order. Shelf 0 is
## the top shelf; space 0 is the leftmost space as you face the unit.
static func slot_for_index(index: int) -> Vector3i:
	var within_unit := index % SPACES_PER_UNIT
	return Vector3i(index / SPACES_PER_UNIT, within_unit / SPACES_PER_SHELF, within_unit % SPACES_PER_SHELF)


static func units_needed(binder_count: int) -> int:
	return ceili(float(binder_count) / SPACES_PER_UNIT)


## Per unit, a flat array of SPACES_PER_UNIT entries (BinderRange or null for
## an unlabelled space), indexed by shelf * SPACES_PER_SHELF + space.
static func assign(binders: Array[BinderRange], unit_count: int) -> Array[Array]:
	var units: Array[Array] = []
	for u in unit_count:
		var spaces := []
		spaces.resize(SPACES_PER_UNIT)
		units.append(spaces)
	for i in binders.size():
		var slot := slot_for_index(i)
		if slot.x >= unit_count:
			push_error("ShelfLayout: %d binders don't fit in %d units" % [binders.size(), unit_count])
			break
		units[slot.x][slot.y * SPACES_PER_SHELF + slot.z] = binders[i]
	return units
