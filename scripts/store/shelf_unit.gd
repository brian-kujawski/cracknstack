class_name ShelfUnit
extends StaticBody3D
## One library bookcase, any width: two shelves split into bays by thin
## dividers, each board fronted by a moulded edge, over a panelled base on a
## skirting, between fluted end pilasters, under a crown and a top that is a
## surface like a table's, for cards and binders. The mouldings come from
## Kiln (assets/models/bookcase). Its origin is on the floor, centred under
## the unit, and its open front faces local +Z.
##
## Every space is labelled for one binder, with a nameplate on the shelf's
## edge under it (Nameplates), and is as wide as that binder, give or take
## the bay's spare room (ShelfLayout).
## A binder stood in its own space locks in; in any other labelled space it
## glows red. Once its own completed binder stands there, a space's plate
## turns from black to gold; when every space on a shelf has, the light under
## the shelf above comes on.
##
## A locked set's space is bare: no plate, and its binder waits out of
## sight in it (refresh_locks) until the set unlocks and the binder is
## delivered (deliver_binder).
##
## The unit's collision is one solid box from the floor up, so nothing gets
## under or behind it; only the top is a separate body (`top`), which aiming
## treats like a table top.

const DEPTH := 0.35
const BOARD_THICKNESS := 0.04
const SIDE_THICKNESS := 0.03
## Height of each shelf board's top surface, top shelf first. The lowest
## board sits on the legs, a shelf's height off the floor.
const SHELF_HEIGHTS := [0.95, 0.55]
## Height of the top board's top surface (the cap sits on it).
const HEIGHT := 1.35
## How many bays each shelf is split into by dividers. The unit is as wide
## as the binders need (fitted_width()), so the bays are too.
const BAYS := 10
## The narrowest a bay gets, however few binders there are.
const MIN_BAY_WIDTH := 0.3
const DIVIDER_THICKNESS := 0.012
const BACK_THICKNESS := 0.02
## The edge band on each board's front: its depth, and how far it hangs below
## the board. Its top is flush with the board, so binders stand clear of it.
const BAND_DEPTH := 0.012
const BAND_DROP := 0.008
const CAP_THICKNESS := 0.025
## How far the top cap overhangs the sides and front (over the crown).
const CAP_OVERHANG := 0.04
## How much narrower than its space a nameplate is, at least (half each side).
const PLATE_CLEARANCE := 0.008
## The base's panels: a stile at both ends and at every so many bay
## dividers (leg_spots(), named for the legs the shelf once stood on, and
## still where the wall art above it is spaced).
const LEGS_EVERY := 2
## How far the end stiles' centres sit in from the unit's ends.
const LEG_INSET := 0.06
const MOULDINGS := preload("res://assets/models/bookcase/bookcase.glb")
const ROOM_MOULDINGS := preload("res://assets/models/mouldings/mouldings.glb")
## The panelled base: how far its panels sit back from the shelf fronts, how
## far its frame stands proud of them, the frame's width, and the skirting's
## and base cap's heights (the skirting is the room's).
const BASE_SET_BACK := 0.02
const BASE_FRAME_PROUD := 0.01
const BASE_FRAME_WIDTH := 0.06
const SKIRTING_HEIGHT := 0.16
const BASE_CAP_HEIGHT := 0.03
## The crown under the top: its height, as built.
const CROWN_HEIGHT := 0.05
## Brass label holders: lips above and below each nameplate.
const HOLDER_LIP := 0.0025
const HOLDER_DEPTH := 0.004

## Inside width, between the side panels.
var width := 0.0
## Per space, in shelf order: the binder that belongs there.
var spaces: Array = []
## Per space: the Binder standing there now, or null.
var shelved: Array = []
## The top's body: cards and binders put down on it rest there.
var top: StaticBody3D
var nameplates: Nameplates

var _layout: ShelfLayout
var _bays := 1
var _dividers: Array[float] = []
var _section_lights: Array[MeshInstance3D] = []


## Outside width of a unit this wide inside.
static func outer_width(inner_width: float) -> float:
	return inner_width + 2 * SIDE_THICKNESS


