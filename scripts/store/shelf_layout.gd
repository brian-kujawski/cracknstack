class_name ShelfLayout
extends RefCounted
## Which shelf space each binder belongs in. Binders are split as evenly as
## possible across the labelled units, in shelf order (release date, then
## volume), so walking from one unit to the next reads the game's timeline
## (plan §3.2, Layer 2). Within a unit, spaces read like a book: left to
## right along a shelf, top shelf first.

const SHELVES_PER_UNIT := 5
## Spaces per shelf on a standard (unlabelled) unit. Labelled units are as
## wide as the wall they stand on.
const SPACES_PER_SHELF := 12


## Per unit, a flat array of SHELVES_PER_UNIT * spaces_per_shelf[unit] entries
## (BinderRange, or null for an unlabelled space), indexed by
## shelf * spaces_per_shelf[unit] + space.
static func assign(binders: Array[BinderRange], spaces_per_shelf: Array[int]) -> Array[Array]:
	var units: Array[Array] = []
	var unit_count := spaces_per_shelf.size()
	var next := 0
	for u in unit_count:
		var spaces := []
		spaces.resize(SHELVES_PER_UNIT * spaces_per_shelf[u])
		units.append(spaces)
		# The first (count % units) units take one extra binder.
		var share := binders.size() / unit_count + (1 if u < binders.size() % unit_count else 0)
		if share > spaces.size():
			push_error("ShelfLayout: unit %d holds %d binders, %d needed" % [u, spaces.size(), share])
			share = spaces.size()
		for i in share:
			spaces[i] = binders[next]
			next += 1
	return units
