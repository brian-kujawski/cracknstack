class_name PackDisplay
extends StaticBody3D
## A stand of booster packs by the door (a prototype of buying packs): a
## wooden plinth with an open cardboard display on top, three columns of
## sealed packs standing in it, one set to a column, front pack showing.
## Click it with empty hands to take the front pack of the column you're
## aiming at; click it with a pack in hand to put the pack back.
##
## It never runs out, and its packs are free: when the last pack goes, it
## fills up again with three unlocked sets (PackContents.pick_set; it stands
## empty until a set unlocks, and the shop stocks it then). It stands in
## for the morning's deliveries until buying exists. What's on the stand
## isn't saved; a loaded game stocks it afresh.
##
## Its origin is on the floor under the middle of the plinth, and it faces
## local +Z.

const PLINTH := Vector3(0.42, 0.9, 0.32)
## The display box on top: its floor, walls and the lid standing up behind.
const TRAY := Vector3(0.32, 0.055, 0.24)
const LID := Vector2(0.32, 0.17)
const LID_LEAN := deg_to_rad(12.0)
const WALL := 0.006
const COLUMNS := 3
const PER_COLUMN := 8
const COLUMN_STEP := 0.1
## Packs stand leaning back this far, this far apart front to back.
const PACK_LEAN := deg_to_rad(14.0)
const PACK_STEP := 0.019
const CARDBOARD := Color(0.13, 0.11, 0.16)

## The packs in each column, front first.
var columns: Array[Array] = []
var _rng := RandomNumberGenerator.new()


## Builds the plinth and the display, empty (see stock).
func build(wood: Material, random_seed := 0) -> void:
	_rng.seed = random_seed
	var plinth := MeshInstance3D.new()
	plinth.mesh = _box(PLINTH)
	plinth.material_override = wood
	plinth.position.y = PLINTH.y / 2
	add_child(plinth)
	var board := StandardMaterial3D.new()
	board.albedo_color = CARDBOARD
	board.roughness = 0.8
	var top := PLINTH.y
	_part(Vector3(TRAY.x, WALL, TRAY.z), Vector3(0, top + WALL / 2, 0), board)
	_part(Vector3(TRAY.x, TRAY.y, WALL), Vector3(0, top + TRAY.y / 2, TRAY.z / 2 - WALL / 2), board)
	for side in [-1, 1]:
		_part(Vector3(WALL, TRAY.y, TRAY.z), Vector3(side * (TRAY.x / 2 - WALL / 2), top + TRAY.y / 2, 0), board)
	var lid := _part(Vector3(LID.x, LID.y, WALL), Vector3.ZERO, board)
	lid.rotation.x = -LID_LEAN
	lid.position = Vector3(0, top + LID.y / 2 * cos(LID_LEAN), -TRAY.z / 2 - LID.y / 2 * sin(LID_LEAN))
	var title := Label3D.new()
	title.text = "BOOSTER PACKS"
	title.font = BinderLettering.FONT
	title.font_size = 64
	title.pixel_size = 0.0004
	title.modulate = Color(0.95, 0.78, 0.38)
	title.outline_size = 0
	title.shaded = true
	title.position = Vector3(0, LID.y * 0.22, WALL / 2 + 0.0005)
	lid.add_child(title)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(PLINTH.x, PLINTH.y + LID.y, PLINTH.z)
	shape.shape = box
	shape.position.y = box.size.y / 2
	add_child(shape)


## Fills every column with a full run of packs of a new set.
func stock() -> void:
	for column in columns:
		for pack: BoosterPack in column:
			pack.queue_free()
	columns.clear()
	for c in COLUMNS:
		columns.append([])
		var code := PackContents.pick_set(_rng)
		if code.is_empty():
			continue
		for i in PER_COLUMN:
			var pack := BoosterPack.new()
			pack.setup(code)
			add_child(pack)
			columns[c].append(pack)
		_line_up(c)


func pack_count() -> int:
	var count := 0
	for column in columns:
		count += column.size()
	return count


## The column under a point (global), or the nearest one that has packs;
## -1 if none have.
func column_at(point: Vector3) -> int:
	var x := to_local(point).x
	var best := -1
	for c in columns.size():
		if columns[c].is_empty():
			continue
		if best < 0 or absf(_column_x(c) - x) < absf(_column_x(best) - x):
			best = c
	return best


## Takes the front pack of the column at `point` off the stand, still in
## the tree where it stood (the caller moves it). Restocks when the stand's
## empty. Null if there's nothing to take.
func take(point: Vector3) -> BoosterPack:
	var c := column_at(point)
	if c < 0:
		return null
	var pack: BoosterPack = columns[c].pop_front()
	_line_up(c)
	if pack_count() == 0:
		stock.call_deferred()
	return pack


## Puts a pack back at the front of a column of its own set, or else of the
## column at `point`. The pack is moved here (reparented).
func give_back(pack: BoosterPack, point: Vector3) -> void:
	var c := -1
	for i in columns.size():
		if not columns[i].is_empty() and columns[i][0].set_code == pack.set_code:
			c = i
	if c < 0:
		c = clampi(column_at(point), 0, COLUMNS - 1)
	if pack.get_parent() != null:
		pack.get_parent().remove_child(pack)
	add_child(pack)
	pack.set_tear(0.0)
	columns[c].push_front(pack)
	_line_up(c)


## Where pack `index` of a column stands, in the stand's space.
func slot_transform(column: int, index: int) -> Transform3D:
	var lean := Basis(Vector3.RIGHT, -PACK_LEAN)
	var foot := Vector3(_column_x(column), PLINTH.y + WALL, TRAY.z / 2 - 0.03 - index * PACK_STEP)
	return Transform3D(lean, foot + lean * Vector3(0, BoosterPack.SIZE.y / 2, 0))


func _line_up(column: int) -> void:
	for i in columns[column].size():
		columns[column][i].transform = slot_transform(column, i)


func _column_x(column: int) -> float:
	return (column - (COLUMNS - 1) / 2.0) * COLUMN_STEP


func _part(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = _box(size)
	part.material_override = material
	part.position = at
	add_child(part)
	return part


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh
