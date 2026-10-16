extends Node3D
## Builds the graybox store (M1): main floor with an entrance, play tables,
## counter and two aisles of gondola shelving; a back room through a doorway;
## and the labelled wall shelving where every binder has its space.
##
## Everything is plain boxes so the layout is cheap to change. Coordinates are
## metres: x runs 0..TOTAL_WIDTH left to right as you walk in, z runs from the
## back wall (0) to the storefront (DEPTH), y is up.

const MAIN_WIDTH := 20.0
const BACK_ROOM_WIDTH := 8.0
const TOTAL_WIDTH := MAIN_WIDTH + BACK_ROOM_WIDTH
const DEPTH := 14.0
const CEILING_HEIGHT := 3.2
const WALL_THICKNESS := 0.2
const ENTRANCE := Vector2(8.0, 10.0) # x range of the front door gap
const BACK_ROOM_DOOR := Vector2(6.0, 8.0) # z range of the doorway in the partition

var _wall_material := _material(Color(0.86, 0.84, 0.8))
var _floor_material := _material(Color(0.55, 0.5, 0.45))
var _shelf_material := _material(Color(0.62, 0.48, 0.34))
var _fixture_material := _material(Color(0.3, 0.32, 0.36))
var _table_material := _material(Color(0.2, 0.42, 0.3))


func _ready() -> void:
	_build_shell()
	_build_labelled_shelving()
	_build_aisles()
	_build_fixtures()
	_build_back_room()
	_build_lights()


func _build_shell() -> void:
	var half := WALL_THICKNESS / 2
	_add_solid(Vector3(TOTAL_WIDTH, 0.2, DEPTH), Vector3(TOTAL_WIDTH / 2, -0.1, DEPTH / 2), _floor_material)
	_add_solid(Vector3(TOTAL_WIDTH, 0.2, DEPTH), Vector3(TOTAL_WIDTH / 2, CEILING_HEIGHT + 0.1, DEPTH / 2), _wall_material)
	# Back, left and right walls.
	_add_wall_x(0.0, TOTAL_WIDTH, -half)
	_add_wall_z(-half, 0.0, DEPTH)
	_add_wall_z(TOTAL_WIDTH + half, 0.0, DEPTH)
	# Storefront with the entrance gap.
	_add_wall_x(0.0, ENTRANCE.x, DEPTH + half)
	_add_wall_x(ENTRANCE.y, TOTAL_WIDTH, DEPTH + half)
	_add_solid(Vector3(ENTRANCE.y - ENTRANCE.x, 0.8, WALL_THICKNESS),
		Vector3((ENTRANCE.x + ENTRANCE.y) / 2, CEILING_HEIGHT - 0.4, DEPTH + half), _wall_material)
	# Partition between the shop floor and the back room, with a doorway.
	_add_wall_z(MAIN_WIDTH, 0.0, BACK_ROOM_DOOR.x)
	_add_wall_z(MAIN_WIDTH, BACK_ROOM_DOOR.y, DEPTH)
	_add_solid(Vector3(WALL_THICKNESS, 0.9, BACK_ROOM_DOOR.y - BACK_ROOM_DOOR.x),
		Vector3(MAIN_WIDTH, CEILING_HEIGHT - 0.45, (BACK_ROOM_DOOR.x + BACK_ROOM_DOOR.y) / 2), _wall_material)


## Wall shelving for every binder: along the back wall first, then down the
## left wall toward the storefront. Units are filled in shelf order.
func _build_labelled_shelving() -> void:
	var binders := CardDatabase.all_binders()
	var unit_count := ShelfLayout.units_needed(binders.size())
	var assignments := ShelfLayout.assign(binders, unit_count)
	var unit_width := ShelfUnit.WIDTH + 2 * ShelfUnit.SIDE_THICKNESS
	var back_wall_units := int((MAIN_WIDTH - 1.0) / unit_width)
	for u in unit_count:
		var unit := ShelfUnit.new()
		unit.name = "BinderShelf%02d" % (u + 1)
		unit.build(assignments[u], _shelf_material)
		if u < back_wall_units:
			# Back wall, reading left to right as you face it.
			unit.position = Vector3(0.6 + unit_width * (u + 0.5), 0, ShelfUnit.DEPTH / 2)
		else:
			# Left wall, facing +x, continuing from the back corner toward the front.
			var along := u - back_wall_units
			unit.rotation.y = PI / 2
			unit.position = Vector3(ShelfUnit.DEPTH / 2, 0, 1.0 + unit_width * (along + 0.5))
		add_child(unit)


## Two aisles of double-sided gondola shelving in the middle of the shop
## floor. They run front to back, so from the door you look down the aisles
## to the binder wall.
func _build_aisles() -> void:
	var unit_width := ShelfUnit.WIDTH + 2 * ShelfUnit.SIDE_THICKNESS
	for row_x in [7.0, 12.0]:
		for i in 4:
			var z := 3.0 + unit_width * (i + 0.5)
			for facing in [PI / 2, -PI / 2]:
				var unit := ShelfUnit.new()
				unit.build([], _shelf_material)
				unit.rotation.y = facing
				# Facing +x sits on the +x side of the row's spine, and vice versa.
				unit.position = Vector3(row_x + (ShelfUnit.DEPTH / 2) * (1 if facing > 0 else -1), 0, z)
				add_child(unit)


func _build_fixtures() -> void:
	# Front counter, right of the door.
	_add_solid(Vector3(4.0, 1.0, 0.8), Vector3(16.0, 0.5, 11.2), _fixture_material)
	# Play tables, left of the door.
	for center in [Vector2(2.6, 11.8), Vector2(5.4, 11.8), Vector2(2.6, 9.8)]:
		_add_solid(Vector3(1.8, 0.75, 0.9), Vector3(center.x, 0.375, center.y), _table_material)


## Plain storage racks along the back room's walls.
func _build_back_room() -> void:
	var unit_width := ShelfUnit.WIDTH + 2 * ShelfUnit.SIDE_THICKNESS
	for i in 5:
		var rack := ShelfUnit.new()
		rack.build([], _shelf_material)
		rack.position = Vector3(MAIN_WIDTH + 1.0 + unit_width * (i + 0.5), 0, ShelfUnit.DEPTH / 2)
		add_child(rack)
	for i in 8:
		var rack := ShelfUnit.new()
		rack.build([], _shelf_material)
		rack.rotation.y = -PI / 2
		rack.position = Vector3(TOTAL_WIDTH - ShelfUnit.DEPTH / 2, 0, 2.5 + unit_width * (i + 0.5))
		add_child(rack)
	_add_solid(Vector3(2.0, 0.9, 1.0), Vector3(23.5, 0.45, 11.0), _fixture_material) # work table


func _build_lights() -> void:
	for x in [3.0, 8.0, 13.0, 18.0, 22.0, 26.0]:
		for z in [3.0, 7.0, 11.0]:
			var light := OmniLight3D.new()
			light.position = Vector3(x, CEILING_HEIGHT - 0.3, z)
			light.omni_range = 6.5
			light.light_energy = 1.2
			add_child(light)


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
