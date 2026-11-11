extends Node3D
## Builds the graybox store: one small room, cluttered on purpose. A closed
## door in the right-hand wall with the IN deliveries and the OUT shipping
## corner either side of it, one wall-length binder shelf on the back wall,
## and four work tables in the middle for setting binders down and stacking
## cards. On the left-hand wall stand two glass display cabinets for the rare
## cards, with a reading corner between them: an armchair, a side table with
## the shop's radio on it, and a floor lamp. A longcase clock stands between
## the windows on the front wall.
##
## Everything is plain boxes so the layout is cheap to change. Coordinates are
## metres: x runs 0..WIDTH left to right as you face the back wall, z runs from
## the back wall (0) to the front wall (DEPTH), y is up.

const WIDTH := 12.0
const DEPTH := 8.0
const CEILING_HEIGHT := 3.0
const WALL_THICKNESS := 0.2
## The most of the back wall the binder shelf may take, as an x range. The
## shelf itself is only as long as its binders need (ShelfUnit.fitted_width),
## centred in this range, so no shelf runs empty; new sets lengthen it.
## Binders read left to right, top shelf first, so the shelf reads the
## timeline like a book.
const BACK_SHELF := Vector2(2.0, 10.0)
## The card tables: 1.3 m square and 1.0 m tall, standing height, so the
## cards on them sit close under the player's eye. They're built as standing
## library tables (deep apron, low stretcher) so the height reads as meant.
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
## Windows on the front wall, either side of the clock: centres along x,
## and the opening's size and sill height.
const WINDOW_XS := [2.9, 9.1]
const WINDOW_SIZE := Vector2(1.8, 1.5)
const WINDOW_SILL := 0.9
## Pendant shades hang this high (their rim), about 1.3 m over the tables:
## high enough that each lamp lights the floor past its table's edge, so
## the table shadows don't meet in a dark seam between neighbouring tables.
const PENDANT_HEIGHT := 2.3
## Picture lights: their wall plate's height over a frame's top, and the
## hood's length as a share of the frame's width.
const PICTURE_LIGHT_GAP := 0.1
const PICTURE_LIGHT_SPAN := 0.6
## Unseen fill spots that light the binder shelf's face: how far out from the
## back wall they hang, how many, and how bright.
const SHELF_FILL_Z := 1.15
const SHELF_FILLS := 7
const SHELF_FILL_ENERGY := 1.0
const FIXTURE_LIGHT := Color(1.0, 0.82, 0.6)
## The display cabinets stand against the left-hand wall (x = 0), facing
## into the room, centred at these z, back one first, with the reading
## corner and its wall of frames between them.
const CABINET_ZS := [1.4, 6.6]
## The reading corner on the left-hand wall (x = 0), between the cabinets:
## along the wall from the back, the side table, the floor lamp tucked in
## against the wall, and the armchair, turned out to face the room, angled a
## little toward the back tables. Floor centres, and the chair's and radio's
## turn (yaw) from facing the door.
const SIDE_TABLE_AT := Vector2(0.76, 3.34)
const FLOOR_LAMP_AT := Vector2(0.32, 3.97)
const ARMCHAIR_AT := Vector2(0.91, 4.54)
const ARMCHAIR_YAW := deg_to_rad(116.0)
## The radio sits across the side table, facing out into the room.
const RADIO_ON_TABLE := Vector2(0.0, -0.05)
const RADIO_YAW := deg_to_rad(70.0)
## The door, centred along the right-hand wall (x = WIDTH): its centre along z.
const DOOR_Z := 4.0
## The shipping corner (ShippingStation) just inside the door, on its front
## side (deliveries turn up on the back side, Main.DELIVERY_ROWS): the middle
## of its OUTGOING mat. It faces into the room, its crate toward the door.
const SHIPPING_AT := Vector2(11.45, 6.3)
## The INCOMING crate (PackCrate): against the right-hand wall just inside
## the door, on its back side, clear of the door's casing.
const PACK_CRATE_AT := Vector2(11.82, 3.06)
## The longcase clock stands against the front wall between the windows:
## its floor centre along x.
const CLOCK_X := 6.0
## The wall art (WallArt), hung in its order. Over the binder shelf, one
## landscape frame centred over each span between pairs of legs, their
## bottoms 22 cm above the shelf top so what's put down there doesn't hide
## them: the height they share, and the art size, mat and moulding for a
## SHELF_ART_SPAN-wide span. Narrower spans get smaller frames, in proportion.
const SHELF_ART := [2.055, Vector2(0.88, 0.64), 0.09, 0.05]
const SHELF_ART_SPAN := 1.6
## Over the reading corner, a grid of seven around a centre piece over the
## floor lamp (its bottom clear of the shade): the centre piece, the pair
## stacked on its shelf side (top, bottom), the pair on its door side, then
## a portrait frame at the shelf end and one at the door end. Each is
## [centre along z, centre height, art size, mat, moulding].
const CORNER_ART := [
	[3.95, 2.08, Vector2(0.75, 0.55), 0.08, 0.045],
	[3.095, 2.253, Vector2(0.36, 0.263), 0.06, 0.035],
	[3.095, 1.721, Vector2(0.36, 0.263), 0.06, 0.035],
	[4.805, 2.253, Vector2(0.36, 0.263), 0.06, 0.035],
	[4.805, 1.721, Vector2(0.36, 0.263), 0.06, 0.035],
	[2.495, 2.05, Vector2(0.3, 0.42), 0.06, 0.035],
	[5.405, 2.05, Vector2(0.3, 0.42), 0.06, 0.035],
]
## The store's wood (assets/store/table_wood): tables, cabinets, the binder
## shelf, window frames and the door. And how many metres of real wood one
## copy of its texture covers.
const TABLE_WOOD := "table_wood"
const TABLE_WOOD_SIZE := 0.6
## The green baize on the tables' playing surface and lining the cabinets'
## backs (assets/store/felt), and how many metres one copy of it covers.
const FELT := "felt"
const FELT_SIZE := 0.3
## The floorboards (assets/store/floorboards, baked from the walnut by
## tools/bake_floorboards.py), and how many metres one copy covers.
const FLOOR := "floorboards"
const FLOOR_SIZE := 1.68
## Painted plaster on the walls and ceiling (assets/store/plaster), and how
## many metres one copy of it covers. The walls above the panelling are
## parchment (style bible §4.5, user 2026-11-11), the ceiling a paler cream.
const PLASTER := "plaster"
const PLASTER_SIZE := 2.0
const PARCHMENT := Color("d6c39a")
const CEILING_CREAM := Color("d9ccb2")
## The rug under the tables (assets/store/rug, tools/bake_rug.py): its
## centre, its size, and its height, just under the first layer of cards
## lying on the floor (PileWorld.CARD_THICKNESS) so it never hides them.
const RUG := "rug"
const RUG_AT := Vector2(6.0, 4.1)
const RUG_SIZE := Vector2(5.0, 4.6)
const RUG_HEIGHT := 0.0004
## The armchair's leather (assets/store/leather, the binders' hide), dyed a
## deep bottle green to stand apart from the walnut and echo the baize, and
## how many metres one copy of it covers.
const LEATHER := "leather"
const LEATHER_SIZE := 0.4
const CHAIR_LEATHER := Color(0.1, 0.22, 0.15)
## Polished brass for the door and cabinet hardware and the curtain rods
## (assets/store/brass), and how many metres one copy of it covers.
const BRASS := "brass"
const BRASS_SIZE := 0.1
## The curtains' knit (assets/store/curtain), tinted cream, and how many
## metres one copy of it covers.
const CURTAIN := "curtain"
const CURTAIN_SIZE := 0.2
## The window drapes: heavy oxblood velvet (the knit, dyed), and how far down
## them the holdbacks gather them in.
const DRAPE_COLOUR := Color(0.34, 0.08, 0.07)
const DRAPE_TIE := 0.58
## The windows' leaded glass (tools/bake_leaded_glass.py), one pane's worth.
const LEADED_GLASS := preload("res://assets/store/leaded_glass/albedo.png")
## The view through the windows: three pictures outside, seen with parallax
## through old glass (shaders/window_view.gdshader, assets/store/window_view).
const WINDOW_VIEW := preload("res://shaders/window_view.gdshader")

