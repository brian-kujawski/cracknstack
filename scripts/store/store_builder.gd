extends Node3D
## Builds the graybox store: one small room, cluttered on purpose. A closed
## door in the front wall, one wall-length binder shelf on the back wall, and
## four work tables in the middle for setting binders down and stacking cards.
## On the right-hand wall (seen from the door) stand two glass display
## cabinets for the rare cards; the left wall is open for store dressing later.
##
## Everything is plain boxes so the layout is cheap to change. Coordinates are
## metres: x runs 0..WIDTH left to right as you face the back wall, z runs from
## the back wall (0) to the front wall (DEPTH), y is up.

const WIDTH := 12.0
const DEPTH := 8.0
const CEILING_HEIGHT := 3.0
const WALL_THICKNESS := 0.2
## The binder shelf's x range along the back wall. Binders read left to
## right, top shelf first, so the shelf reads the timeline like a book.
const BACK_SHELF := Vector2(2.0, 10.0)
const TABLE_SIZE := Vector3(1.3, 1.0, 1.3)
const TABLE_CENTERS := [Vector2(4.6, 2.9), Vector2(7.4, 2.9), Vector2(4.6, 5.3), Vector2(7.4, 5.3)]
## How far past a table's edge a standing player can step, so that with no
## body drawn it looks like leaning over the table. It gets the eyes, and the
## held card, far enough under the pendant for its light to reach the card.
const TABLE_LEAN := 0.45
## Table tops (and their aprons) are in this group. The player passes through
## them and is stopped by a smaller block on LEAN_STOP_LAYER instead.
const TABLE_TOPS := &"table_tops"
## Collision layer only the player collides with: the block under each table
## top that stops a lean, set high enough that crouching still gets you under.
const LEAN_STOP_LAYER := 16
## Windows on the front wall, either side of the door: centres along x, and
## the opening's size and sill height.
const WINDOW_XS := [2.9, 9.1]
const WINDOW_SIZE := Vector2(1.8, 1.5)
const WINDOW_SILL := 0.9
## Pendant shades hang this high (their rim), about 1.3 m over the tables:
## high enough that each lamp lights the floor past its table's edge, so
## the table shadows don't meet in a dark seam between neighbouring tables.
const PENDANT_HEIGHT := 2.3
## The shelf's track light: how far out from the back wall it runs, and how
## many spotlights are on it.
const TRACK_Z := 1.15
const TRACK_HEADS := 7
const FIXTURE_LIGHT := Color(1.0, 0.82, 0.6)
## The display cabinets stand against the right-hand wall (x = WIDTH), facing
## into the room, centred at these z, back one first. They line up with the
## table rows.
const CABINET_ZS := [2.9, 5.3]
## The tables' and cabinets' wood (assets/store/table_wood), and how many
## metres of real wood one copy of its texture covers.
const TABLE_WOOD := "table_wood"
const TABLE_WOOD_SIZE := 0.6
## The shelving's and window frames' wood (assets/store/shelf_wood), and
## how many metres one copy of it covers.
const SHELF_WOOD := "shelf_wood"
const SHELF_WOOD_SIZE := 0.8
## The green baize on the tables' playing surface and lining the cabinets'
## backs (assets/store/felt), and how many metres one copy of it covers.
const FELT := "felt"
const FELT_SIZE := 0.3
## The shop's carpet (assets/store/carpet), and how many metres one copy
## of it covers.
const CARPET := "carpet"
const CARPET_SIZE := 0.5
## Painted plaster on the walls and ceiling (assets/store/plaster), and how
## many metres one copy of it covers.
const PLASTER := "plaster"
const PLASTER_SIZE := 2.0

## Floor footprints nothing on the floor may overlap (the shelves and the
## table legs), as x/z rectangles. The space under a table top is open:
## cards can end up underneath.
var obstacles: Array[Rect2] = []
## For the DayCycle: the light from each window, the curtains, and the sky
## seen between them.
var window_lights: Array[Light3D] = []
var curtain_material := _material(Color(0.86, 0.8, 0.68))
var sky_material := StandardMaterial3D.new()
## Every shadow box in the display cabinets, back cabinet first, each
## cabinet's top row first, left to right as you face it.
var display_slots: Array[Marker3D] = []

var _wall_material := _textured(PLASTER, PLASTER_SIZE)
var _floor_material := _textured(CARPET, CARPET_SIZE)
var _shelf_material := _textured(SHELF_WOOD, SHELF_WOOD_SIZE)
var _table_material := _textured(TABLE_WOOD, TABLE_WOOD_SIZE)
## The same wood for the legs, mapped by the legs' own UVs so the grain runs
## up them (world mapping would lay it across, like the top's).
var _leg_material := _by_uv(_table_material)
var _felt_material := _textured(FELT, FELT_SIZE)
var _fixture_material := _metal(Color(0.12, 0.13, 0.12), 0.45)
var _brass_material := _metal(Color(0.75, 0.6, 0.35), 0.35)


## The floor area cards can land on, inset a little from the walls.
func floor_bounds() -> Rect2:
	return Rect2(0.05, 0.05, WIDTH - 0.1, DEPTH - 0.1)


func _ready() -> void:
	_build_shell()
	_build_binder_shelves()
	_build_tables()
	_build_display_cabinets()
	_build_windows()
	_build_door()
	_build_pendants()
	_build_track_light()


func _build_shell() -> void:
	var half := WALL_THICKNESS / 2
	_add_solid(Vector3(WIDTH, 0.2, DEPTH), Vector3(WIDTH / 2, -0.1, DEPTH / 2), _floor_material)
	_add_solid(Vector3(WIDTH, 0.2, DEPTH), Vector3(WIDTH / 2, CEILING_HEIGHT + 0.1, DEPTH / 2), _wall_material)
	_add_wall_x(0.0, WIDTH, -half)
	_add_wall_x(0.0, WIDTH, DEPTH + half)
	_add_wall_z(-half, 0.0, DEPTH)
	_add_wall_z(WIDTH + half, 0.0, DEPTH)


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
	# The top and apron are their own body, so the player can lean over them.
	var top := StaticBody3D.new()
	top.add_to_group(TABLE_TOPS)
	body.add_child(top)

	_add_part(top, Vector3(size.x, TOP - EDGE_STEP, size.y), Vector3(0, top_y - (TOP - EDGE_STEP) / 2, 0), _table_material, true)
	_add_part(top, Vector3(size.x - 2 * EDGE_STEP, EDGE_STEP, size.y - 2 * EDGE_STEP),
		Vector3(0, top_y - TOP + EDGE_STEP / 2, 0), _table_material, true)
	_add_part(top, Vector3(size.x - 2 * FELT_BORDER, 0.001, size.y - 2 * FELT_BORDER),
		Vector3(0, top_y + 0.0005, 0), _felt_material, false)

	var leg_half := size / 2 - Vector2.ONE * (LEG_INSET + LEG_TOP / 2)
	var leg_height := top_y - TOP
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at: Vector2 = corner * leg_half
		var leg := MeshInstance3D.new()
		leg.mesh = _tapered_leg(LEG_TOP, LEG_FOOT, leg_height)
		leg.material_override = _leg_material
		leg.position = Vector3(at.x, 0, at.y)
		body.add_child(leg)
		_add_shape(body, Vector3(LEG_TOP, leg_height, LEG_TOP), Vector3(at.x, leg_height / 2, at.y))
		var world := center + at
		obstacles.append(Rect2(world - Vector2.ONE * LEG_TOP / 2, Vector2.ONE * LEG_TOP))

	# Apron rails between the legs, set a little back from the legs' faces.
	var apron_y := top_y - TOP - APRON_HEIGHT / 2
	var rail_offset := leg_half + Vector2.ONE * (LEG_TOP / 2 - APRON_THICKNESS / 2 - 0.008)
	for side in [-1, 1]:
		_add_part(top, Vector3(2 * leg_half.x, APRON_HEIGHT, APRON_THICKNESS), Vector3(0, apron_y, side * rail_offset.y), _table_material, true)
		_add_part(top, Vector3(APRON_THICKNESS, APRON_HEIGHT, 2 * leg_half.y), Vector3(side * rail_offset.x, apron_y, 0), _table_material, true)

	# What stops a lean: TABLE_LEAN in from the edge, under the top, and above
	# a crouched body so you can still crawl underneath.
	const LEAN_STOP_BOTTOM := 0.65
	var lean_stop := StaticBody3D.new()
	lean_stop.collision_layer = LEAN_STOP_LAYER
	lean_stop.collision_mask = 0
	body.add_child(lean_stop)
	var stop_height := top_y - TOP - LEAN_STOP_BOTTOM
	_add_shape(lean_stop, Vector3(size.x - 2 * TABLE_LEAN, stop_height, size.y - 2 * TABLE_LEAN), Vector3(0, LEAN_STOP_BOTTOM + stop_height / 2, 0))


