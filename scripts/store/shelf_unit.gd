class_name ShelfUnit
extends StaticBody3D
## One shelving unit, any width: plain store shelving with two shelves,
## split into bays by thin dividers, with an edge band on the front of each
## board and a top cap. It stands raised on pairs of legs (the store adds
## them at leg_spots(), in the tables' style), and its top is a surface like
## a table's, for cards and binders. Its origin is on the floor, centred
## under the unit, and its open front faces local +Z.
##
## Every space is labelled for one binder, with its set code on the shelf
## lip under it, and is as wide as that binder (ShelfLayout). A binder stood
## in its own space locks in; in any other labelled space it glows red. When
## every labelled space on a shelf holds its own completed binder, the light
## under the shelf above comes on.
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
## Roughly how wide a bay is between dividers.
const BAY_WIDTH := 0.8
const DIVIDER_THICKNESS := 0.012
const BACK_THICKNESS := 0.02
## The edge band on each board's front: its depth, and how far it hangs below
## the board. Its top is flush with the board, so binders stand clear of it.
const BAND_DEPTH := 0.012
const BAND_DROP := 0.008
const CAP_THICKNESS := 0.025
## How far the top cap overhangs the sides and front.
const CAP_OVERHANG := 0.012
## Leg pairs stand no further apart than this.
const LEG_SPACING := 2.0
## How far a leg's centre sits in from the unit's front and back.
const LEG_INSET := 0.06

## Inside width, between the side panels.
var width := 0.0
## Per space, in shelf order: the binder that belongs there.
var spaces: Array = []
## Per space: the Binder standing there now, or null.
var shelved: Array = []
## The top's body: cards and binders put down on it rest there.
var top: StaticBody3D

var _layout: ShelfLayout
var _dividers: Array[float] = []
var _section_lights: Array[MeshInstance3D] = []


## Outside width of a unit this wide inside.
static func outer_width(inner_width: float) -> float:
	return inner_width + 2 * SIDE_THICKNESS


## The height of the lowest board's underside: how tall the legs are.
static func leg_height() -> float:
	return SHELF_HEIGHTS[-1] - BOARD_THICKNESS


## Builds the meshes, collision and labels, with a labelled space for each
## binder, in order. Call once before adding to the tree.
func build(binders: Array[BinderRange], material: Material, inner_width: float) -> void:
	width = inner_width
	var bays := maxi(1, roundi(width / BAY_WIDTH))
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

	for i in spaces.size():
		var binder: BinderRange = spaces[i]
		var label := Label3D.new()
		label.text = binder.set_code
		label.font_size = 28
		label.pixel_size = 0.0007
		label.modulate = Color(0.15, 0.15, 0.15)
		label.outline_size = 0
		label.double_sided = false
		label.position = space_position(i)
		label.position.y -= BOARD_THICKNESS / 2
		label.position.z = DEPTH / 2 + 0.002
		label.set_meta("binder_label", binder.label)
		label.visibility_range_end = 6.0
		add_child(label)

	for shelf in SHELF_HEIGHTS.size():
		_section_lights.append(_build_section_light(shelf))


## The top cap's footprint, in the unit's local x and z: what cards and
## binders can be put down on.
func top_rect() -> Rect2:
	var cap_depth := DEPTH + CAP_OVERHANG
	var cap_width := outer_width(width) + 2 * CAP_OVERHANG
	return Rect2(-cap_width / 2, -DEPTH / 2, cap_width, cap_depth)


## The x of each pair of legs, along the unit: one under each end, and more
## between, under dividers, so no two are more than LEG_SPACING apart.
func leg_spots() -> Array[float]:
	var half := outer_width(width) / 2 - LEG_INSET
	var spots: Array[float] = [-half]
	var gaps := ceili(2 * half / LEG_SPACING)
	for i in range(1, gaps):
		var want := -half + 2 * half * i / gaps
		var best := want
		var nearest := INF
		for x in _dividers:
			if absf(x - want) < nearest:
				nearest = absf(x - want)
				best = x
		spots.append(best)
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
## there (it locks in), false if not (it glows red).
func shelve(space: int, binder: Binder) -> bool:
	var correct: bool = spaces[space] == binder.binder
	shelved[space] = binder
	binder.stand_on_shelf(self, space, binder_transform(space, binder.thickness), correct)
	if correct:
		Progression.earn_once("shelved:" + binder.key(), Progression.BINDER_SHELVED)
	if refresh_section(shelf_of(space)):
		Progression.earn_once("section:%s/%d" % [name, shelf_of(space)], Progression.SECTION_LIT)
	return correct


func unshelve(space: int) -> void:
	shelved[space] = null
	refresh_section(shelf_of(space))


## True when every labelled space on a shelf holds its own completed binder.
func is_section_complete(shelf: int) -> bool:
	var any := false
	for index in spaces.size():
		if _layout.shelves[index] != shelf:
			continue
		any = true
		var binder: Binder = shelved[index]
		if binder == null or binder.binder != spaces[index] or not binder.contents.is_complete():
			return false
	return any


## Turns the shelf's light on or off to match. Returns whether it's on.
func refresh_section(shelf: int) -> bool:
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
	var band := _tinted(material, 1.12)
	var dark := _tinted(material, 0.72)
	var board_depth := DEPTH - BACK_THICKNESS - BAND_DEPTH
	var board_z := -DEPTH / 2 + BACK_THICKNESS + board_depth / 2
	var band_z := DEPTH / 2 - BAND_DEPTH / 2
	# Sides and back run from the bottom board's underside to the top.
	var bottom := leg_height()
	var tall := HEIGHT - bottom
	for side in [-1, 1]:
		_add_box(Vector3(SIDE_THICKNESS, tall, DEPTH), Vector3(side * (width + SIDE_THICKNESS) / 2, bottom + tall / 2, 0), material)
	_add_box(Vector3(width, tall, BACK_THICKNESS), Vector3(0, bottom + tall / 2, -DEPTH / 2 + BACK_THICKNESS / 2), dark)

	# Boards, each with an edge band on its front; the top board is the last.
	var board_tops: Array = SHELF_HEIGHTS.duplicate()
	board_tops.append(HEIGHT)
	for top in board_tops:
		_add_box(Vector3(width, BOARD_THICKNESS, board_depth), Vector3(0, top - BOARD_THICKNESS / 2, board_z), material)
		var band_height := BOARD_THICKNESS + BAND_DROP
		_add_box(Vector3(width, band_height, BAND_DEPTH), Vector3(0, top - band_height / 2, band_z), band)

	# Dividers between bays; ShelfLayout keeps every space clear of them.
	var lowest := leg_height()
	var divider_height := HEIGHT - BOARD_THICKNESS - lowest
	var divider_depth := DEPTH - BACK_THICKNESS - BAND_DEPTH
	for x in _dividers:
		_add_box(Vector3(DIVIDER_THICKNESS, divider_height, divider_depth),
			Vector3(x, lowest + divider_height / 2, board_z), material)

	# Top cap, overhanging the sides and front (flush with the wall behind).
	var cap := top_rect()
	_add_box(Vector3(cap.size.x, CAP_THICKNESS, cap.size.y),
		Vector3(cap.get_center().x, HEIGHT + CAP_THICKNESS / 2, cap.get_center().y), band)


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