## Floor footprints nothing on the floor may overlap (the shelves and the
## table legs), as x/z rectangles. The space under a table top is open:
## cards can end up underneath.
var obstacles: Array[Rect2] = []
## Tops that cards and binders can be put down on, like the floor: the
## tables and the binder shelf, as x/z rectangles.
var surfaces: Array[Rect2] = []
## For the DayCycle: the light from each window, the drapes, and the window
## glass, whose view outside it tints with the daylight.
var window_lights: Array[Light3D] = []
var curtain_material := _drapes()
var sky_material := ShaderMaterial.new()
## Every shadow box in the display cabinets, back cabinet first, each
## cabinet's top row first, left to right as you face it.
var display_slots: Array[Marker3D] = []
## The display cabinets, back cabinet first; their slots hold the rare cards
## in that order.
var cabinets: Array[DisplayCabinet] = []
## The radio on the reading corner's side table.
var radio: ShopRadio
## The shipping corner by the door: the OUTGOING mat and the crate of
## flat-packed shipping boxes.
var shipping_station: ShippingStation
## The INCOMING crate just inside the door that booster packs are delivered
## into (PackCrate).
var pack_crate: PackCrate
## The longcase clock; the shop gives it the DayCycle to show.
var clock: ShopClock
## The wall art's frames, in WallArt's order.
var wall_frames: Array[WallFrame] = []
## The back-wall binder shelf.
var binder_shelf: ShelfUnit

