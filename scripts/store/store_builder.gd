extends Node3D
## Builds the graybox store: one small room, cluttered on purpose. A closed
## door in the front wall, three wall-length binder shelves ringing the other
## walls (left, back, right), and four work tables in the middle for setting
## binders down and stacking cards.
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
## Binder shelves: [x or z range along the wall] for the left, back and
## right walls. Binders run left wall (from the door end), back wall, right
## wall (back to the door end), so walking round the room reads the timeline.
const LEFT_SHELF := Vector2(1.2, 6.7) # z range
const BACK_SHELF := Vector2(2.0, 10.0) # x range
const RIGHT_SHELF := Vector2(1.2, 6.7) # z range
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
var _table_material := _material(Color(0.2, 0.42, 0.3))


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


## Three wall-length shelves, each as many spaces wide as its wall allows,
## with the binders split evenly between them.
func _build_binder_shelves() -> void:
	var lengths := [LEFT_SHELF.y - LEFT_SHELF.x, BACK_SHELF.y - BACK_SHELF.x, RIGHT_SHELF.y - RIGHT_SHELF.x]
	var per_shelf: Array[int] = []
	for length in lengths:
		per_shelf.append(int((length - 2 * ShelfUnit.SIDE_THICKNESS) / ShelfUnit.SPACE_WIDTH))
	var assignments := ShelfLayout.assign(CardDatabase.all_binders(), per_shelf)
	var inset := ShelfUnit.DEPTH / 2
	var placements := [
		# Left wall, facing +x: reads from the door end toward the back.
		[Vector3(inset, 0, (LEFT_SHELF.x + LEFT_SHELF.y) / 2), PI / 2],
		# Back wall, facing the door: reads left to right.
		[Vector3((BACK_SHELF.x + BACK_SHELF.y) / 2, 0, inset), 0.0],
		# Right wall, facing -x: reads from the back toward the door end.
		[Vector3(WIDTH - inset, 0, (RIGHT_SHELF.x + RIGHT_SHELF.y) / 2), -PI / 2],
	]
	for u in 3:
		var unit := ShelfUnit.new()
		unit.name = "BinderShelf%d" % (u + 1)
		unit.build(assignments[u], _shelf_material, per_shelf[u])
		unit.position = placements[u][0]
		unit.rotation.y = placements[u][1]
		_add_shelf(unit)


## Each table is a top on four legs, so cards that slid underneath stay in
## sight and in reach.
func _build_tables() -> void:
	const TOP := 0.04
	const LEG := 0.06
	var half := Vector2(TABLE_SIZE.x, TABLE_SIZE.z) / 2 - Vector2(LEG, LEG)
	for center in TABLE_CENTERS:
		_add_solid(Vector3(TABLE_SIZE.x, TOP, TABLE_SIZE.z), Vector3(center.x, TABLE_SIZE.y - TOP / 2, center.y), _table_material)
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var leg: Vector2 = center + corner * half
			_add_solid(Vector3(LEG, TABLE_SIZE.y - TOP, LEG), Vector3(leg.x, (TABLE_SIZE.y - TOP) / 2, leg.y), _table_material)
			obstacles.append(Rect2(leg - Vector2(LEG, LEG) / 2, Vector2(LEG, LEG)))


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


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
