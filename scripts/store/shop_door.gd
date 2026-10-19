class_name ShopDoor
extends StaticBody3D
## The shop's front door (closed, not usable yet): a clear-anodised storefront
## door in a fixed frame, one big glass panel, a push bar across it for
## getting out, a closer on top, and the glass mostly papered over with
## letter-size flyers taped up from the inside. Its origin is on the floor at
## the middle of the doorway, against the wall, and it faces local +Z.
##
## Each flyer is its own mesh with its own material. A picture saved as
## FLYER_DIR/flyer_NN.png (or .jpg/.webp), numbered like FLYERS from 01,
## shows on that flyer; until then it's blank coloured paper.

## The door leaf, and the frame's width around it (jambs and head).
const LEAF_SIZE := Vector2(1.0, 2.1)
const FRAME_WIDTH := 0.05
const FRAME_DEPTH := 0.1
const HEAD_HEIGHT := 0.1
const THRESHOLD := 0.012
const LEAF_DEPTH := 0.045
## The leaf's front face (toward the room) sits this far out from the wall.
const LEAF_FRONT := 0.075
const STILE := 0.11
const TOP_RAIL := 0.11
const BOTTOM_RAIL := 0.25
const GLASS_THICKNESS := 0.006
## The push bar's height (centre) and how far it stands off the leaf.
const BAR_HEIGHT := 1.0
const BAR_STANDOFF := 0.06
## The hinges are on this side of the leaf (local x).
const HINGE_SIDE := 1.0
const FLYER_DIR := "res://assets/store/door/flyers/"
## US letter, portrait.
const LETTER := Vector2(0.216, 0.279)
## Each flyer: its centre on the glass (x across, y up, from the doorway's
## middle at the floor), whether it's turned landscape, and its paper colour.
## Later entries are taped over earlier ones where they overlap.
const FLYERS := [
	[Vector2(-0.27, 1.855), false, Color(0.96, 0.95, 0.9)],
	[Vector2(0.0, 1.865), false, Color(0.97, 0.82, 0.84)],
	[Vector2(0.27, 1.847), false, Color(0.92, 0.86, 0.96)],
	[Vector2(-0.25, 1.595), true, Color(0.82, 0.9, 0.97)],
	[Vector2(0.03, 1.578), true, Color(0.98, 0.9, 0.72)],
	[Vector2(0.28, 1.597), false, Color(0.98, 0.92, 0.62)],
	[Vector2(-0.28, 1.315), false, Color(0.84, 0.94, 0.82)],
	[Vector2(-0.03, 1.31), false, Color(0.96, 0.95, 0.9)],
	[Vector2(0.24, 1.325), false, Color(0.97, 0.82, 0.84)],
	[Vector2(-0.28, 1.045), false, Color(0.92, 0.86, 0.96)],
	[Vector2(-0.03, 1.055), true, Color(0.82, 0.9, 0.97)],
	[Vector2(0.25, 1.037), true, Color(0.98, 0.9, 0.72)],
	[Vector2(-0.26, 0.775), false, Color(0.98, 0.92, 0.62)],
	[Vector2(0.005, 0.758), false, Color(0.84, 0.94, 0.82)],
	[Vector2(-0.25, 0.507), true, Color(0.96, 0.95, 0.9)],
	[Vector2(0.03, 0.5), true, Color(0.97, 0.82, 0.84)],
	[Vector2(0.28, 0.495), false, Color(0.92, 0.86, 0.96)],
]

## Every flyer's material, in FLYERS order, for swapping pictures in code.
var flyer_materials: Array[StandardMaterial3D] = []