var _wall_material := _tinted(_textured(PLASTER, PLASTER_SIZE), PARCHMENT)
var _ceiling_material := _tinted(_textured(PLASTER, PLASTER_SIZE), CEILING_CREAM)
var _floor_material := _textured(FLOOR, FLOOR_SIZE)
var _table_material := _textured(TABLE_WOOD, TABLE_WOOD_SIZE)
## The same wood for the legs, mapped by the legs' own UVs so the grain runs
## up them (world mapping would lay it across, like the top's).
## The bookcase's trim (its mouldings and top), a shade lighter than the wood.
var _trim_material: Material = ShelfUnit._tinted(_table_material, 1.12)
var _felt_material := _textured(FELT, FELT_SIZE)
var _fixture_material := _metal(Color(0.12, 0.13, 0.12), 0.45)
var _brass_material := _brass()


## The floor area cards can land on, inset a little from the walls.
func floor_bounds() -> Rect2:
	return Rect2(0.05, 0.05, WIDTH - 0.1, DEPTH - 0.1)


func _ready() -> void:
	_build_shell()
	_build_binder_shelves()
	_build_tables()
	_build_display_cabinets()
	_build_reading_corner()
	_build_shipping_station()
	_build_pack_crate()
	_build_wall_art()
	_build_picture_lights()
	_build_clock()
	_build_windows()
	_build_door()
	_build_pendants()


func _build_shell() -> void:
	var half := WALL_THICKNESS / 2
	_add_solid(Vector3(WIDTH, 0.2, DEPTH), Vector3(WIDTH / 2, -0.1, DEPTH / 2), _floor_material)
	_add_solid(Vector3(WIDTH, 0.2, DEPTH), Vector3(WIDTH / 2, CEILING_HEIGHT + 0.1, DEPTH / 2), _ceiling_material)
	_add_wall_x(0.0, WIDTH, -half)
	_add_wall_x(0.0, WIDTH, DEPTH + half)
	_add_wall_z(-half, 0.0, DEPTH)
	_add_wall_z(WIDTH + half, 0.0, DEPTH)
	var panelling := WallPanelling.new()
	panelling.name = "WallPanelling"
	panelling.build(WallPanelling.room_runs(WIDTH, DEPTH, DOOR_Z, ShopDoor.footprint().size.x + 0.04),
		_table_material, CEILING_HEIGHT)
	add_child(panelling)
	_build_rug()


## The rug: a flat quad just above the floor, under the tables. It takes no
## part in physics; cards land on the floor beneath it as before.
func _build_rug() -> void:
	var quad := PlaneMesh.new()
	quad.size = RUG_SIZE
	var rug := MeshInstance3D.new()
	rug.name = "Rug"
	rug.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/store/%s/albedo.jpg" % RUG)
	material.roughness = 1.0
	rug.material_override = material
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rug.position = Vector3(RUG_AT.x, RUG_HEIGHT, RUG_AT.y)
	add_child(rug)


