class_name PackCrate
extends StaticBody3D
## The INCOMING crate just inside the door: a low wooden crate, open at the
## top, that Card Shop booster packs (and Howling Mine's) are delivered
## into, lying flat in neat stacks. It mirrors the shipping corner's crate on
## the door's other side.
##
## Its origin is on the floor at the crate's middle; packs lie with their
## tops toward local +x (built against the right-hand wall, unturned, so
## they read upright as you walk in). The packs are loose BoosterPacks on
## the pile, like any put down: the crate only says where the next one goes
## (next_pack_pose), counting what's actually in each stack, so a stack you
## took packs from fills up again first, and nothing needs saving.
##
## Only the boards collide (thin walls and a floor), so you aim past the rim
## at the packs inside.

## Stacks: COLUMNS across the crate (along z, a pack's width each), ROWS
## along x (a pack's length each), with GAP between them and the boards.
const COLUMNS := 4
const ROWS := 2
const GAP := 0.012
const BOARD := 0.018
## The boards stand this high (outside); a stack stops at STACK_MAX packs,
## a little under the rim.
const HEIGHT := 0.13
const STACK_MAX := 16
## How far a delivered pack may sit off its stack's centre, and off square.
const JITTER := 0.004
const JITTER_YAW := 0.06
const LETTERING := Color(0.95, 0.75, 0.1)

## Inside size: x along a pack's length, z across.
static var inside := Vector2(
	ROWS * BoosterPack.SIZE.y + (ROWS + 1) * GAP,
	COLUMNS * BoosterPack.SIZE.x + (COLUMNS + 1) * GAP)


## Builds the crate in `wood` (the furniture's).
func build(wood: Material) -> void:
	name = "PackCrate"
	collision_layer = 1
	collision_mask = 0
	var outside := outside_size()
	_board(Vector3(outside.x, BOARD, outside.y), Vector3(0, BOARD / 2, 0), wood)
	for side in [-1, 1]:
		_board(Vector3(outside.x, HEIGHT, BOARD), Vector3(0, HEIGHT / 2, side * (outside.y - BOARD) / 2), wood)
		_board(Vector3(BOARD, HEIGHT, inside.y), Vector3(side * (outside.x - BOARD) / 2, HEIGHT / 2, 0), wood)
	var words := Label3D.new()
	words.name = "Incoming"
	words.text = "INCOMING"
	words.font = BinderLettering.FONT
	words.font_size = 64
	words.outline_size = 0
	words.modulate = LETTERING
	words.shaded = true
	words.pixel_size = 0.0007
	# On the board that faces into the room (-x).
	words.rotation.y = -PI / 2
	words.position = Vector3(-outside.x / 2 - 0.001, HEIGHT * 0.55, 0)
	add_child(words)


## The crate's outside footprint: x, z.
static func outside_size() -> Vector2:
	return inside + Vector2.ONE * 2 * BOARD


## The floor rect (x, z) the crate stands on, in the parent's space, to keep
## cards off it.
func footprint() -> Rect2:
	var size := outside_size()
	return Rect2(Vector2(position.x, position.z) - size / 2, size)


## How many packs there are, in all, among `packs` (global positions are
## read) lying in the crate.
func pack_count(packs: Array) -> int:
	var count := 0
	for n in _stack_counts(packs):
		count += n
	return count


## Where the next delivered pack lies (global, BoosterPack.lying_pose: its
## underside at the origin), on the lowest stack of the crate (the first
## one, front to back and door side first, of those tied), given every
## loose pack about (`packs`); null once every stack is full. `rng` turns
## it a touch off square.
func next_pack_pose(packs: Array, rng: RandomNumberGenerator) -> Variant:
	var counts := _stack_counts(packs)
	var best := -1
	for i in counts.size():
		if counts[i] < STACK_MAX and (best < 0 or counts[i] < counts[best]):
			best = i
	if best < 0:
		return null
	var centre := _stack_centre(best)
	var local := Vector3(centre.x + rng.randf_range(-JITTER, JITTER), BOARD + counts[best] * BoosterPack.THICKNESS,
		centre.y + rng.randf_range(-JITTER, JITTER))
	var yaw := global_rotation.y - PI / 2 + rng.randf_range(-JITTER_YAW, JITTER_YAW)
	return BoosterPack.lying_pose(to_global(local), yaw)


## Packs lying in each stack, in stack order.
func _stack_counts(packs: Array) -> Array[int]:
	var counts: Array[int] = []
	counts.resize(ROWS * COLUMNS)
	counts.fill(0)
	for pack in packs:
		if not is_instance_valid(pack) or not pack is BoosterPack or not (pack as BoosterPack).is_lying():
			continue
		var at := to_local((pack as Node3D).global_position)
		if absf(at.x) > inside.x / 2 or absf(at.z) > inside.y / 2 or at.y > HEIGHT + STACK_MAX * BoosterPack.THICKNESS:
			continue
		var row := clampi(int((at.x + inside.x / 2) / (inside.x / ROWS)), 0, ROWS - 1)
		var column := clampi(int((at.z + inside.y / 2) / (inside.y / COLUMNS)), 0, COLUMNS - 1)
		counts[_stack_index(row, column)] += 1
	return counts


## Stack order: the row nearer the room first (lower x), and in each row
## the column nearest the door (higher z) first.
func _stack_index(row: int, column: int) -> int:
	return row * COLUMNS + (COLUMNS - 1 - column)


## A stack's centre (local x, z).
func _stack_centre(index: int) -> Vector2:
	var row := index / COLUMNS
	var column := COLUMNS - 1 - index % COLUMNS
	return Vector2(
		-inside.x / 2 + GAP + BoosterPack.SIZE.y / 2 + row * (BoosterPack.SIZE.y + GAP),
		-inside.y / 2 + GAP + BoosterPack.SIZE.x / 2 + column * (BoosterPack.SIZE.x + GAP))


func _board(size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = material
	add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = at
	add_child(shape)
