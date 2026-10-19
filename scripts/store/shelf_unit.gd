class_name ShelfUnit
extends StaticBody3D
## One shelving unit, any number of spaces wide: plain flat-pack store
## shelving split into bays by thin dividers, with an edge band on the front
## of each board, a recessed kick plate and a top cap. Its origin is on the
## floor, centred under the unit, and its open front faces local +Z.
##
## Labelled units show each binder's set code and number range on the shelf
## lip under its space. A binder stood in its own space locks in; in any other
## labelled space it glows red. When every labelled space on a shelf holds its
## own completed binder, the light under the shelf above comes on.

const SPACE_WIDTH := 0.1
const DEPTH := 0.35
const HEIGHT := 2.2
const BOARD_THICKNESS := 0.04
const SIDE_THICKNESS := 0.03
## Height of each shelf board's top surface, top shelf first.
const SHELF_HEIGHTS := [1.75, 1.35, 0.95, 0.55, 0.15]
## Roughly how many spaces wide a bay is between dividers (about 0.8 m).
const BAY_SPACES := 8
const DIVIDER_THICKNESS := 0.012
const BACK_THICKNESS := 0.02
## The edge band on each board's front: its depth, and how far it hangs below
## the board. Its top is flush with the board, so binders stand clear of it.
const BAND_DEPTH := 0.012
const BAND_DROP := 0.008
## How far the kick plate sits back from the front.
const KICK_RECESS := 0.025
const CAP_THICKNESS := 0.025
## How far the top cap overhangs the sides and front.
const CAP_OVERHANG := 0.012

## Spaces along each shelf.
var spaces_per_shelf := ShelfLayout.SPACES_PER_SHELF
## Inside width, between the side panels.
var width := 0.0
## Per space (shelf * spaces_per_shelf + space): the binder that belongs
## there, or null. Empty for unlabelled units.
var spaces: Array = []
## Per space: the Binder standing there now, or null.
var shelved: Array = []

var _section_lights: Array[MeshInstance3D] = []


## Outside width of a unit with this many spaces per shelf.
static func outer_width(per_shelf: int) -> float:
	return per_shelf * SPACE_WIDTH + 2 * SIDE_THICKNESS


## Builds the meshes, collision and labels. Call once before adding to the
## tree. A labelled unit gets SHELVES_PER_UNIT * per_shelf spaces from
## ShelfLayout.assign(); an unlabelled one gets [].
func build(space_binders: Array, material: Material, per_shelf := ShelfLayout.SPACES_PER_SHELF) -> void:
	spaces = space_binders
	spaces_per_shelf = per_shelf
	width = per_shelf * SPACE_WIDTH
	shelved.resize(spaces.size())
	_build_frame(material)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width + 2 * SIDE_THICKNESS, HEIGHT, DEPTH)
	shape.shape = box
	shape.position.y = HEIGHT / 2
	add_child(shape)

	for i in spaces.size():
		var binder: BinderRange = spaces[i]
		if binder == null:
			continue
		var label := Label3D.new()
		label.text = binder.set_code
		label.font_size = 32
		label.pixel_size = 0.0007
		label.modulate = Color(0.15, 0.15, 0.15)
		label.outline_size = 0
		label.double_sided = false
		label.position = space_position(shelf_of(i), i % spaces_per_shelf)
		label.position.y -= BOARD_THICKNESS / 2
		label.position.z = DEPTH / 2 + 0.002
		label.set_meta("binder_label", binder.label)
		label.visibility_range_end = 6.0
		add_child(label)

	if not spaces.is_empty():
		for shelf in ShelfLayout.SHELVES_PER_UNIT:
			_section_lights.append(_build_section_light(shelf))


## The labelled space at a world-space point on the unit's front, or -1.
func space_at(global_point: Vector3) -> int:
	if spaces.is_empty():
		return -1
	var local := to_local(global_point)
	if absf(local.x) >= width / 2:
		return -1
	for shelf in SHELF_HEIGHTS.size():
		# Heights run top shelf first, so the first board at or below the
		# point is the one it's above.
		if local.y >= SHELF_HEIGHTS[shelf] - 0.01:
			var index := shelf * spaces_per_shelf + int((local.x + width / 2) / SPACE_WIDTH)
			return index if spaces[index] != null else -1
	return -1