## One wall-length, two-shelf library bookcase on the back wall, facing the
## door, holding every binder, in the tables' dark wood with brass label
## holders; its top is a surface like a table's.
func _build_binder_shelves() -> void:
	var binders := CardDatabase.all_binders()
	var most := BACK_SHELF.y - BACK_SHELF.x - 2 * ShelfUnit.SIDE_THICKNESS
	var inner := ShelfUnit.fitted_width(binders)
	if inner > most:
		push_error("StoreBuilder: the binders need %.2f m of shelf; the back wall has room for %.2f m" % [inner, most])
		inner = most
	var unit := ShelfUnit.new()
	unit.name = "BinderShelf"
	unit.build(binders, _table_material, inner, ShelfUnit.BAYS, _brass_material)
	unit.position = Vector3((BACK_SHELF.x + BACK_SHELF.y) / 2, 0, ShelfUnit.DEPTH / 2)
	binder_shelf = unit
	_add_shelf(unit)
	var top := unit.top_rect()
	surfaces.append(Rect2(top.position + Vector2(unit.position.x, unit.position.z), top.size))


## Each table is a heavy solid-wood games table in the bookcase's style: a
## thick top in its moulded edge round a felt playing surface, a deep apron,
## and four fluted legs that taper toward the floor into brass foot caps. The space under the top stays open, so cards that
## slid underneath stay in sight and in reach (crouching gets you under).
func _build_tables() -> void:
	for center in TABLE_CENTERS:
		_build_table(center)