## How wide inside a unit of `bays` bays a shelf must be to hold `binders`
## with no shelf running empty: each bay as wide as its fair share of the
## binders needs, at their tightest.
static func fitted_width(binders: Array[BinderRange], bays := BAYS) -> float:
	var bay := ShelfLayout.fit_bay_width(binders, SHELF_HEIGHTS.size() * bays)
	return bays * (maxf(bay, MIN_BAY_WIDTH) + DIVIDER_THICKNESS)


## The height of the lowest board's underside: how tall the legs are.
static func leg_height() -> float:
	return SHELF_HEIGHTS[-1] - BOARD_THICKNESS


## Builds the meshes, collision and nameplates, with a labelled space for each
## binder, in order. Call once before adding to the tree.
func build(binders: Array[BinderRange], material: Material, inner_width: float, bays := BAYS, brass: Material = null) -> void:
	width = inner_width
	_bays = bays
	var bay_ranges: Array[Vector2] = []
	for bay in bays:
		var start := width * bay / bays + (DIVIDER_THICKNESS / 2 if bay > 0 else 0.0)
		var end := width * (bay + 1) / bays - (DIVIDER_THICKNESS / 2 if bay < bays - 1 else 0.0)
		bay_ranges.append(Vector2(start, end))
		if bay > 0:
			_dividers.append(-width / 2 + width * bay / bays)
	_layout = ShelfLayout.plan(binders, SHELF_HEIGHTS.size(), bay_ranges)
	spaces.assign(_layout.binders)
	shelved.resize(spaces.size())
	_build_frame(material)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(outer_width(width), HEIGHT, DEPTH)
	shape.shape = box
	shape.position.y = HEIGHT / 2
	add_child(shape)

	top = StaticBody3D.new()
	top.name = "Top"
	add_child(top)
	var cap := top_rect()
	var cap_shape := CollisionShape3D.new()
	var cap_box := BoxShape3D.new()
	cap_box.size = Vector3(cap.size.x, CAP_THICKNESS, cap.size.y)
	cap_shape.shape = cap_box
	cap_shape.position = Vector3(cap.get_center().x, HEIGHT + CAP_THICKNESS / 2, cap.get_center().y)
	top.add_child(cap_shape)

	nameplates = Nameplates.new()
	nameplates.name = "Nameplates"
	var codes: Array[String] = []
	var centers: Array[Vector3] = []
	var plate_widths: Array[float] = []
	for i in spaces.size():
		codes.append(spaces[i].set_code)
		var center := space_position(i)
		center.y -= (BOARD_THICKNESS + BAND_DROP) / 2
		center.z = DEPTH / 2
		centers.append(center)
		plate_widths.append(_layout.widths[i] - PLATE_CLEARANCE)
	nameplates.build(codes, centers, plate_widths)
	add_child(nameplates)
	if brass != null:
		_build_label_holders(centers, plate_widths, brass)

	for shelf in SHELF_HEIGHTS.size():
		_section_lights.append(_build_section_light(shelf))


## The top cap's footprint, in the unit's local x and z: what cards and
## binders can be put down on.
func top_rect() -> Rect2:
	var cap_depth := DEPTH + CAP_OVERHANG
	var cap_width := outer_width(width) + 2 * CAP_OVERHANG
	return Rect2(-cap_width / 2, -DEPTH / 2, cap_width, cap_depth)


## The x of each pair of legs, along the unit: one under each end, and one
## under every LEGS_EVERY-th divider between.
func leg_spots() -> Array[float]:
	var half := outer_width(width) / 2 - LEG_INSET
	var spots: Array[float] = [-half]
	for i in range(LEGS_EVERY, _bays, LEGS_EVERY):
		spots.append(_dividers[i - 1])
	spots.append(half)
	return spots


## The labelled space at a world-space point on the unit's front, or -1.
func space_at(global_point: Vector3) -> int:
	var local := to_local(global_point)
	if absf(local.x) >= width / 2:
		return -1
	for shelf in SHELF_HEIGHTS.size():
		# Heights run top shelf first, so the first board at or below the
		# point is the one it's above.
		if local.y >= SHELF_HEIGHTS[shelf] - 0.01:
			var x := local.x + width / 2
			for i in spaces.size():
				if _layout.shelves[i] == shelf and x >= _layout.lefts[i] and x < _layout.lefts[i] + _layout.widths[i]:
					return i
			return -1
	return -1


