extends Node3D
## Builds the graybox store: one small room, cluttered on purpose. A closed
## door in the front wall, one wall-length binder shelf on the back wall, and
## four work tables in the middle for setting binders down and stacking cards.
## The side walls are left open for store dressing later.
##
## Everything is plain boxes so the layout is cheap to change. Coordinates are
## metres: x runs 0..WIDTH left to right as you face the back wall, z runs from
## the back wall (0) to the front wall (DEPTH), y is up.

const WIDTH := 12.0
const DEPTH := 8.0
const CEILING_HEIGHT := 3.0
const WALL_THICKNESS := 0.2
## The door (closed, not usable yet): centred on the front wall.
const DOOR_SIZE := Vector2(1.0, 2.1)
## The binder shelf's x range along the back wall. Binders read left to
## right, top shelf first, so the shelf reads the timeline like a book.
const BACK_SHELF := Vector2(2.0, 10.0)
const TABLE_SIZE := Vector3(1.3, 1.0, 1.3)
const TABLE_CENTERS := [Vector2(4.6, 2.9), Vector2(7.4, 2.9), Vector2(4.6, 5.3), Vector2(7.4, 5.3)]

## Floor footprints nothing on the floor may overlap (the shelves and the
## table legs), as x/z rectangles. The space under a table top is open:
## cards can end up underneath.
var obstacles: Array[Rect2] = []

var _wall_material := _material(Color(0.86, 0.84, 0.8))
var _floor_material := _material(Color(0.55, 0.5, 0.45))
var _shelf_material := _material(Color(0.62, 0.48, 0.34))
var _door_material := _material(Color(0.9, 0.5, 0.15))
var _table_material := _wood(Color(0.46, 0.29, 0.16))
var _felt_material := _material(Color(0.1, 0.24, 0.17))


## The floor area cards can land on, inset a little from the walls.
func floor_bounds() -> Rect2:
	return Rect2(0.05, 0.05, WIDTH - 0.1, DEPTH - 0.1)


func _ready() -> void:
	_build_shell()
	_build_binder_shelves()
	_build_tables()
	_build_lights()


func _build_shell() -> void:
	var half := WALL_THICKNESS / 2
	_add_solid(Vector3(WIDTH, 0.2, DEPTH), Vector3(WIDTH / 2, -0.1, DEPTH / 2), _floor_material)
	_add_solid(Vector3(WIDTH, 0.2, DEPTH), Vector3(WIDTH / 2, CEILING_HEIGHT + 0.1, DEPTH / 2), _wall_material)
	_add_wall_x(0.0, WIDTH, -half)
	_add_wall_x(0.0, WIDTH, DEPTH + half)
	_add_wall_z(-half, 0.0, DEPTH)
	_add_wall_z(WIDTH + half, 0.0, DEPTH)
	# The door is just a slab on the inside of the front wall for now.
	_add_solid(Vector3(DOOR_SIZE.x, DOOR_SIZE.y, 0.04), Vector3(WIDTH / 2, DOOR_SIZE.y / 2, DEPTH - 0.02), _door_material)


## One wall-length shelf on the back wall, facing the door, holding every
## binder.
func _build_binder_shelves() -> void:
	var per_shelf: Array[int] = [int((BACK_SHELF.y - BACK_SHELF.x - 2 * ShelfUnit.SIDE_THICKNESS) / ShelfUnit.SPACE_WIDTH)]
	var assignments := ShelfLayout.assign(CardDatabase.all_binders(), per_shelf)
	var unit := ShelfUnit.new()
	unit.name = "BinderShelf"
	unit.build(assignments[0], _shelf_material, per_shelf[0])
	unit.position = Vector3((BACK_SHELF.x + BACK_SHELF.y) / 2, 0, ShelfUnit.DEPTH / 2)
	_add_shelf(unit)


## Each table is a heavy solid-wood games table: a thick top with a stepped
## edge and a felt playing surface, a deep apron, and four square legs that
## taper toward the floor. The space under the top stays open, so cards that
## slid underneath stay in sight and in reach (crouching gets you under).
func _build_tables() -> void:
	for center in TABLE_CENTERS:
		_build_table(center)


