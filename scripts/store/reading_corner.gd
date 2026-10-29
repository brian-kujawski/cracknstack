class_name ReadingCorner
extends RefCounted
## The furniture of the reading corner on the left-hand wall: a leather
## armchair, a side table big enough for the radio and a book, and a floor
## lamp that adds a little warm light to that side of the room. The store
## places them (StoreBuilder._build_reading_corner); the radio is a ShopRadio.
##
## Each piece's origin is on the floor, centred under it, and its front faces
## local +Z. Each is a solid body, in the FURNITURE group so it can't be aimed
## at like a table top.

const FURNITURE := &"furniture"

## The armchair: width and depth, and the seat cushion's top.
const CHAIR_SIZE := Vector2(0.85, 0.9)
const CHAIR_HEIGHT := 1.02
const CHAIR_ARM := 0.16
const CHAIR_ARM_TOP := 0.66
const SEAT_HEIGHT := 0.49
const CHAIR_LEG := 0.09
## The side table: square top, at about the chair's arm height.
const TABLE_TOP := 0.65
const TABLE_HEIGHT := 0.6
## The floor lamp: its round base, and its shade, which spans SHADE_BOTTOM
## to LAMP_HEIGHT.
const LAMP_BASE := 0.32
const LAMP_HEIGHT := 1.73
const SHADE_BOTTOM := 1.43
const SHADE_RADII := Vector2(0.15, 0.23)
## The lamp's light: soft and all round, as through a cloth shade, and how
## brightly the shade itself glows.
const LAMP_ENERGY := 0.6
const LAMP_RANGE := 4.0
const SHADE_GLOW := 1.6


## An upholstered armchair: rolled arms, a seat and back cushion, a back
## leaning back a little, on four short wooden legs.
static func armchair(leather: Material, wood: Material) -> StaticBody3D:
	var body := _body()
	var w := CHAIR_SIZE.x
	var d := CHAIR_SIZE.y
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var leg := _add(body, _taper(0.024, 0.017, CHAIR_LEG), wood)
		leg.position = Vector3(corner.x * (w / 2 - 0.07), CHAIR_LEG / 2, corner.y * (d / 2 - 0.07))
	var base_top := CHAIR_LEG + 0.27
	_add(body, rounded_box(Vector3(w, base_top - CHAIR_LEG, d - 0.02), 0.03), leather).position.y = (CHAIR_LEG + base_top) / 2
	var arm_bottom := base_top - 0.06
	for side in [-1, 1]:
		var arm := _add(body, rounded_box(Vector3(CHAIR_ARM, CHAIR_ARM_TOP - arm_bottom, d - 0.03), 0.07), leather)
		arm.position = Vector3(side * (w / 2 - CHAIR_ARM / 2), (arm_bottom + CHAIR_ARM_TOP) / 2, 0.01)
	var back := _add(body, rounded_box(Vector3(w, CHAIR_HEIGHT - arm_bottom, 0.2), 0.07), leather)
	back.position = Vector3(0, (arm_bottom + CHAIR_HEIGHT) / 2, -d / 2 + 0.1)
	back.rotation.x = -0.1
	# The cushions fill the space between the arms, in front of the back.
	var inner := w - 2 * CHAIR_ARM - 0.01
	var seat_back := -d / 2 + 0.2
	var seat := _add(body, rounded_box(Vector3(inner, SEAT_HEIGHT - base_top + 0.01, d / 2 - seat_back), 0.045), leather)
	seat.position = Vector3(0, (base_top + SEAT_HEIGHT) / 2 - 0.005, (seat_back + d / 2) / 2)
	var cushion := _add(body, rounded_box(Vector3(inner, 0.48, 0.14), 0.05), leather)
	cushion.position = Vector3(0, SEAT_HEIGHT + 0.25, seat_back + 0.05)
	cushion.rotation.x = -0.2
	_shape(body, Vector3(w, CHAIR_ARM_TOP, d), Vector3(0, CHAIR_ARM_TOP / 2, 0))
	_shape(body, Vector3(w, CHAIR_HEIGHT, 0.25), Vector3(0, CHAIR_HEIGHT / 2, -d / 2 + 0.125))
	return body


## A square side table in the store's wood, like a small version of the work
## tables: a top with a softened edge, an apron, tapered legs, and a shelf
## low down. `leg_wood` is the wood mapped up the legs.
static func side_table(wood: StandardMaterial3D, leg_wood: Material) -> StaticBody3D:
	const TOP := 0.03
	const EDGE_STEP := 0.008
	const LEG_TOP := 0.045
	const LEG_FOOT := 0.034
	const LEG_INSET := 0.03
	const APRON := 0.07
	const SHELF_Y := 0.16
	var body := _body()
	var s := TABLE_TOP
	_add(body, _box(Vector3(s, TOP - EDGE_STEP, s)), wood).position.y = TABLE_HEIGHT - (TOP - EDGE_STEP) / 2
	_add(body, _box(Vector3(s - 2 * EDGE_STEP, EDGE_STEP, s - 2 * EDGE_STEP)), wood).position.y = TABLE_HEIGHT - TOP + EDGE_STEP / 2
	var leg_half := s / 2 - LEG_INSET - LEG_TOP / 2
	var leg_height := TABLE_HEIGHT - TOP
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var leg := _add(body, preload("res://scripts/store/store_builder.gd")._tapered_leg(LEG_TOP, LEG_FOOT, leg_height), leg_wood)
		leg.position = Vector3(corner.x * leg_half, 0, corner.y * leg_half)
	var rail := 2 * leg_half
	var rail_at := leg_half + LEG_TOP / 2 - 0.012
	for side in [-1, 1]:
		_add(body, _box(Vector3(rail, APRON, 0.018)), wood).position = Vector3(0, leg_height - APRON / 2, side * rail_at)
		_add(body, _box(Vector3(0.018, APRON, rail)), wood).position = Vector3(side * rail_at, leg_height - APRON / 2, 0)
	_add(body, _box(Vector3(rail + LEG_TOP - 0.01, 0.018, rail + LEG_TOP - 0.01)), wood).position.y = SHELF_Y
	_shape(body, Vector3(s, TABLE_HEIGHT, s), Vector3(0, TABLE_HEIGHT / 2, 0))
	return body


## A floor lamp: a brass stand on a round base under a cloth shade. The shade
## glows with the bulb inside it and lets its light through all round, softly:
## no bright cones out of the top and bottom. `light` is the store's lamp colour.
static func floor_lamp(brass: Material, shade_cloth: StandardMaterial3D, light: Color) -> StaticBody3D:
	var body := _body()
	_add(body, _taper(LAMP_BASE / 2 - 0.01, LAMP_BASE / 2, 0.025), brass).position.y = 0.0125
	_add(body, _taper(0.03, 0.06, 0.03), brass).position.y = 0.04
	var stem_top := SHADE_BOTTOM + 0.08
	_add(body, _taper(0.011, 0.011, stem_top - 0.05), brass).position.y = (stem_top + 0.05) / 2
	_add(body, _taper(0.02, 0.02, 0.05), brass).position.y = stem_top + 0.02

	var shade_height := LAMP_HEIGHT - SHADE_BOTTOM
	var shade_mesh := _taper(SHADE_RADII.x, SHADE_RADII.y, shade_height)
	shade_mesh.cap_top = false
	shade_mesh.cap_bottom = false
	var glow: StandardMaterial3D = shade_cloth.duplicate()
	glow.emission_enabled = true
	glow.emission = light
	glow.emission_energy_multiplier = SHADE_GLOW
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shade := _add(body, shade_mesh, glow)
	shade.position.y = SHADE_BOTTOM + shade_height / 2
	# The light comes through the cloth, so the shade mustn't block it.
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var lamp := OmniLight3D.new()
	lamp.position.y = SHADE_BOTTOM + 0.13
	lamp.light_color = light
	lamp.light_energy = LAMP_ENERGY
	lamp.omni_range = LAMP_RANGE
	lamp.omni_attenuation = 1.5
	lamp.shadow_enabled = true
	lamp.shadow_blur = 3.0
	lamp.shadow_normal_bias = 0.2
	body.add_child(lamp)

	_shape(body, Vector3(LAMP_BASE, 0.05, LAMP_BASE), Vector3(0, 0.025, 0))
	_shape(body, Vector3(0.05, SHADE_BOTTOM, 0.05), Vector3(0, SHADE_BOTTOM / 2, 0))
	_shape(body, Vector3(2 * SHADE_RADII.y, shade_height, 2 * SHADE_RADII.y), shade.position)
	return body


## A box with rounded edges and corners, `radius` round, centred on its
## origin. Its normals are the true rounded surface's, so it shades smoothly.
static func rounded_box(size: Vector3, radius: float) -> ArrayMesh:
	# Fine enough for a few rows of vertices round each edge.
	var cell := maxf(radius / 3, 0.006)
	var box := BoxMesh.new()
	box.size = size
	box.subdivide_width = ceili(size.x / cell)
	box.subdivide_height = ceili(size.y / cell)
	box.subdivide_depth = ceili(size.z / cell)
	var arrays := box.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var inner := (size / 2 - Vector3.ONE * radius).max(Vector3.ZERO)
	for i in vertices.size():
		var p := vertices[i]
		var core := p.clamp(-inner, inner)
		var out := p - core
		if out.length() > 0.0001:
			normals[i] = out.normalized()
			vertices[i] = core + normals[i] * radius
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A copy of a material, darker by `factor`.
static func tinted(material: StandardMaterial3D, factor: float) -> StandardMaterial3D:
	var copy: StandardMaterial3D = material.duplicate()
	var c := copy.albedo_color
	copy.albedo_color = Color(c.r * factor, c.g * factor, c.b * factor, c.a)
	return copy


static func _body() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.add_to_group(FURNITURE)
	return body


static func _add(body: Node3D, mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	body.add_child(instance)
	return instance


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


## A round post or disc, `top` and `bottom` its radii.
static func _taper(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 24
	return mesh


static func _shape(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)