## Stands a binder in a space. Returns true if it's the binder that belongs
## there (it locks in), false if not (it glows red). A `quiet` one (put back
## from a save) doesn't flash.
func shelve(space: int, binder: Binder, quiet := false) -> bool:
	var correct: bool = spaces[space] == binder.binder
	shelved[space] = binder
	binder.stand_on_shelf(self, space, binder_transform(space, binder.thickness), correct, quiet)
	if is_space_complete(space):
		Progression.earn_once("shelved:" + binder.key(), Progression.BINDER_SHELVED)
	if refresh_section(shelf_of(space)):
		Progression.earn_once("section:%s/%d" % [name, shelf_of(space)], Progression.SECTION_LIT)
	return correct


func unshelve(space: int) -> void:
	shelved[space] = null
	refresh_section(shelf_of(space))


## True when a space holds its own completed binder.
func is_space_complete(space: int) -> bool:
	var binder: Binder = shelved[space]
	return binder != null and binder.binder == spaces[space] and binder.contents.is_complete()


## True when every labelled space on a shelf holds its own completed binder.
func is_section_complete(shelf: int) -> bool:
	var any := false
	for index in spaces.size():
		if _layout.shelves[index] != shelf:
			continue
		any = true
		if not is_space_complete(index):
			return false
	return any


## Turns the shelf's nameplates and light to match what stands there.
## Returns whether the light is on.
func refresh_section(shelf: int) -> bool:
	for index in spaces.size():
		if _layout.shelves[index] == shelf:
			nameplates.set_gold(index, is_space_complete(index))
	var lit := is_section_complete(shelf)
	var material: StandardMaterial3D = _section_lights[shelf].material_override
	material.emission_energy_multiplier = 3.0 if lit else 0.0
	material.albedo_color = Color(1.0, 0.9, 0.7) if lit else Color(0.25, 0.25, 0.25)
	return lit


## Where a binder this thick stands in a space, spine out (in the unit's
## local space), centred in the space.
## The spine sits a few millimetres proud of the unit's front so it's the
## binder, not the shelf, under the crosshair.
func binder_transform(space: int, thickness: float) -> Transform3D:
	var floor_point := space_position(space)
	# Binder axes: thickness (y) runs along the shelf, the spine (-x) faces
	# out, and the binder's length (z) stands upright.
	var basis := Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0))
	var origin := Vector3(floor_point.x - thickness / 2, floor_point.y + Binder.COVER.y / 2 + 0.002,
		DEPTH / 2 + 0.004 - Binder.COVER.x / 2)
	return Transform3D(basis, origin)


## Stands each binder in its own empty space on whichever of `shelves`
## has one, quietly (a new game: every binder starts on the shelf). Returns
## the binders that found no space.
static func shelve_all(binders: Array[Binder], shelves: Array) -> Array[Binder]:
	var left: Array[Binder] = []
	for binder in binders:
		var placed := false
		for unit: ShelfUnit in shelves:
			var space := unit.space_for(binder.binder.set_code)
			if space >= 0 and unit.shelved[space] == null:
				unit.shelve(space, binder, true)
				placed = true
				break
		if not placed:
			left.append(binder)
	return left


## Shows the plate of every unlocked set's space and hides the rest, and
## hides each locked set's binder standing here (Progression.is_set_unlocked).
func refresh_locks() -> void:
	var shown: Array[bool] = []
	for space in spaces.size():
		shown.append(Progression.is_set_unlocked(spaces[space].set_code))
		var binder: Binder = shelved[space]
		if binder != null:
			binder.visible = Progression.is_set_unlocked(binder.binder.set_code)
	nameplates.show_plates(shown)


## A set has just unlocked: its plate arrives in a glow, and if its binder is
## still waiting out of sight in its space, the binder comes off the shelf
## for delivery. Returns that binder (not yet placed anywhere), or null.
func deliver_binder(set_code: String) -> Binder:
	var space := space_for(set_code)
	if space < 0:
		return null
	nameplates.set_shown(space, true, true)
	var binder: Binder = shelved[space]
	if binder == null or binder.binder.set_code != set_code or binder.visible:
		return null
	unshelve(space)
	binder.visible = true
	return binder