func _build_table(center: Vector2) -> void:
	const TOP := 0.048
	## The moulded edge round the top (the bookcase's shelf edge): how deep.
	const EDGE := 0.012
	## Legs: fluted and tapering, in brass foot caps, set in from the edge.
	const LEG_TOP := 0.1
	const LEG_INSET := 0.05
	const APRON_HEIGHT := 0.14
	## A low H-stretcher between the legs, as on a standing library table.
	const STRETCHER_Y := 0.2
	const STRETCHER := Vector2(0.045, 0.05)
	const APRON_THICKNESS := 0.025
	const FELT_BORDER := 0.11
	var body := StaticBody3D.new()
	body.position = Vector3(center.x, 0, center.y)
	add_child(body)
	var size := Vector2(TABLE_SIZE.x, TABLE_SIZE.z)
	var top_y := TABLE_SIZE.y
	surfaces.append(Rect2(center - size / 2, size))
	# The top and apron are their own body, so the player can lean over them.
	var top := StaticBody3D.new()
	top.add_to_group(TABLE_TOPS)
	body.add_child(top)

	# The top: a slab inside the bookcase's moulded edge, which runs round it.
	_add_part(top, Vector3(size.x - 2 * EDGE, TOP, size.y - 2 * EDGE), Vector3(0, top_y - TOP / 2, 0), _table_material, false)
	_add_shape(top, Vector3(size.x, TOP, size.y), Vector3(0, top_y - TOP / 2, 0))
	Furniture.ring(top, "ShelfEdge", Vector3(0, top_y, 0), size - Vector2.ONE * 2 * EDGE, EDGE, _trim_material)
	_add_part(top, Vector3(size.x - 2 * FELT_BORDER, 0.001, size.y - 2 * FELT_BORDER),
		Vector3(0, top_y + 0.0005, 0), _felt_material, false)

	var leg_half := size / 2 - Vector2.ONE * (LEG_INSET + LEG_TOP / 2)
	var leg_height := top_y - TOP
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at: Vector2 = corner * leg_half
		Furniture.leg(body, Vector3(at.x, 0, at.y), LEG_TOP, leg_height, _table_material, _brass_material)
		_add_shape(body, Vector3(LEG_TOP, leg_height, LEG_TOP), Vector3(at.x, leg_height / 2, at.y))
		var world := center + at
		obstacles.append(Rect2(world - Vector2.ONE * LEG_TOP / 2, Vector2.ONE * LEG_TOP))

	# Apron rails between the legs, set a little back from the legs' faces.
	var apron_y := top_y - TOP - APRON_HEIGHT / 2
	var rail_offset := leg_half + Vector2.ONE * (LEG_TOP / 2 - APRON_THICKNESS / 2 - 0.008)
	for side in [-1, 1]:
		_add_part(top, Vector3(2 * leg_half.x, APRON_HEIGHT, APRON_THICKNESS), Vector3(0, apron_y, side * rail_offset.y), _table_material, true)
		_add_part(top, Vector3(APRON_THICKNESS, APRON_HEIGHT, 2 * leg_half.y), Vector3(side * rail_offset.x, apron_y, 0), _table_material, true)

	# The H-stretcher: a rail between each side's legs, and one across the
	# middle. Only seen: nothing collides with it.
	for side in [-1, 1]:
		_add_part(body, Vector3(STRETCHER.x, STRETCHER.y, 2 * leg_half.y), Vector3(side * leg_half.x, STRETCHER_Y, 0), _table_material, false)
	_add_part(body, Vector3(2 * leg_half.x, STRETCHER.y, STRETCHER.x), Vector3(0, STRETCHER_Y, 0), _table_material, false)

	# What stops a lean: TABLE_LEAN in from the edge, under the top, and above
	# a crouched body so you can still crawl underneath.
	const LEAN_STOP_BOTTOM := 0.65
	var lean_stop := StaticBody3D.new()
	lean_stop.collision_layer = LEAN_STOP_LAYER
	lean_stop.collision_mask = 0
	body.add_child(lean_stop)
	var stop_height := top_y - TOP - LEAN_STOP_BOTTOM
	_add_shape(lean_stop, Vector3(size.x - 2 * TABLE_LEAN, stop_height, size.y - 2 * TABLE_LEAN), Vector3(0, LEAN_STOP_BOTTOM + stop_height / 2, 0))


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
		cabinet.build(_table_material, _felt_material, _brass_material, FIXTURE_LIGHT)
		cabinet.position = Vector3(DisplayCabinet.DEPTH / 2, 0, CABINET_ZS[i])
		cabinet.rotation.y = PI / 2
		cabinet.first_number = display_slots.size() + 1
		add_child(cabinet)
		cabinets.append(cabinet)
		display_slots.append_array(cabinet.slots)
		# Turned a quarter, the footprint's across becomes z and its out-from-the-wall +x.
		var footprint := DisplayCabinet.footprint()
		obstacles.append(Rect2(Vector2(DisplayCabinet.DEPTH / 2 + footprint.position.y, CABINET_ZS[i] - footprint.end.x),
			Vector2(footprint.size.y, footprint.size.x)))


## The longcase clock against the front wall between the windows, facing
## into the room.
func _build_clock() -> void:
	clock = ShopClock.new()
	clock.name = "ShopClock"
	clock.build(_table_material, _brass_material)
	_place(clock, Vector2(CLOCK_X, DEPTH - ShopClock.DEPTH / 2), PI, Vector2(ShopClock.WIDTH, ShopClock.DEPTH))


## Empty picture frames over the binder shelf and the reading corner (see
## SHELF_ART and CORNER_ART), waiting for their cards (WallArt).
func _build_wall_art() -> void:
	var legs := binder_shelf.leg_spots()
	for i in range(1, legs.size()):
		var span := legs[i] - legs[i - 1]
		var shrink := minf(1.0, span / SHELF_ART_SPAN)
		var x := binder_shelf.position.x + (legs[i] + legs[i - 1]) / 2
		_hang_frame(Vector3(x, SHELF_ART[0], 0), 0.0, SHELF_ART[1] * shrink, SHELF_ART[2] * shrink, SHELF_ART[3] * shrink)
	for frame in CORNER_ART:
		_hang_frame(Vector3(0, frame[1], frame[0]), PI / 2, frame[2], frame[3], frame[4])


func _hang_frame(at: Vector3, yaw: float, art_size: Vector2, mat: float, moulding: float) -> void:
	var frame := WallFrame.new()
	frame.name = "WallFrame%02d" % (wall_frames.size() + 1)
	frame.build(art_size, mat, moulding, _table_material)
	frame.position = at
	frame.rotation.y = yaw
	add_child(frame)
	wall_frames.append(frame)


## The reading corner (see SIDE_TABLE_AT): solid furniture whose footprints
## the cards keep clear of, and the radio, which opens the Radio menu.
func _build_reading_corner() -> void:
	var leather := _textured(LEATHER, LEATHER_SIZE)
	leather.albedo_color = CHAIR_LEATHER
	leather.normal_scale = 2.0
	var chair := ReadingCorner.armchair(leather, _table_material, _brass_material)
	chair.name = "Armchair"
	_place(chair, ARMCHAIR_AT, ARMCHAIR_YAW, ReadingCorner.CHAIR_SIZE)
	var table := ReadingCorner.side_table(_table_material, _brass_material)
	table.name = "SideTable"
	_place(table, SIDE_TABLE_AT, 0.0, Vector2.ONE * ReadingCorner.TABLE_TOP)
	var lamp := ReadingCorner.floor_lamp(_brass_material, _curtain(), FIXTURE_LIGHT)
	lamp.name = "FloorLamp"
	_place(lamp, FLOOR_LAMP_AT, 0.0, Vector2.ONE * ReadingCorner.LAMP_BASE)
	radio = ShopRadio.new()
	radio.name = "ShopRadio"
	radio.build()
	var on := SIDE_TABLE_AT + RADIO_ON_TABLE
	radio.position = Vector3(on.x, ReadingCorner.TABLE_HEIGHT, on.y)
	radio.rotation.y = RADIO_YAW
	add_child(radio)


func _build_shipping_station() -> void:
	shipping_station = ShippingStation.new()
	shipping_station.build(_table_material)
	shipping_station.position = Vector3(SHIPPING_AT.x, 0, SHIPPING_AT.y)
	shipping_station.rotation.y = -PI / 2
	add_child(shipping_station)
	obstacles.append(shipping_station.crate_footprint())


func _build_pack_crate() -> void:
	pack_crate = PackCrate.new()
	pack_crate.build(_table_material)
	pack_crate.position = Vector3(PACK_CRATE_AT.x, 0, PACK_CRATE_AT.y)
	add_child(pack_crate)
	obstacles.append(pack_crate.footprint())


## Adds a piece standing on the floor at `at`, turned by `yaw`, and keeps the
## cards off its footprint (`size` across by deep, as the box around it once turned).
func _place(body: Node3D, at: Vector2, yaw: float, size: Vector2) -> void:
	body.position = Vector3(at.x, 0, at.y)
	body.rotation.y = yaw
	add_child(body)
	var reach := Vector2(absf(cos(yaw)) * size.x + absf(sin(yaw)) * size.y,
		absf(sin(yaw)) * size.x + absf(cos(yaw)) * size.y)
	obstacles.append(Rect2(at - reach / 2, reach))