## A square leg standing on the floor, `top` wide under the table and
## narrowing to `foot` at the floor. Its UVs are in TABLE_WOOD_SIZE units,
## with u running up the leg, so the wood's grain does too.
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
		var uvs := [Vector2(0, 0), Vector2(0, foot), Vector2(height, top), Vector2(height, 0)]
		var corners_3d := [a0, b0, b1, a1]
		# Clockwise seen from outside (Godot's front faces).
		for j in [0, 1, 2, 0, 2, 3]:
			tool.set_uv(uvs[j] / TABLE_WOOD_SIZE)
			tool.add_vertex(corners_3d[j])
	tool.generate_normals()
	tool.generate_tangents()
	return tool.commit()


func _add_part(body: Node3D, size: Vector3, center: Vector3, material: Material, solid: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	body.add_child(instance)
	if solid:
		_add_shape(body as StaticBody3D, size, center)


func _add_shape(body: StaticBody3D, size: Vector3, center: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)


## Two oak and glass display cabinets on the right-hand wall, their backs to
## the wall, holding an empty shadow box for each rare card.
func _build_display_cabinets() -> void:
	for i in CABINET_ZS.size():
		var cabinet := DisplayCabinet.new()
		cabinet.name = "DisplayCabinet%d" % (i + 1)
		cabinet.build(_table_material, _felt_material, FIXTURE_LIGHT)
		cabinet.position = Vector3(WIDTH - DisplayCabinet.DEPTH / 2, 0, CABINET_ZS[i])
		cabinet.rotation.y = -PI / 2
		add_child(cabinet)
		display_slots.append_array(cabinet.slots)
		# Turned a quarter, the footprint's across becomes z and its out-from-the-wall -x.
		var footprint := DisplayCabinet.footprint()
		obstacles.append(Rect2(Vector2(WIDTH - DisplayCabinet.DEPTH / 2 - footprint.end.y, CABINET_ZS[i] + footprint.position.x),
			Vector2(footprint.size.y, footprint.size.x)))


## Each window is a framed opening with a deep sill, the sky behind it, and
## two curtains drawn nearly closed on a rod, so daylight comes in diffuse.
func _build_windows() -> void:
	const FRAME := 0.07
	const FRAME_DEPTH := 0.06
	const CURTAIN_Z := 0.13
	sky_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_material.albedo_color = Color.BLACK
	curtain_material.emission_enabled = true
	curtain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var size: Vector2 = WINDOW_SIZE
	for x in WINDOW_XS:
		var mid_y := WINDOW_SILL + size.y / 2
		_add_part(self, Vector3(size.x, size.y, 0.01), Vector3(x, mid_y, DEPTH - 0.005), sky_material, false)
		# Frame: head, jambs, a cross bar, and a sill that sticks out.
		var frame_z := DEPTH - FRAME_DEPTH / 2
		for side in [-1, 1]:
			_add_part(self, Vector3(FRAME, size.y + 2 * FRAME, FRAME_DEPTH), Vector3(x + side * (size.x + FRAME) / 2, mid_y, frame_z), _shelf_material, false)
		_add_part(self, Vector3(size.x + 2 * FRAME, FRAME, FRAME_DEPTH), Vector3(x, WINDOW_SILL + size.y + FRAME / 2, frame_z), _shelf_material, false)
		_add_part(self, Vector3(size.x, FRAME * 0.6, FRAME_DEPTH * 0.6), Vector3(x, mid_y, DEPTH - FRAME_DEPTH * 0.3), _shelf_material, false)
		_add_part(self, Vector3(size.x + 2 * FRAME + 0.06, 0.04, 0.16), Vector3(x, WINDOW_SILL - 0.02, DEPTH - 0.08), _shelf_material, false)
		# Curtains drawn to within a hand's width of each other.
		var rod_y := WINDOW_SILL + size.y + FRAME + 0.08
		var rod := MeshInstance3D.new()
		var rod_mesh := CylinderMesh.new()
		rod_mesh.top_radius = 0.012
		rod_mesh.bottom_radius = 0.012
		rod_mesh.height = size.x + 0.5
		rod.mesh = rod_mesh
		rod.material_override = _brass_material
		rod.rotation.z = PI / 2
		rod.position = Vector3(x, rod_y, DEPTH - CURTAIN_Z)
		add_child(rod)
		var curtain_width := size.x / 2 + 0.2
		# The curtains stop just clear of the sill.
		var drop := rod_y - (WINDOW_SILL + 0.025)
		for side in [-1, 1]:
			var curtain := MeshInstance3D.new()
			curtain.mesh = _curtain_mesh(curtain_width, drop)
			curtain.material_override = curtain_material
			curtain.position = Vector3(x + side * (curtain_width / 2 + 0.05), rod_y, DEPTH - CURTAIN_Z)
			add_child(curtain)
		# Soft daylight into the room, no shadows (the curtains diffuse it).
		var light := SpotLight3D.new()
		light.position = Vector3(x, mid_y + 0.3, DEPTH - 0.3)
		light.rotation.x = deg_to_rad(-12)
		light.spot_angle = 60.0
		light.spot_range = 9.0
		light.spot_attenuation = 0.8
		light.light_specular = 0.2
		add_child(light)
		window_lights.append(light)


## The shop door, centred on the front wall and facing into the room.
func _build_door() -> void:
	var door := ShopDoor.new()
	door.name = "ShopDoor"
	door.build()
	door.position = Vector3(WIDTH / 2, 0, DEPTH)
	door.rotation.y = PI
	add_child(door)
	var footprint := ShopDoor.footprint()
	obstacles.append(Rect2(Vector2(WIDTH / 2 + footprint.position.x, DEPTH - footprint.end.y), footprint.size))


## A pleated curtain hanging from its top edge (origin at the top centre).
static func _curtain_mesh(width: float, drop: float) -> ArrayMesh:
	const PLEAT := 0.11
	const DEPTH_OF_PLEAT := 0.035
	const STEPS := 40
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in STEPS:
		var x0 := -width / 2 + width * i / STEPS
		var x1 := -width / 2 + width * (i + 1) / STEPS
		var z0 := DEPTH_OF_PLEAT / 2 * sin(TAU * x0 / PLEAT)
		var z1 := DEPTH_OF_PLEAT / 2 * sin(TAU * x1 / PLEAT)
		var a := Vector3(x0, 0, z0)
		var b := Vector3(x1, 0, z1)
		var c := Vector3(x1, -drop, z1)
		var d := Vector3(x0, -drop, z0)
		for v in [a, b, c, a, c, d]:
			tool.add_vertex(v)
	tool.generate_normals()
	return tool.commit()


## A pendant over each table: a ceiling canopy, a cord, and a deep enamel
## shade with a warm downlight that pools on the felt and spills onto the
## floor round the table.
func _build_pendants() -> void:
	var bulb_material := StandardMaterial3D.new()
	bulb_material.emission_enabled = true
	bulb_material.emission = FIXTURE_LIGHT
	bulb_material.emission_energy_multiplier = 4.0
	bulb_material.albedo_color = Color(1, 0.95, 0.85)
	var inside_material := _material(Color(0.95, 0.92, 0.85))
	inside_material.cull_mode = BaseMaterial3D.CULL_FRONT
	for center in TABLE_CENTERS:
		var at := Vector3(center.x, 0, center.y)
		_add_cylinder(Vector3(at.x, CEILING_HEIGHT - 0.015, at.z), 0.06, 0.06, 0.03, _fixture_material)
		var cord_top := CEILING_HEIGHT - 0.03
		var shade_top := PENDANT_HEIGHT + 0.2
		_add_cylinder(Vector3(at.x, (cord_top + shade_top) / 2, at.z), 0.004, 0.004, cord_top - shade_top, _fixture_material)
		# The shade: a short neck flaring to a wide rim, painted inside.
		_add_cylinder(Vector3(at.x, shade_top - 0.03, at.z), 0.03, 0.03, 0.06, _fixture_material)
		var shade := _add_cylinder(Vector3(at.x, PENDANT_HEIGHT + 0.07, at.z), 0.05, 0.23, 0.14, _fixture_material, self, true)
		_add_cylinder(Vector3(at.x, PENDANT_HEIGHT + 0.07, at.z), 0.048, 0.228, 0.14, inside_material, self, true)
		# The bulb sits inside, so the shade's inner faces must block light too.
		shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		var bulb := MeshInstance3D.new()
		var bulb_mesh := SphereMesh.new()
		bulb_mesh.radius = 0.04
		bulb_mesh.height = 0.08
		bulb.mesh = bulb_mesh
		bulb.material_override = bulb_material
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bulb.position = Vector3(at.x, PENDANT_HEIGHT + 0.09, at.z)
		add_child(bulb)
		var light := SpotLight3D.new()
		light.position = Vector3(at.x, PENDANT_HEIGHT + 0.05, at.z)
		light.rotation.x = -PI / 2
		light.light_color = FIXTURE_LIGHT
		light.light_energy = 1.4
		light.spot_angle = 50.0
		light.spot_range = 4.5
		light.spot_attenuation = 1.2
		light.shadow_enabled = true
		light.shadow_blur = 2.0
		add_child(light)
		# Lights the inside of the shade and fades out on its way to the table:
		# a stand-in for bounce light. It casts shadows so the shade blocks it
		# from the ceiling; its short range means only the lamp is in its map.
		var fill := OmniLight3D.new()
		fill.position = Vector3(at.x, PENDANT_HEIGHT + 0.06, at.z)
		fill.light_color = FIXTURE_LIGHT
		fill.light_energy = 0.3
		fill.omni_range = 1.3
		fill.omni_attenuation = 2.0
		fill.shadow_enabled = true
		fill.shadow_normal_bias = 0.2
		add_child(fill)


## A ceiling track along the shelf with spotlights angled at its face, so
## the labels and spines read clearly. No shadows: it's there to light faces.
func _build_track_light() -> void:
	var length: float = BACK_SHELF.y - BACK_SHELF.x
	var track_y := CEILING_HEIGHT - 0.02
	_add_part(self, Vector3(length, 0.03, 0.035), Vector3((BACK_SHELF.x + BACK_SHELF.y) / 2, track_y, TRACK_Z), _fixture_material, false)
	var lens_material := StandardMaterial3D.new()
	lens_material.emission_enabled = true
	lens_material.emission = FIXTURE_LIGHT
	lens_material.emission_energy_multiplier = 3.0
	var target_y := 1.15
	var target_z := ShelfUnit.DEPTH
	for i in TRACK_HEADS:
		var x: float = BACK_SHELF.x + length * (i + 0.5) / TRACK_HEADS
		_add_cylinder(Vector3(x, track_y - 0.05, TRACK_Z), 0.008, 0.008, 0.08, _fixture_material)
		var head := Node3D.new()
		head.position = Vector3(x, track_y - 0.1, TRACK_Z)
		add_child(head)
		head.look_at(Vector3(x, target_y, target_z), Vector3.UP)
		var can := _add_cylinder(Vector3.ZERO, 0.035, 0.035, 0.13, _fixture_material, head)
		can.rotation.x = PI / 2
		var lens := _add_cylinder(Vector3(0, 0, -0.066), 0.03, 0.03, 0.002, lens_material, head)
		lens.rotation.x = PI / 2
		var light := SpotLight3D.new()
		light.light_color = FIXTURE_LIGHT
		light.light_energy = 1.2
		light.spot_angle = 36.0
		light.spot_range = 4.0
		light.spot_attenuation = 0.6
		light.position = Vector3(0, 0, -0.07)
		head.add_child(light)


func _add_cylinder(center: Vector3, top: float, bottom: float, height: float, material: Material,
		parent: Node = self, open_bottom := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.cap_bottom = not open_bottom
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 24
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	parent.add_child(instance)
	return instance


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


## A tiling PBR surface from assets/store/<name>/ (albedo, normal and
## roughness maps), mapped by world position so it runs on across
## neighbouring boxes. `size` is how many metres one copy of it covers.
static func _textured(name: String, size: float) -> StandardMaterial3D:
	var dir := "res://assets/store/%s/" % name
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(dir + "albedo.jpg")
	material.normal_enabled = true
	material.normal_texture = load(dir + "normal.jpg")
	material.roughness_texture = load(dir + "roughness.jpg")
	material.roughness = 1.0  # Scales the map.
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / size
	return material


## A copy of a textured surface that follows the mesh's own UVs instead.
static func _by_uv(material: StandardMaterial3D) -> StandardMaterial3D:
	var copy: StandardMaterial3D = material.duplicate()
	copy.uv1_triplanar = false
	copy.uv1_world_triplanar = false
	copy.uv1_scale = Vector3.ONE
	return copy


static func _metal(color: Color, roughness: float) -> StandardMaterial3D:
	var material := _material(color)
	material.metallic = 0.8
	material.roughness = roughness
	return material


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
