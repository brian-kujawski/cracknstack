class_name DisplayCabinet
extends StaticBody3D
## A solid-oak display cabinet for the rare cards: a closed cupboard base, and
## on it a glass case with two glazed front doors, glass sides and a lined
## back. Hung on the back, in rows, are empty shadow boxes, one per rare card,
## each with a blank brass plate under it. Lights under the case's top shine
## down onto the frames.
##
## Its origin is on the floor, centred under the cabinet, its back against
## the wall, and its glass front faces local +Z. Local +X runs left to right
## as you face it.
##
## Each shadow box has a slot: a Marker3D where a card hangs, face out (+Z),
## upright (+Y), centred in the box. Each holds one rare card (RareCards):
## slot 0 holds rare card `first_number`, the next slot the next number, and
## so on. The slots fill the left half of the case (three by three, row by
## row from the top) and then the right half, so each half shows nine cards
## in order. A card hung in its box locks in for good, with the glow and sound
## of a card locking into a binder pocket.

const WIDTH := 1.5
const DEPTH := 0.45
## The cupboard base, up to the top of the shelf the glass case stands on.
const BASE_HEIGHT := 0.885
## Top of the glass case (under the cornice).
const CASE_TOP := 2.05
## The cornice overhangs the front and sides by this much.
const CORNICE_OVERHANG := 0.03
const CORNICE_HEIGHT := 0.08
## Shadow boxes: rows top first, columns left to right.
const ROWS := 3
const COLUMNS := 6
## The case is filled in halves this many columns wide (see slots).
const HALF_COLUMNS := COLUMNS / 2
const SLOTS := ROWS * COLUMNS
## A shadow box's outside size, and how deep it stands off the back.
const FRAME_SIZE := Vector2(0.17, 0.22)
const FRAME_DEPTH := 0.05
## How far in front of the box's lining a card hangs (on standoffs).
const CARD_STANDOFF := 0.012

const _POST := 0.045
const _BACK := 0.02
const _LINING := 0.004
const _MOULDING := 0.022

## The slot markers: the left half's nine boxes, row by row from the top
## and left to right in each row, then the right half's.
var slots: Array[Marker3D] = []
## The rare card number slot 0 holds (the next cabinet carries on from
## first_number + SLOTS).
var first_number := 1
## Per slot: the card id hung there, or -1.
var displayed := PackedInt32Array()

## Per slot: the card hanging there, made when it's first hung.
var _views: Array[MeshInstance3D] = []

var _parts := {}


## The floor footprint (x across, z out from the wall), in local metres.
static func footprint() -> Rect2:
	var width := WIDTH + 2 * CORNICE_OVERHANG
	return Rect2(-width / 2, -DEPTH / 2, width, DEPTH + CORNICE_OVERHANG)


## Builds the meshes, lights, collision and slots. `wood` is the oak the
## store's tables are made of, `lining` covers the back of the case behind
## the frames, `brass` is for the knobs and plates, and `light` is the colour
## of the store's lamps. Call once before adding to the tree.
func build(wood: StandardMaterial3D, lining: Material, brass: Material, light: Color) -> void:
	var dark := _tinted(wood, 0.7)
	var walnut := _tinted(wood, 0.5)
	var linen := _material(Color(0.83, 0.79, 0.7), 0.95)
	var glass := _material(Color(0.85, 0.93, 0.92, 0.1), 0.04)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic_specular = 0.8

	_build_base(wood, dark, brass)
	_build_case(wood, lining, brass, glass)
	_build_frames(walnut, linen, brass)
	_build_lights(light)
	_commit()

	displayed.resize(slots.size())
	displayed.fill(-1)
	_views.resize(slots.size())

	var box := BoxShape3D.new()
	var top := CASE_TOP + CORNICE_HEIGHT
	box.size = Vector3(WIDTH, top, DEPTH)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position.y = top / 2
	add_child(shape)


## The slot rare card `number` hangs in here, or -1 if it's another
## cabinet's.
func slot_for(number: int) -> int:
	var slot := number - first_number
	return slot if slot >= 0 and slot < slots.size() else -1


## Where a card hanging in a slot is, as a global pose for a card quad (see
## Glide).
func slot_pose(slot: int) -> Transform3D:
	return slots[slot].global_transform


## The shadow box a ray from `from` to `to` looks into, or -1: the nearest
## one whose frame the ray passes through, through the glass.
func slot_on_ray(from: Vector3, to: Vector3) -> int:
	var best := -1
	var nearest := INF
	for i in slots.size():
		var pose := slots[i].global_transform
		var hit = Plane(pose.basis.z, pose.origin).intersects_segment(from, to)
		if hit == null:
			continue
		var local: Vector3 = pose.affine_inverse() * hit
		if absf(local.x) <= FRAME_SIZE.x / 2 and absf(local.y) <= FRAME_SIZE.y / 2 and from.distance_to(hit) < nearest:
			nearest = from.distance_to(hit)
			best = i
	return best


