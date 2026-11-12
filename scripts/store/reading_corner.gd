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
const CHAIR_ARM_TOP := 0.66
const SEAT_HEIGHT := 0.49
const CHAIR_LEG := 0.09
const ARMCHAIR := preload("res://assets/models/armchair/armchair.glb")
## The side table: square top, at about the chair's arm height.
const TABLE_TOP := 0.65
const TABLE_HEIGHT := 0.6
## The floor lamp: its round base, and its shade, which spans SHADE_BOTTOM
## to LAMP_HEIGHT.
const LAMP_BASE := 0.32
const FLOOR_LAMP := preload("res://assets/models/floor_lamp/floor_lamp.glb")
const LAMP_HEIGHT := 1.58
const SHADE_BOTTOM := 1.3
const SHADE_RADII := Vector2(0.15, 0.23)
## The lamp's light: soft and all round, as through a cloth shade, and how
## brightly the shade itself glows.
const LAMP_ENERGY := 0.6
const LAMP_RANGE := 4.0
const SHADE_GLOW := 1.0
## The shade's parchment, and how many pleats it's folded into.
const SHADE_COLOUR := Color(0.95, 0.8, 0.58)
const SHADE_PLEATS := 40


## A tailored leather club chair from Kiln (assets/models/armchair): rolled
## arms faced with brass nailheads, a buttoned back raked a little, a firm
## seat cushion, on a walnut rail and four short turned legs. Built to
## CHAIR_SIZE, CHAIR_HEIGHT, SEAT_HEIGHT and CHAIR_ARM_TOP; solid as two
## boxes, the arms' height all over and the back to its full height.
static func armchair(leather: Material, wood: Material, brass: Material) -> StaticBody3D:
	var body := _body()
	var parts := KilnModel.parts(ARMCHAIR, ["Leather", "Wood", "Brass"])
	KilnModel.add(body, parts["Leather"], leather)
	KilnModel.add(body, parts["Wood"], wood)
	KilnModel.add(body, parts["Brass"], brass).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var w := CHAIR_SIZE.x
	var d := CHAIR_SIZE.y
	_shape(body, Vector3(w, CHAIR_ARM_TOP, d), Vector3(0, CHAIR_ARM_TOP / 2, 0))
	_shape(body, Vector3(w, CHAIR_HEIGHT, 0.25), Vector3(0, CHAIR_HEIGHT / 2, -d / 2 + 0.125))
	return body


## A square side table in the store's wood, like a small version of the work
## tables: a top with a softened edge, an apron, fluted legs in brass foot
## caps (Furniture.leg), and a shelf low down.
static func side_table(wood: StandardMaterial3D, brass: Material) -> StaticBody3D:
	const TOP := 0.03
	const EDGE_STEP := 0.008
	const LEG_TOP := 0.05
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
		Furniture.leg(body, Vector3(corner.x * leg_half, 0, corner.y * leg_half), LEG_TOP, leg_height, wood, brass)
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
	# The stepped base, turned stem and finial come from Kiln
	# (assets/models/floor_lamp), built to these heights.
	var parts := KilnModel.parts(FLOOR_LAMP, ["Base", "Stem", "Finial"])
	for part in ["Base", "Stem", "Finial"]:
		KilnModel.add(body, parts[part], brass)

	var shade_height := LAMP_HEIGHT - SHADE_BOTTOM
	# A pleated parchment shade, lit from inside: it glows a warm amber rather
	# than white, with a thin brass rim round its top and bottom.
	var glow: StandardMaterial3D = shade_cloth.duplicate()
	glow.albedo_color = SHADE_COLOUR
	glow.emission_enabled = true
	glow.emission = SHADE_COLOUR * light
	glow.emission_energy_multiplier = SHADE_GLOW
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shade := _add(body, pleated_shade(SHADE_RADII.x, SHADE_RADII.y, shade_height, SHADE_PLEATS), glow)
	shade.position.y = SHADE_BOTTOM + shade_height / 2
	# The light comes through the cloth, so the shade mustn't block it.
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for rim in [[SHADE_RADII.y, SHADE_BOTTOM], [SHADE_RADII.x, LAMP_HEIGHT]]:
		var ring := TorusMesh.new()
		ring.inner_radius = rim[0] - 0.002
		ring.outer_radius = rim[0] + 0.004
		ring.rings = 48
		ring.ring_segments = 6
		var band := _add(body, ring, brass)
		band.position.y = rim[1]
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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


## A lamp shade `height` tall, `top` and `bottom` round, centred on its
## origin, open at both ends: the cloth folded into `pleats` sharp pleats.
static func pleated_shade(top: float, bottom: float, height: float, pleats: int) -> ArrayMesh:
	const DEPTH := 0.007
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0xFFFFFFFF)  # Flat faces, so each fold catches light.
	var steps := pleats * 2
	var ring := func(i: int, radius: float, y: float) -> Vector3:
		var r := radius - (DEPTH if i % 2 == 1 else 0.0)
		var a := TAU * i / steps
		return Vector3(cos(a) * r, y, sin(a) * r)
	for i in steps:
		var b0: Vector3 = ring.call(i, bottom, -height / 2)
		var b1: Vector3 = ring.call(i + 1, bottom, -height / 2)
		var t0: Vector3 = ring.call(i, top, height / 2)
		var t1: Vector3 = ring.call(i + 1, top, height / 2)
		for v in [b0, t0, t1, b0, t1, b1]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


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
static func _shape(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)