## Stands a binder in a space. Returns true if it's the binder that belongs
## there (it locks in), false if not (it glows red).
func shelve(space: int, binder: Binder) -> bool:
	var correct: bool = spaces[space] == binder.binder
	shelved[space] = binder
	binder.stand_on_shelf(self, space, binder_transform(space), correct)
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
	for space in spaces_per_shelf:
		var index := shelf * spaces_per_shelf + space
		if spaces[index] == null:
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


## Where a binder stands in a space, spine out (in the unit's local space).
## The spine sits a few millimetres proud of the unit's front so it's the
## binder, not the shelf, under the crosshair.
func binder_transform(space: int) -> Transform3D:
	var floor_point := space_position(shelf_of(space), space % spaces_per_shelf)
	# Binder axes: thickness (y) runs along the shelf, the spine (-x) faces
	# out, and the binder's length (z) stands upright.
	var basis := Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0))
	var origin := Vector3(floor_point.x - Binder.THICKNESS / 2, floor_point.y + Binder.COVER.y / 2 + 0.002,
		DEPTH / 2 + 0.004 - Binder.COVER.x / 2)
	return Transform3D(basis, origin)


## Which shelf (0 = top) a space is on.
func shelf_of(space: int) -> int:
	return space / spaces_per_shelf


## Local position of the centre of a space's floor (the top of its board).
func space_position(shelf: int, space: int) -> Vector3:
	return Vector3(-width / 2 + SPACE_WIDTH * (space + 0.5), SHELF_HEIGHTS[shelf], 0)


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
	for side in [-1, 1]:
		_add_box(Vector3(SIDE_THICKNESS, HEIGHT, DEPTH), Vector3(side * (width + SIDE_THICKNESS) / 2, HEIGHT / 2, 0), material)
	_add_box(Vector3(width, HEIGHT, BACK_THICKNESS), Vector3(0, HEIGHT / 2, -DEPTH / 2 + BACK_THICKNESS / 2), dark)

	# Boards, each with an edge band on its front; the top board is the last.
	var board_tops: Array = SHELF_HEIGHTS.duplicate()
	board_tops.append(HEIGHT)
	for top in board_tops:
		_add_box(Vector3(width, BOARD_THICKNESS, board_depth), Vector3(0, top - BOARD_THICKNESS / 2, board_z), material)
		var band_height := BOARD_THICKNESS + BAND_DROP
		_add_box(Vector3(width, band_height, BAND_DEPTH), Vector3(0, top - band_height / 2, band_z), band)

	# Dividers on space boundaries, so every space keeps its full width.
	var bays := maxi(1, roundi(float(spaces_per_shelf) / BAY_SPACES))
	var lowest: float = SHELF_HEIGHTS[-1] - BOARD_THICKNESS
	var divider_height := HEIGHT - BOARD_THICKNESS - lowest
	var divider_depth := DEPTH - BACK_THICKNESS - BAND_DEPTH
	for bay in range(1, bays):
		var x := -width / 2 + SPACE_WIDTH * roundi(float(bay * spaces_per_shelf) / bays)
		_add_box(Vector3(DIVIDER_THICKNESS, divider_height, divider_depth),
			Vector3(x, lowest + divider_height / 2, board_z), material)

	# Kick plate, set back under the bottom board.
	var kick_height: float = lowest - BAND_DROP
	_add_box(Vector3(width, kick_height, 0.018), Vector3(0, kick_height / 2, DEPTH / 2 - KICK_RECESS - 0.009), dark)

	# Top cap, overhanging the sides and front (flush with the wall behind).
	var cap_depth := DEPTH + CAP_OVERHANG
	_add_box(Vector3(width + 2 * (SIDE_THICKNESS + CAP_OVERHANG), CAP_THICKNESS, cap_depth),
		Vector3(0, HEIGHT + CAP_THICKNESS / 2, -DEPTH / 2 + cap_depth / 2), band)


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