## The space labelled for a set's binder, or -1.
func space_for(set_code: String) -> int:
	for space in spaces.size():
		if spaces[space].set_code == set_code:
			return space
	return -1


## Which shelf (0 = top) a space is on.
func shelf_of(space: int) -> int:
	return _layout.shelves[space]


## Local position of the centre of a space's floor (the top of its board).
func space_position(space: int) -> Vector3:
	var x := -width / 2 + _layout.lefts[space] + _layout.widths[space] / 2
	return Vector3(x, SHELF_HEIGHTS[_layout.shelves[space]], 0)


## A strip light under the board above a shelf, dark until the shelf is done.
func _build_section_light(shelf: int) -> MeshInstance3D:
	var above: float = HEIGHT - BOARD_THICKNESS if shelf == 0 else SHELF_HEIGHTS[shelf - 1] - BOARD_THICKNESS
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width - 0.02, 0.006, 0.015)
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission = Color(1.0, 0.85, 0.55)
	material.emission_energy_multiplier = 0.0
	material.albedo_color = Color(0.25, 0.25, 0.25)
	var strip := MeshInstance3D.new()
	strip.mesh = mesh
	strip.material_override = material
	strip.position = Vector3(0, above - 0.003, DEPTH / 2 - 0.03)
	add_child(strip)
	return strip


## The visible furniture. Collision stays one box over the whole unit.
func _build_frame(material: Material) -> void:
	var parts := KilnModel.parts(MOULDINGS, ["ShelfEdge", "Crown", "BaseCap", "Pilaster"])
	var skirting: Array = KilnModel.parts(ROOM_MOULDINGS, ["Skirting"])["Skirting"]
	var trim := _tinted(material, 1.12)
	var dark := _tinted(material, 0.72)
	var outer := outer_width(width)
	var board_depth := DEPTH - BACK_THICKNESS - BAND_DEPTH
	var board_z := -DEPTH / 2 + BACK_THICKNESS + board_depth / 2
	var front := DEPTH / 2
	# Sides and back run from the floor to the top.
	for side in [-1, 1]:
		_add_box(Vector3(SIDE_THICKNESS, HEIGHT, DEPTH), Vector3(side * (width + SIDE_THICKNESS) / 2, HEIGHT / 2, 0), material)
	_add_box(Vector3(width, HEIGHT, BACK_THICKNESS), Vector3(0, HEIGHT / 2, -DEPTH / 2 + BACK_THICKNESS / 2), dark)

	# Boards, each fronted by a moulded edge; the top board is the last.
	var board_tops: Array = SHELF_HEIGHTS.duplicate()
	board_tops.append(HEIGHT)
	for top in board_tops:
		_add_box(Vector3(width, BOARD_THICKNESS, board_depth), Vector3(0, top - BOARD_THICKNESS / 2, board_z), material)
		_add_run(parts["ShelfEdge"], Vector3(-width / 2, top, front - BAND_DEPTH), Vector3.RIGHT, width, trim)

	# Dividers between bays; ShelfLayout keeps every space clear of them.
	var lowest := leg_height()
	var divider_height := HEIGHT - BOARD_THICKNESS - lowest
	var divider_depth := DEPTH - BACK_THICKNESS - BAND_DEPTH
	for x in _dividers:
		_add_box(Vector3(DIVIDER_THICKNESS, divider_height, divider_depth),
			Vector3(x, lowest + divider_height / 2, board_z), material)

	# Fluted pilasters on the ends, from the base cap up to the crown.
	var pilaster_bottom := lowest
	var pilaster_tall := HEIGHT - CROWN_HEIGHT - pilaster_bottom
	for side in [-1, 1]:
		KilnModel.add(self, parts["Pilaster"], material, Transform3D(Basis.from_scale(Vector3(1, pilaster_tall, 1)),
			Vector3(side * (width + SIDE_THICKNESS) / 2, pilaster_bottom, front)))

	# The panelled base under the lowest shelf: panels set back, a frame of
	# stiles and rails proud of them, a cap moulding, and the skirting.
	var base_face := front - BASE_SET_BACK
	_add_box(Vector3(outer, lowest, 0.01), Vector3(0, lowest / 2, base_face - 0.005), dark)
	var frame_z := base_face + BASE_FRAME_PROUD / 2
	var rail_bottom := SKIRTING_HEIGHT
	var rail_top := lowest - BASE_CAP_HEIGHT
	for y in [rail_bottom + BASE_FRAME_WIDTH / 2, rail_top - BASE_FRAME_WIDTH / 2]:
		_add_box(Vector3(outer, BASE_FRAME_WIDTH, BASE_FRAME_PROUD), Vector3(0, y, frame_z), material)
	var stile_tall := rail_top - rail_bottom
	for x in leg_spots():
		_add_box(Vector3(BASE_FRAME_WIDTH, stile_tall, BASE_FRAME_PROUD), Vector3(x, rail_bottom + stile_tall / 2, frame_z), material)
	_add_run(parts["BaseCap"], Vector3(-outer / 2, rail_top, front - BASE_SET_BACK), Vector3.RIGHT, outer, trim)
	_add_run(skirting, Vector3(-outer / 2 - 0.022, 0, front - BASE_SET_BACK), Vector3.RIGHT, outer + 0.044, trim)
	for side in [-1, 1]:
		# Skirting returns along each end, back to the wall.
		var start := Vector3(side * outer / 2, 0, front - BASE_SET_BACK if side > 0 else -DEPTH / 2)
		_add_run(skirting, start, Vector3.FORWARD if side > 0 else Vector3.BACK, DEPTH - BASE_SET_BACK, trim, Vector3.RIGHT * side)

	# Crown under the top along the front and back along both ends, then
	# the top itself, overhanging the crown.
	var crown_y := HEIGHT
	_add_run(parts["Crown"], Vector3(-outer / 2 - 0.035, crown_y, front), Vector3.RIGHT, outer + 0.07, trim)
	for side in [-1, 1]:
		var start := Vector3(side * outer / 2, crown_y, front if side > 0 else -DEPTH / 2)
		_add_run(parts["Crown"], start, Vector3.FORWARD if side > 0 else Vector3.BACK, DEPTH, trim, Vector3.RIGHT * side)
	var cap := top_rect()
	_add_box(Vector3(cap.size.x, CAP_THICKNESS, cap.size.y),
		Vector3(cap.get_center().x, HEIGHT + CAP_THICKNESS / 2, cap.get_center().y), trim)