## Builds the meshes and collision. Call once before adding to the tree.
func build() -> void:
	var metal := _metal(Color(0.6, 0.61, 0.6), 0.4)
	var steel := _metal(Color(0.78, 0.78, 0.76), 0.3)
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.06, 0.06, 0.06)
	rubber.roughness = 0.8
	var half := LEAF_SIZE.x / 2
	var top := LEAF_SIZE.y

	# The fixed frame: two jambs, a head and a low threshold on the floor.
	for side in [-1, 1]:
		_box(Vector3(FRAME_WIDTH, top + HEAD_HEIGHT, FRAME_DEPTH), Vector3(side * (half + FRAME_WIDTH / 2), (top + HEAD_HEIGHT) / 2, FRAME_DEPTH / 2), metal)
	_box(Vector3(LEAF_SIZE.x + 2 * FRAME_WIDTH, HEAD_HEIGHT, FRAME_DEPTH), Vector3(0, top + HEAD_HEIGHT / 2, FRAME_DEPTH / 2), metal)
	_box(Vector3(LEAF_SIZE.x, THRESHOLD, 0.12), Vector3(0, THRESHOLD / 2, 0.06), metal)

	# The leaf: stiles and rails round one sheet of glass, held in by stops.
	var leaf_z := LEAF_FRONT - LEAF_DEPTH / 2
	var bottom := THRESHOLD + 0.003
	var glass_bottom := bottom + BOTTOM_RAIL
	var glass_top := top - TOP_RAIL
	var glass_half := half - STILE
	for side in [-1, 1]:
		_box(Vector3(STILE, top - bottom, LEAF_DEPTH), Vector3(side * (half - STILE / 2), (top + bottom) / 2, leaf_z), metal)
	_box(Vector3(2 * glass_half, TOP_RAIL, LEAF_DEPTH), Vector3(0, top - TOP_RAIL / 2, leaf_z), metal)
	_box(Vector3(2 * glass_half, BOTTOM_RAIL, LEAF_DEPTH), Vector3(0, bottom + BOTTOM_RAIL / 2, leaf_z), metal)
	const STOP := 0.016
	var stop_z := leaf_z + GLASS_THICKNESS / 2 + 0.006
	for side in [-1, 1]:
		_box(Vector3(STOP, glass_top - glass_bottom, 0.012), Vector3(side * (glass_half - STOP / 2), (glass_top + glass_bottom) / 2, stop_z), metal)
		_box(Vector3(2 * glass_half, STOP, 0.012), Vector3(0, (glass_top + glass_bottom) / 2 + side * ((glass_top - glass_bottom) / 2 - STOP / 2), stop_z), metal)
	var glass := _box(Vector3(2 * glass_half, glass_top - glass_bottom, GLASS_THICKNESS), Vector3(0, (glass_top + glass_bottom) / 2, leaf_z), _glass())
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Hinge knuckles on the hinge edge.
	for y in [0.3, 1.05, 1.8]:
		_cylinder(0.011, 0.11, Vector3(HINGE_SIDE * half, y, LEAF_FRONT - 0.004), steel)

	_build_push_bar(steel, rubber)
	_build_closer(metal, steel)
	_build_flyers(Vector2(glass_half, glass_top), leaf_z + GLASS_THICKNESS / 2)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(LEAF_SIZE.x + 2 * FRAME_WIDTH, top + HEAD_HEIGHT, FRAME_DEPTH)
	shape.shape = box
	shape.position = Vector3(0, box.size.y / 2, FRAME_DEPTH / 2)
	add_child(shape)


## The floor footprint (x across, z out from the wall), in local metres.
static func footprint() -> Rect2:
	return Rect2(-LEAF_SIZE.x / 2 - FRAME_WIDTH, 0, LEAF_SIZE.x + 2 * FRAME_WIDTH, 0.12)


## A panic bar: a mechanism case on the latch side, a bracket by the hinges,
## and a round push rail between them with a black touch strip.
func _build_push_bar(steel: Material, rubber: Material) -> void:
	var half := LEAF_SIZE.x / 2
	var latch := -HINGE_SIDE
	var face := LEAF_FRONT
	const CASE := Vector3(0.17, 0.085, 0.07)
	const BRACKET := Vector3(0.05, 0.085, 0.07)
	var case_x := latch * (half - 0.03 - CASE.x / 2)
	var bracket_x := HINGE_SIDE * (half - 0.04 - BRACKET.x / 2)
	# Each end housing has a black cover plate on its face.
	for part in [[CASE, case_x], [BRACKET, bracket_x]]:
		var size: Vector3 = part[0]
		_box(size, Vector3(part[1], BAR_HEIGHT, face + size.z / 2), steel)
		_box(Vector3(size.x - 0.01, size.y - 0.01, 0.004), Vector3(part[1], BAR_HEIGHT, face + size.z + 0.002), rubber)
	var rail_from := case_x + latch * -CASE.x / 2
	var rail_to := bracket_x - HINGE_SIDE * BRACKET.x / 2
	var rail_length := absf(rail_to - rail_from)
	var rail_mid := (rail_from + rail_to) / 2
	var rail_z := face + BAR_STANDOFF
	var rail := _cylinder(0.024, rail_length, Vector3(rail_mid, BAR_HEIGHT, rail_z - 0.01), steel)
	rail.rotation.z = PI / 2
	rail.scale = Vector3(1, 1, 0.75)
	_box(Vector3(rail_length * 0.7, 0.018, 0.004), Vector3(rail_mid, BAR_HEIGHT, rail_z + 0.009), rubber)
	# The rail's arms back to the leaf at each end.
	for x in [rail_from + HINGE_SIDE * 0.03, rail_to - HINGE_SIDE * 0.03]:
		_box(Vector3(0.02, 0.03, BAR_STANDOFF - 0.01), Vector3(x, BAR_HEIGHT, face + (BAR_STANDOFF - 0.01) / 2), steel)