## Hides (or shows again) the card hanging in a slot, while it's away being
## looked at up close.
func set_lifted(slot: int, lifted: bool) -> void:
	if _views[slot] != null:
		_views[slot].visible = not lifted


func displayed_count() -> int:
	return slots.size() - displayed.count(-1)


func is_complete() -> bool:
	return displayed.count(-1) == 0


## Hangs card `id` in its own slot. Returns false if it isn't one of this
## cabinet's rare cards or its slot's taken. With `flash`, it glows up the
## way a card locking into its pocket does (a save putting it back doesn't).
func display(id: int, flash := true) -> bool:
	var card := CardDatabase.get_card(id)
	var slot := slot_for(card.collector_number) if RareCards.is_rare(card) else -1
	if slot < 0 or displayed[slot] >= 0:
		return false
	displayed[slot] = id
	var view := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = PileWorld.CARD_SIZE
	view.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/binder_card.gdshader")
	CardView.apply(material, id)
	material.set_shader_parameter("glow", Binder.LOCKED_GLOW)
	view.material_override = material
	slots[slot].add_child(view)
	_views[slot] = view
	if flash:
		var tween := view.create_tween()
		tween.tween_method(func(c: Color) -> void: material.set_shader_parameter("glow", c),
			Binder.FLASH_GLOW, Binder.LOCKED_GLOW, 0.9)
	return true


## Empties every slot (before a save fills them).
func clear_display() -> void:
	displayed.fill(-1)
	for i in _views.size():
		if _views[i] != null:
			_views[i].queue_free()
			_views[i] = null


## A recessed plinth, a carcass with two panelled doors, and the shelf the
## case stands on, overhanging the doors a little.
func _build_base(wood: Material, dark: Material, brass: Material) -> void:
	const PLINTH := 0.09
	const PLINTH_RECESS := 0.04
	const SHELF := 0.035
	_box(Vector3(WIDTH - 0.04, PLINTH, DEPTH - PLINTH_RECESS), Vector3(0, PLINTH / 2, -PLINTH_RECESS / 2), dark)
	var carcass_top := BASE_HEIGHT - SHELF
	var carcass := carcass_top - PLINTH
	_box(Vector3(WIDTH, carcass, DEPTH - 0.022), Vector3(0, PLINTH + carcass / 2, -0.011), wood)
	_box(Vector3(WIDTH + 0.02, SHELF, DEPTH + 0.015), Vector3(0, carcass_top + SHELF / 2, 0.0075), wood)

	# Two doors meeting in the middle: a slab with a frame of stiles and rails
	# standing proud of it, so the middle reads as a sunk panel.
	const GAP := 0.004
	const STILE := 0.06
	const SLAB := 0.016
	const RAISE := 0.008
	var door := Vector2(WIDTH / 2 - 0.02 - GAP, carcass - 2 * GAP)
	var mid_y := PLINTH + carcass / 2
	var slab_z := DEPTH / 2 - 0.022 + SLAB / 2
	for side in [-1, 1]:
		var x: float = side * (GAP / 2 + door.x / 2)
		_box(Vector3(door.x, door.y, SLAB), Vector3(x, mid_y, slab_z), wood)
		var face_z := slab_z + SLAB / 2 + RAISE / 2
		for edge in [-1, 1]:
			_box(Vector3(STILE, door.y, RAISE), Vector3(x + edge * (door.x - STILE) / 2, mid_y, face_z), wood)
			_box(Vector3(door.x - 2 * STILE, STILE, RAISE), Vector3(x, mid_y + edge * (door.y - STILE) / 2, face_z), wood)
		# A small brass knob by the meeting edge.
		var knob := Vector3(side * (GAP / 2 + STILE / 2), mid_y + door.y * 0.3, face_z + RAISE / 2)
		_box(Vector3(0.018, 0.018, 0.024), knob + Vector3(0, 0, 0.012), brass)