## Each window is a framed opening with a deep sill and leaded glass lit by
## the sky, with heavy drapes on a brass rod gathered back to either side.
func _build_windows() -> void:
	const FRAME := 0.07
	const FRAME_DEPTH := 0.06
	const CURTAIN_Z := 0.13
	sky_material.shader = WINDOW_VIEW
	sky_material.set_shader_parameter("leaded", LEADED_GLASS)
	sky_material.set_shader_parameter("wall_z", DEPTH)
	for layer in ["near", "mid", "far"]:
		sky_material.set_shader_parameter(layer + "_layer", load("res://assets/store/window_view/%s.png" % layer))
	curtain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var size: Vector2 = WINDOW_SIZE
	for x in WINDOW_XS:
		var mid_y := WINDOW_SILL + size.y / 2
		# Leaded glass, a pane either side of the transom, facing the room.
		for half in [-1, 1]:
			var pane := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(size.x, size.y / 2)
			pane.mesh = quad
			pane.material_override = sky_material
			pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pane.position = Vector3(x, mid_y + half * size.y / 4, DEPTH - 0.01)
			pane.rotation.y = PI
			add_child(pane)
		# Frame: head, jambs, a cross bar, and a sill that sticks out.
		var frame_z := DEPTH - FRAME_DEPTH / 2
		for side in [-1, 1]:
			_add_part(self, Vector3(FRAME, size.y + 2 * FRAME, FRAME_DEPTH), Vector3(x + side * (size.x + FRAME) / 2, mid_y, frame_z), _table_material, false)
		_add_part(self, Vector3(size.x + 2 * FRAME, FRAME, FRAME_DEPTH), Vector3(x, WINDOW_SILL + size.y + FRAME / 2, frame_z), _table_material, false)
		_add_part(self, Vector3(size.x, FRAME * 0.6, FRAME_DEPTH * 0.6), Vector3(x, mid_y, DEPTH - FRAME_DEPTH * 0.3), _table_material, false)
		_add_part(self, Vector3(size.x + 2 * FRAME + 0.06, 0.04, 0.16), Vector3(x, WINDOW_SILL - 0.02, DEPTH - 0.08), _table_material, false)
		# Heavy drapes either side, gathered back to brass holdbacks.
		var rod_y := WINDOW_SILL + size.y + FRAME + 0.08
		var rod := MeshInstance3D.new()
		var rod_mesh := CylinderMesh.new()
		rod_mesh.top_radius = 0.014
		rod_mesh.bottom_radius = 0.014
		rod_mesh.height = size.x + 0.7
		rod.mesh = rod_mesh
		rod.material_override = _brass_material
		rod.rotation.z = PI / 2
		rod.position = Vector3(x, rod_y, DEPTH - CURTAIN_Z)
		add_child(rod)
		var drape_width := size.x / 2 + 0.25
		# The drapes stop just clear of the sill.
		var drop := rod_y - (WINDOW_SILL + 0.025)
		for side in [-1, 1]:
			var finial := _add_cylinder(Vector3(x + side * (size.x / 2 + 0.35), rod_y, DEPTH - CURTAIN_Z), 0.026, 0.026, 0.05, _brass_material)
			finial.rotation.z = PI / 2
			var outer_x: float = x + side * (size.x / 2 + 0.3)
			var drape := MeshInstance3D.new()
			drape.mesh = _drape_mesh(drape_width, drop, -side)
			drape.material_override = curtain_material
			drape.position = Vector3(outer_x, rod_y, DEPTH - CURTAIN_Z)
			add_child(drape)
			var holdback := _add_cylinder(Vector3(outer_x - side * 0.08, rod_y - drop * DRAPE_TIE, DEPTH - 0.04), 0.022, 0.012, 0.08, _brass_material)
			holdback.rotation.x = PI / 2
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


## The door, on the right-hand wall at DOOR_Z, facing into the room.
func _build_door() -> void:
	var door := ShopDoor.new()
	door.name = "ShopDoor"
	door.build(_table_material, _brass_material)
	door.position = Vector3(WIDTH, 0, DOOR_Z)
	door.rotation.y = -PI / 2
	add_child(door)
	# Turned a quarter, the footprint's across becomes z and its depth -x.
	var footprint := ShopDoor.footprint()
	obstacles.append(Rect2(Vector2(WIDTH - footprint.end.y, DOOR_Z + footprint.position.x), Vector2(footprint.size.y, footprint.size.x)))


## A heavy drape hanging from its top outer corner (the origin), its folds
## running `inward` (+1 or -1 along x) toward the window's middle, gathered
## in at DRAPE_TIE of the way down and flaring out again below.
static func _drape_mesh(width: float, drop: float, inward: float) -> ArrayMesh:
	const PLEAT := 0.13
	const DEPTH_OF_PLEAT := 0.05
	const ACROSS := 48
	const DOWN := 32
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array[PackedVector3Array] = []
	for j in DOWN + 1:
		var t := float(j) / DOWN
		var gather := _drape_gather(t)
		var row := PackedVector3Array()
		for i in ACROSS + 1:
			var u := float(i) / ACROSS
			var along := u * width
			# Folds deepen where the cloth is gathered in.
			var fold := DEPTH_OF_PLEAT / 2 * sin(TAU * along / PLEAT) / sqrt(gather)
			row.append(Vector3(inward * along * gather, -t * drop, fold + 0.02 * (1.0 - gather)))
		rows.append(row)
	for j in DOWN:
		for i in ACROSS:
			var a := rows[j][i]
			var b := rows[j][i + 1]
			var c := rows[j + 1][i + 1]
			var d := rows[j + 1][i]
			for v in [a, b, c, a, c, d]:
				tool.add_vertex(v)
	tool.generate_normals()
	return tool.commit()