func _build_table(center: Vector2) -> void:
	const TOP := 0.05
	## The top's underside steps in here to soften the edge.
	const EDGE_STEP := 0.012
	## Legs: square, wider at the top than at the foot, set in from the edge.
	const LEG_TOP := 0.09
	const LEG_FOOT := 0.065
	const LEG_INSET := 0.05
	const APRON_HEIGHT := 0.11
	const APRON_THICKNESS := 0.025
	const FELT_BORDER := 0.11
	var body := StaticBody3D.new()
	body.position = Vector3(center.x, 0, center.y)
	add_child(body)
	var size := Vector2(TABLE_SIZE.x, TABLE_SIZE.z)
	var top_y := TABLE_SIZE.y

	_add_part(body, Vector3(size.x, TOP - EDGE_STEP, size.y), Vector3(0, top_y - (TOP - EDGE_STEP) / 2, 0), _table_material, true)
	_add_part(body, Vector3(size.x - 2 * EDGE_STEP, EDGE_STEP, size.y - 2 * EDGE_STEP),
		Vector3(0, top_y - TOP + EDGE_STEP / 2, 0), _table_material, true)
	_add_part(body, Vector3(size.x - 2 * FELT_BORDER, 0.001, size.y - 2 * FELT_BORDER),
		Vector3(0, top_y + 0.0005, 0), _felt_material, false)

	var leg_half := size / 2 - Vector2.ONE * (LEG_INSET + LEG_TOP / 2)
	var leg_height := top_y - TOP
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at: Vector2 = corner * leg_half
		var leg := MeshInstance3D.new()
		leg.mesh = _tapered_leg(LEG_TOP, LEG_FOOT, leg_height)
		leg.material_override = _table_material
		leg.position = Vector3(at.x, 0, at.y)
		body.add_child(leg)
		_add_shape(body, Vector3(LEG_TOP, leg_height, LEG_TOP), Vector3(at.x, leg_height / 2, at.y))
		var world := center + at
		obstacles.append(Rect2(world - Vector2.ONE * LEG_TOP / 2, Vector2.ONE * LEG_TOP))

	# Apron rails between the legs, set a little back from the legs' faces.
	var apron_y := top_y - TOP - APRON_HEIGHT / 2
	var rail_offset := leg_half + Vector2.ONE * (LEG_TOP / 2 - APRON_THICKNESS / 2 - 0.008)
	for side in [-1, 1]:
		_add_part(body, Vector3(2 * leg_half.x, APRON_HEIGHT, APRON_THICKNESS), Vector3(0, apron_y, side * rail_offset.y), _table_material, true)
		_add_part(body, Vector3(APRON_THICKNESS, APRON_HEIGHT, 2 * leg_half.y), Vector3(side * rail_offset.x, apron_y, 0), _table_material, true)


## A square leg standing on the floor, `top` wide under the table and
## narrowing to `foot` at the floor.
static func _tapered_leg(top: float, foot: float, height: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var a0 := Vector3(a.x * foot / 2, 0, a.y * foot / 2)
		var b0 := Vector3(b.x * foot / 2, 0, b.y * foot / 2)
		var a1 := Vector3(a.x * top / 2, height, a.y * top / 2)
		var b1 := Vector3(b.x * top / 2, height, b.y * top / 2)
		# Clockwise seen from outside (Godot's front faces).
		for v in [a0, b0, b1, a0, b1, a1]:
			tool.add_vertex(v)
	tool.generate_normals()
	return tool.commit()


func _add_part(body: StaticBody3D, size: Vector3, center: Vector3, material: Material, solid: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	body.add_child(instance)
	if solid:
		_add_shape(body, size, center)


func _add_shape(body: StaticBody3D, size: Vector3, center: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)


func _build_lights() -> void:
	for x in [2.5, 6.0, 9.5]:
		for z in [2.5, 5.5]:
			var light := OmniLight3D.new()
			light.position = Vector3(x, CEILING_HEIGHT - 0.3, z)
			light.omni_range = 5.5
			light.light_energy = 1.2
			add_child(light)


func _add_shelf(unit: ShelfUnit) -> void:
	add_child(unit)
	# Footprint is width × depth, turned with the unit (always a multiple of 90°).
	var size := Vector2(ShelfUnit.outer_width(unit.spaces_per_shelf), ShelfUnit.DEPTH)
	if absf(sin(unit.rotation.y)) > 0.5:
		size = Vector2(size.y, size.x)
	obstacles.append(Rect2(Vector2(unit.position.x, unit.position.z) - size / 2, size))


func _add_wall_x(x_from: float, x_to: float, z: float) -> void:
	_add_solid(Vector3(x_to - x_from, CEILING_HEIGHT, WALL_THICKNESS),
		Vector3((x_from + x_to) / 2, CEILING_HEIGHT / 2, z), _wall_material)


func _add_wall_z(x: float, z_from: float, z_to: float) -> void:
	_add_solid(Vector3(WALL_THICKNESS, CEILING_HEIGHT, z_to - z_from),
		Vector3(x, CEILING_HEIGHT / 2, (z_from + z_to) / 2), _wall_material)


func _add_solid(size: Vector3, center: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	body.add_child(instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)


## A warm oiled hardwood: a little sheen, no texture yet (that's M4e).
static func _wood(color: Color) -> StandardMaterial3D:
	var material := _material(color)
	material.roughness = 0.55
	return material


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