## The glass case: corner posts, a back panel lined with green baize, glass sides,
## two glazed doors, top and bottom rails, and a stepped cornice.
func _build_case(wood: Material, lining: Material, brass: Material, glass: Material) -> void:
	var height := CASE_TOP - BASE_HEIGHT
	var mid_y := BASE_HEIGHT + height / 2
	var front := DEPTH / 2
	var back := -DEPTH / 2
	_box(Vector3(WIDTH, height, _BACK), Vector3(0, mid_y, back + _BACK / 2), wood)
	_box(Vector3(WIDTH - 2 * _POST, height - 0.01, _LINING), Vector3(0, mid_y, back + _BACK + _LINING / 2), lining)
	for side in [-1, 1]:
		var x: float = side * (WIDTH / 2 - _POST / 2)
		_box(Vector3(_POST, height, _POST), Vector3(x, mid_y, front - _POST / 2), wood)
		_box(Vector3(_POST, height, _POST), Vector3(x, mid_y, back + _BACK + _POST / 2), wood)
		# Glass between the posts, with a thin rail top and bottom.
		var run := DEPTH - _BACK - 2 * _POST
		var run_z := back + _BACK + _POST + run / 2
		_box(Vector3(0.006, height - 0.07, run), Vector3(side * (WIDTH / 2 - 0.012), mid_y, run_z), glass, false)
		_box(Vector3(0.025, 0.035, run), Vector3(side * (WIDTH / 2 - 0.0125), BASE_HEIGHT + 0.0175, run_z), wood)
		_box(Vector3(0.025, 0.035, run), Vector3(side * (WIDTH / 2 - 0.0125), CASE_TOP - 0.0175, run_z), wood)

	# Front rails: a low one at the bottom and a deeper one at the top, which
	# hides the light strip behind it.
	const BOTTOM_RAIL := 0.04
	const TOP_RAIL := 0.06
	var inner := WIDTH - 2 * _POST
	_box(Vector3(inner, BOTTOM_RAIL, 0.03), Vector3(0, BASE_HEIGHT + BOTTOM_RAIL / 2, front - 0.015), wood)
	_box(Vector3(inner, TOP_RAIL, 0.03), Vector3(0, CASE_TOP - TOP_RAIL / 2, front - 0.015), wood)
	_box(Vector3(WIDTH, 0.025, DEPTH), Vector3(0, CASE_TOP + 0.0125, 0), wood)

	# Two glazed doors meeting in the middle, each a frame round a glass pane,
	# with a brass knob and a lock escutcheon at the meeting stiles.
	const GAP := 0.003
	const STILE := 0.035
	const THICK := 0.022
	var door := Vector2(inner / 2 - GAP, height - BOTTOM_RAIL - TOP_RAIL - 2 * GAP)
	var door_y := BASE_HEIGHT + BOTTOM_RAIL + GAP + door.y / 2
	var door_z := front - 0.004 - THICK / 2
	for side in [-1, 1]:
		var x: float = side * (GAP / 2 + door.x / 2)
		for edge in [-1, 1]:
			_box(Vector3(STILE, door.y, THICK), Vector3(x + edge * (door.x - STILE) / 2, door_y, door_z), wood)
			_box(Vector3(door.x - 2 * STILE, STILE, THICK), Vector3(x, door_y + edge * (door.y - STILE) / 2, door_z), wood)
		_box(Vector3(door.x - 2 * STILE + 0.01, door.y - 2 * STILE + 0.01, 0.005), Vector3(x, door_y, door_z), glass, false)
		var stile_x: float = side * (GAP / 2 + STILE / 2)
		_box(Vector3(0.016, 0.016, 0.02), Vector3(stile_x, door_y - 0.05, front + 0.006), brass)
	_box(Vector3(0.012, 0.03, 0.002), Vector3(-(GAP / 2 + STILE / 2), door_y + 0.03, front + 0.001), brass)

	# The cornice: a cove step, then the crown, both overhanging front and
	# sides and flush with the wall behind.
	var step := CORNICE_OVERHANG / 2
	var cove_y := CASE_TOP + 0.025
	_box(Vector3(WIDTH + 2 * step, 0.025, DEPTH + step), Vector3(0, cove_y + 0.0125, step / 2), wood)
	var crown := CORNICE_HEIGHT - 0.05
	_box(Vector3(WIDTH + 2 * CORNICE_OVERHANG, crown, DEPTH + CORNICE_OVERHANG),
		Vector3(0, cove_y + 0.025 + crown / 2, CORNICE_OVERHANG / 2), wood)