## An overhead closer on the top rail by the hinges, its arm folded up to a
## shoe on the frame head.
func _build_closer(metal: Material, steel: Material) -> void:
	var half := LEAF_SIZE.x / 2
	var y := LEAF_SIZE.y - TOP_RAIL / 2
	var body_x := HINGE_SIDE * (half - 0.08 - 0.13)
	_box(Vector3(0.26, 0.055, 0.05), Vector3(body_x, y, LEAF_FRONT + 0.025), metal)
	_cylinder(0.012, 0.02, Vector3(body_x + HINGE_SIDE * 0.1, y, LEAF_FRONT + 0.06), steel).rotation.x = PI / 2
	var head_y := LEAF_SIZE.y + HEAD_HEIGHT / 2
	var shoe_x := body_x - HINGE_SIDE * 0.16
	_box(Vector3(0.06, 0.04, 0.02), Vector3(shoe_x, head_y, FRAME_DEPTH + 0.01), metal)
	# Two arm links: pivot to elbow, elbow to shoe.
	var pivot := Vector3(body_x + HINGE_SIDE * 0.1, y, LEAF_FRONT + 0.07)
	var elbow := Vector3(body_x + HINGE_SIDE * 0.02, head_y - 0.01, LEAF_FRONT + 0.07)
	var shoe := Vector3(shoe_x, head_y, FRAME_DEPTH + 0.025)
	for link in [[pivot, elbow], [elbow, shoe]]:
		var from: Vector3 = link[0]
		var to: Vector3 = link[1]
		var arm := _box(Vector3(from.distance_to(to), 0.014, 0.006), (from + to) / 2, steel)
		arm.rotation.z = atan2(to.y - from.y, to.x - from.x)


## The flyers, taped to the inside of the glass a little crooked. `glass` is
## the glass's half width and top edge; `z` its inside face.
func _build_flyers(glass: Vector2, z: float) -> void:
	var tape := StandardMaterial3D.new()
	tape.albedo_color = Color(0.95, 0.93, 0.85, 0.55)
	tape.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tape.roughness = 0.4
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for i in FLYERS.size():
		var entry: Array = FLYERS[i]
		var size: Vector2 = Vector2(LETTER.y, LETTER.x) if entry[1] else LETTER
		var centre: Vector2 = entry[0]
		# Keep each sheet on the glass.
		centre.x = clampf(centre.x, -glass.x + size.x / 2, glass.x - size.x / 2)
		centre.y = minf(centre.y, glass.y - size.y / 2 - 0.01)
		var material := StandardMaterial3D.new()
		material.albedo_color = entry[2]
		material.roughness = 0.85
		var picture := flyer_texture(i)
		if picture:
			material.albedo_texture = picture
			material.albedo_color = Color.WHITE
		flyer_materials.append(material)
		var mesh := QuadMesh.new()
		mesh.size = size
		var flyer := MeshInstance3D.new()
		flyer.name = "Flyer%02d" % (i + 1)
		flyer.mesh = mesh
		flyer.material_override = material
		# Each sheet sits a hair in front of the ones it overlaps.
		flyer.position = Vector3(centre.x, centre.y, z + 0.0008 + i * 0.0003)
		flyer.rotation.z = deg_to_rad(rng.randf_range(-2.5, 2.5))
		add_child(flyer)
		# Two strips of tape across the top corners, sometimes the bottom too.
		var corners := [Vector2(-1, 1), Vector2(1, 1)]
		if rng.randf() < 0.4:
			corners += [Vector2(-1, -1), Vector2(1, -1)]
		for corner in corners:
			var strip := MeshInstance3D.new()
			var strip_mesh := QuadMesh.new()
			strip_mesh.size = Vector2(0.05, 0.018)
			strip.mesh = strip_mesh
			strip.material_override = tape
			strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			strip.position = Vector3(corner.x * (size.x / 2 - 0.008), corner.y * (size.y / 2 - 0.008), 0.0004)
			strip.rotation.z = -corner.x * corner.y * PI / 4 + deg_to_rad(rng.randf_range(-8, 8))
			flyer.add_child(strip)


## The picture for flyer `index` (0-based) if one has been added, else null.
static func flyer_texture(index: int) -> Texture2D:
	for extension in ["png", "jpg", "webp"]:
		var path := "%sflyer_%02d.%s" % [FLYER_DIR, index + 1, extension]
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _box(size: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	add_child(instance)
	return instance


func _cylinder(radius: float, height: float, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	add_child(instance)
	return instance


static func _glass() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.8, 0.8, 0.18)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.05
	material.metallic_specular = 0.8
	return material


static func _metal(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.5
	material.roughness = roughness
	return material