## How much of a drape's width is left at `t` of the way down: wide at the
## rod, pinched in at the holdback, flaring a little below it.
static func _drape_gather(t: float) -> float:
	if t <= DRAPE_TIE:
		return lerpf(0.34, 0.2, smoothstep(0.0, 1.0, t / DRAPE_TIE))
	return lerpf(0.2, 0.3, smoothstep(0.0, 1.0, (t - DRAPE_TIE) / (1.0 - DRAPE_TIE)))


## A brass library pendant over each table (LightFixtures.pendant), its
## green glass shade lined in opal, with a warm downlight that pools on the
## felt and spills onto the floor round the table.
func _build_pendants() -> void:
	for center in TABLE_CENTERS:
		var at := Vector3(center.x, 0, center.y)
		LightFixtures.pendant(self, Vector3(at.x, PENDANT_HEIGHT, at.z), CEILING_HEIGHT, _brass_material)
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


## Brass picture lights over the frames above the binder shelf and over the
## centre of the reading corner's wall of frames.
##
## The shelf's spines face the room, where a light on the wall can't reach
## them, so unseen fill spots out over the room (where the old ceiling track
## hung) keep the labels and spines readable, like light from the pendants.
func _build_picture_lights() -> void:
	for frame in wall_frames:
		var shelf_frame := is_zero_approx(frame.rotation.y)
		if not shelf_frame and not is_equal_approx(frame.position.z, CORNER_ART[0][0]):
			continue
		var outer := WallFrame.outer_size(frame.opening, frame.mat, frame.moulding)
		var half := outer.y / 2
		var plate := frame.position + Vector3(0, half + PICTURE_LIGHT_GAP, 0)
		var normal := Vector3(sin(frame.rotation.y), 0, cos(frame.rotation.y))
		LightFixtures.picture_light(self, plate + normal * 0.005, frame.rotation.y,
			outer.x * PICTURE_LIGHT_SPAN, half + PICTURE_LIGHT_GAP, _brass_material, FIXTURE_LIGHT)
	var length := ShelfUnit.outer_width(binder_shelf.width)
	var start := binder_shelf.position.x - length / 2
	for i in SHELF_FILLS:
		var x: float = start + length * (i + 0.5) / SHELF_FILLS
		var light := SpotLight3D.new()
		light.light_color = FIXTURE_LIGHT
		light.light_energy = SHELF_FILL_ENERGY
		light.spot_angle = 36.0
		light.spot_range = 4.0
		light.spot_attenuation = 0.6
		light.light_specular = 0.0
		var from := Vector3(x, CEILING_HEIGHT - 0.12, SHELF_FILL_Z)
		light.transform = Transform3D(Basis.looking_at(Vector3(x, 0.95, ShelfUnit.DEPTH) - from, Vector3.UP), from)
		add_child(light)


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
	var size := Vector2(ShelfUnit.outer_width(unit.width), ShelfUnit.DEPTH)
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


## `material` with its colour multiplied by `tint` (returned for chaining).
static func _tinted(material: StandardMaterial3D, tint: Color) -> StandardMaterial3D:
	material.albedo_color = tint
	return material


## The window drapes: the knit, dyed oxblood, with a velvet sheen.
static func _drapes() -> StandardMaterial3D:
	var material := _curtain()
	material.albedo_color = DRAPE_COLOUR
	material.rim_enabled = true
	material.rim = 0.5
	material.rim_tint = 0.4
	return material


## The knit curtain fabric, tinted the curtains' cream.
static func _curtain() -> StandardMaterial3D:
	var material := _textured(CURTAIN, CURTAIN_SIZE)
	material.albedo_color = Color(0.86, 0.8, 0.68)
	material.normal_scale = 2.0  # The knit's own relief barely shows on a curtain.
	return material


## The brass texture as a metal (its metalness map is solid white).
static func _brass() -> StandardMaterial3D:
	var material := _textured(BRASS, BRASS_SIZE)
	material.metallic = 1.0
	return material


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