## A 1 m moulding (`part`, face toward +Z in the model) laid from `start`
## along `along` for `length`, its face toward `facing` (the front, +Z, by
## default). `along` must turn into `facing` as seen from above (along ×
## up = facing), or the moulding comes out mirrored.
func _add_run(part: Array, start: Vector3, along: Vector3, length: float, material: Material, facing := Vector3.BACK) -> void:
	var basis := Basis(along, Vector3.UP, facing)
	KilnModel.add(self, part, material, Transform3D(basis.scaled_local(Vector3(length, 1, 1)), start))


## Brass lips above and below each nameplate, like a library label holder.
func _build_label_holders(centers: Array[Vector3], plate_widths: Array[float], brass: Material) -> void:
	for i in centers.size():
		for side in [-1, 1]:
			var y: float = centers[i].y + side * (Nameplates.PLATE_SIZE.y / 2 + HOLDER_LIP / 2)
			_add_box(Vector3(plate_widths[i] + 0.004, HOLDER_LIP, HOLDER_DEPTH),
				Vector3(centers[i].x, y, DEPTH / 2 + HOLDER_DEPTH / 2), brass)


## A lighter or darker copy of the shelf material, for trim and back panels.
static func _tinted(material: Material, factor: float) -> Material:
	if not material is StandardMaterial3D:
		return material
	var copy: StandardMaterial3D = material.duplicate()
	var c := copy.albedo_color
	copy.albedo_color = Color(minf(c.r * factor, 1.0), minf(c.g * factor, 1.0), minf(c.b * factor, 1.0), c.a)
	return copy


func _add_box(size: Vector3, center: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	add_child(instance)