## The shadow boxes, hung on the baize back in a grid: a walnut moulding as
## deep as the box, a gilt slip round the front of the opening, and a linen
## lining at the back. Under each, a blank brass plate for the card's name.
func _build_frames(walnut: Material, linen: Material, brass: Material) -> void:
	var gilt := _material(Color(0.8, 0.66, 0.38), 0.4)
	gilt.metallic = 0.7
	var back := -DEPTH / 2 + _BACK + _LINING
	var usable := Vector2(WIDTH - 2 * _POST, CASE_TOP - 0.06 - BASE_HEIGHT - 0.04)
	var pitch := Vector2(usable.x / COLUMNS, usable.y / ROWS)
	var w := FRAME_SIZE.x
	var h := FRAME_SIZE.y
	var m := _MOULDING
	var z := back + FRAME_DEPTH / 2
	slots.resize(SLOTS)
	for row in ROWS:
		for column in COLUMNS:
			var x := -usable.x / 2 + pitch.x * (column + 0.5)
			# Frame sits a little above the middle of its cell; the plate goes under.
			var y := CASE_TOP - 0.06 - pitch.y * (row + 0.5) + 0.02
			_box(Vector3(w, m, FRAME_DEPTH), Vector3(x, y + (h - m) / 2, z), walnut)
			_box(Vector3(w, m, FRAME_DEPTH), Vector3(x, y - (h - m) / 2, z), walnut)
			_box(Vector3(m, h - 2 * m, FRAME_DEPTH), Vector3(x - (w - m) / 2, y, z), walnut)
			_box(Vector3(m, h - 2 * m, FRAME_DEPTH), Vector3(x + (w - m) / 2, y, z), walnut)
			_box(Vector3(w - 2 * m, h - 2 * m, 0.006), Vector3(x, y, back + 0.003), linen)
			# Gilt slip just inside the front of the moulding.
			const SLIP := 0.005
			var inner := Vector2(w - 2 * m, h - 2 * m)
			var slip_z := back + FRAME_DEPTH - 0.004
			_box(Vector3(inner.x, SLIP, 0.008), Vector3(x, y + (inner.y - SLIP) / 2, slip_z), gilt)
			_box(Vector3(inner.x, SLIP, 0.008), Vector3(x, y - (inner.y - SLIP) / 2, slip_z), gilt)
			_box(Vector3(SLIP, inner.y - 2 * SLIP, 0.008), Vector3(x - (inner.x - SLIP) / 2, y, slip_z), gilt)
			_box(Vector3(SLIP, inner.y - 2 * SLIP, 0.008), Vector3(x + (inner.x - SLIP) / 2, y, slip_z), gilt)
			_box(Vector3(0.08, 0.02, 0.003), Vector3(x, y - h / 2 - 0.028, back + 0.0015), brass)

			var index := column / HALF_COLUMNS * ROWS * HALF_COLUMNS + row * HALF_COLUMNS + column % HALF_COLUMNS
			var slot := Marker3D.new()
			slot.name = "Slot%02d" % index
			slot.position = Vector3(x, y, back + 0.006 + CARD_STANDOFF)
			add_child(slot)
			slots[index] = slot


## Two spotlights tucked behind the top rail, aimed down at the back of the
## case, and the strip they stand for. They cast shadows, so each frame
## throws its own shadow down the baize. Glass casts none, so some light
## spills through the sides onto the wall, as it would.
func _build_lights(colour: Color) -> void:
	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(WIDTH - 2 * _POST - 0.04, 0.006, 0.014)
	strip.mesh = strip_mesh
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(1, 0.95, 0.85)
	lit.emission_enabled = true
	lit.emission = colour
	lit.emission_energy_multiplier = 3.0
	strip.material_override = lit
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	strip.position = Vector3(0, CASE_TOP - 0.006, DEPTH / 2 - 0.05)
	add_child(strip)
	for side in [-1, 1]:
		var light := SpotLight3D.new()
		light.light_color = colour
		light.light_energy = 0.6
		light.spot_angle = 48.0
		light.spot_angle_attenuation = 2.0
		light.spot_range = 1.5
		light.spot_attenuation = 0.9
		light.light_specular = 0.3
		light.shadow_enabled = true
		light.shadow_blur = 1.5
		add_child(light)
		light.position = Vector3(side * WIDTH * 0.22, CASE_TOP - 0.02, DEPTH / 2 - 0.06)
		light.look_at_from_position(light.position,
			Vector3(side * WIDTH * 0.22, BASE_HEIGHT + 0.35, -DEPTH / 2), Vector3.UP)


## Queues a box into its material's merged mesh, so the whole cabinet draws
## in a handful of calls. Glass doesn't cast shadows.
func _box(size: Vector3, center: Vector3, material: Material, shadows := true) -> void:
	var key := [material, shadows]
	if not _parts.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_parts[key] = tool
	var mesh := BoxMesh.new()
	mesh.size = size
	(_parts[key] as SurfaceTool).append_from(mesh, 0, Transform3D(Basis(), center))


func _commit() -> void:
	for key in _parts:
		var instance := MeshInstance3D.new()
		instance.mesh = (_parts[key] as SurfaceTool).commit()
		instance.material_override = key[0]
		if not key[1]:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	_parts.clear()


static func _tinted(material: StandardMaterial3D, factor: float) -> StandardMaterial3D:
	var copy: StandardMaterial3D = material.duplicate()
	var c := copy.albedo_color
	copy.albedo_color = Color(c.r * factor, c.g * factor, c.b * factor, c.a)
	return copy


static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
