class_name PileWorld
extends Node3D
## Owns every card lying on the floor (plan §4.4). Cards are not nodes: they
## live in packed arrays indexed by card id (one instance per card), and are
## drawn by one MultiMesh per floor chunk.
##
## The pile is static and deliberately klunky. Walking never moves a card.
## The only movement is the one-step gap fill when a card is picked up: the
## few cards that directly overlapped it slide a little toward the gap, and
## nothing else reacts. No physics, no chains.

const CARD_SIZE := Vector2(0.063, 0.088) # metres, real card size
const CARD_THICKNESS := 0.0006
const CHUNK_SIZE := 2.0
## Picking grid: each card is filed under the cell holding its centre. Cells
## are wider than half a card's diagonal, so a 3×3 query finds every card
## that could cover a point.
const GRID_CELL := 0.1
## Height map resolution used to stack cards on top of each other.
const HEIGHT_CELL := 0.05
const GAP_FILL_MAX_CARDS := 6
const GAP_FILL_PULL := 0.35 # fraction of the way toward the gap
const GAP_FILL_SECONDS := 0.18
const OVERLAP_DISTANCE := 0.075

enum State { ON_FLOOR, HELD }

var bounds: Rect2

var _positions := PackedVector3Array()
var _rotations := PackedFloat32Array()
var _face_up := PackedByteArray()
var _states := PackedByteArray()
var _set_numbers := PackedInt32Array()
var _accents := PackedColorArray()

var _chunk_columns := 0
var _chunks: Array[MultiMeshInstance3D] = []
var _chunk_cards: Array[PackedInt32Array] = []
var _chunk_of := PackedInt32Array()
var _slot_of := PackedInt32Array()

var _grid_columns := 0
var _grid_rows := 0
var _grid: Array[PackedInt32Array] = []

var _height_columns := 0
var _heights := PackedFloat32Array()

var _highlighted := -1
var _material: ShaderMaterial
var _mesh: PlaneMesh

## card id -> {from: Vector3, to: Vector3, t: float}
var _slides := {}


## Scatters every card in the database over `floor_bounds`, avoiding the
## footprints in `obstacles`. Binders are placed separately by spawn_binders().
func build(floor_bounds: Rect2, obstacles: Array[Rect2], random_seed: int) -> void:
	bounds = floor_bounds
	var count := CardDatabase.card_count()
	_allocate(count)
	_build_set_lookup()
	var placements := PileGenerator.scatter(count, bounds, obstacles, random_seed)
	# Drop cards in a random order so every set ends up mixed through the layers.
	var order := range(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed + 1
	for i in range(count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: int = order[i]
		order[i] = order[j]
		order[j] = swap
	for id in order:
		var placement := placements[id]
		_face_up[id] = 1 if placement.face_up else 0
		_put_on_floor(id, placement.position, placement.rotation)
	for c in _chunks.size():
		_rebuild_chunk(c)


## Lays each binder volume somewhere on top of the pile.
func spawn_binders(obstacles: Array[Rect2], random_seed: int) -> void:
	var binders := CardDatabase.all_binders()
	var placements := PileGenerator.scatter(binders.size(), bounds, obstacles, random_seed + 2)
	for i in binders.size():
		var binder := FloorBinder.new()
		binder.setup(binders[i], CardDatabase.get_set(binders[i].set_code).accent_color)
		var p := placements[i].position
		binder.position = Vector3(p.x, height_at(p) + FloorBinder.THICKNESS / 2, p.y)
		binder.rotation.y = placements[i].rotation
		add_child(binder)


func card_count_on_floor() -> int:
	return _states.count(State.ON_FLOOR)


func card_position(id: int) -> Vector3:
	return _positions[id]


func is_on_floor(id: int) -> bool:
	return _states[id] == State.ON_FLOOR


## The highest card on the floor covering this floor point, or -1.
func top_card_at(point: Vector3) -> int:
	var p := Vector2(point.x, point.z)
	var best := -1
	var best_height := -INF
	for id in _cards_near(p):
		if _states[id] != State.ON_FLOOR or not _covers(id, p):
			continue
		if _positions[id].y > best_height:
			best_height = _positions[id].y
			best = id
	return best


## Lifts a card out of the pile. Its overlapping neighbours slide toward the
## gap (one step, see class comment).
func pick_up(id: int) -> void:
	if _states[id] != State.ON_FLOOR:
		return
	if id == _highlighted:
		set_highlight(-1)
	_slides.erase(id)
	var gap := Vector2(_positions[id].x, _positions[id].z)
	_states[id] = State.HELD
	_grid_remove(id)
	_chunk_remove(id)
	_start_gap_fill(gap)


## Puts a held card back down on top of whatever is at `point`.
func drop(id: int, point: Vector3, rotation_y: float) -> void:
	if _states[id] != State.HELD:
		return
	_states[id] = State.ON_FLOOR
	var p := Vector2(clampf(point.x, bounds.position.x, bounds.end.x), clampf(point.z, bounds.position.y, bounds.end.y))
	_face_up[id] = 1
	_put_on_floor(id, p, rotation_y)
	_rebuild_chunk(_chunk_of[id])


func set_highlight(id: int) -> void:
	if id == _highlighted:
		return
	var previous := _highlighted
	_highlighted = id
	if previous >= 0 and _states[previous] == State.ON_FLOOR:
		_update_instance_custom(previous)
	if id >= 0:
		_update_instance_custom(id)


## Top of the stack at a floor point (used to rest binders and dropped cards).
func height_at(p: Vector2) -> float:
	return _heights[_height_index(p)]


func _process(delta: float) -> void:
	if _slides.is_empty():
		return
	var finished: Array[int] = []
	for id in _slides:
		var slide: Dictionary = _slides[id]
		slide.t = minf(1.0, slide.t + delta / GAP_FILL_SECONDS)
		var eased: float = 1.0 - pow(1.0 - slide.t, 3.0)
		_positions[id] = (slide.from as Vector3).lerp(slide.to, eased)
		_chunks[_chunk_of[id]].multimesh.set_instance_transform(_slot_of[id], _card_transform(id))
		if slide.t >= 1.0:
			finished.append(id)
	for id in finished:
		_slides.erase(id)
		_grid_remove(id)
		_grid_add(id)


func _start_gap_fill(gap: Vector2) -> void:
	var neighbours: Array[int] = []
	for id in _cards_near(gap):
		if _states[id] == State.ON_FLOOR and not _slides.has(id) \
				and Vector2(_positions[id].x, _positions[id].z).distance_to(gap) < OVERLAP_DISTANCE:
			neighbours.append(id)
	neighbours.sort_custom(func(a: int, b: int) -> bool:
		return Vector2(_positions[a].x, _positions[a].z).distance_squared_to(gap) \
			< Vector2(_positions[b].x, _positions[b].z).distance_squared_to(gap))
	for id in neighbours.slice(0, GAP_FILL_MAX_CARDS):
		var from := _positions[id]
		var to := from.lerp(Vector3(gap.x, from.y, gap.y), GAP_FILL_PULL)
		_slides[id] = {"from": from, "to": to, "t": 0.0}


func _allocate(count: int) -> void:
	_positions.resize(count)
	_rotations.resize(count)
	_face_up.resize(count)
	_states.resize(count)
	_states.fill(State.ON_FLOOR)
	_chunk_of.resize(count)
	_slot_of.resize(count)

	_chunk_columns = ceili(bounds.size.x / CHUNK_SIZE)
	var chunk_rows := ceili(bounds.size.y / CHUNK_SIZE)
	_mesh = PlaneMesh.new()
	_mesh.size = CARD_SIZE
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/floor_card.gdshader")
	for c in _chunk_columns * chunk_rows:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.use_custom_data = true
		multimesh.mesh = _mesh
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = _material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		_chunks.append(instance)
		_chunk_cards.append(PackedInt32Array())

	_grid_columns = ceili(bounds.size.x / GRID_CELL)
	_grid_rows = ceili(bounds.size.y / GRID_CELL)
	_grid.resize(_grid_columns * _grid_rows)
	for i in _grid.size():
		_grid[i] = PackedInt32Array()

	_height_columns = ceili(bounds.size.x / HEIGHT_CELL)
	_heights.resize(_height_columns * ceili(bounds.size.y / HEIGHT_CELL))
	_heights.fill(0.0)


func _build_set_lookup() -> void:
	var set_numbers := {}
	var sets := CardDatabase.sets_in_shelf_order()
	for i in sets.size():
		set_numbers[sets[i].code] = i + 1
	_set_numbers.resize(CardDatabase.card_count())
	_accents.resize(CardDatabase.card_count())
	for id in CardDatabase.card_count():
		var card := CardDatabase.get_card(id)
		_set_numbers[id] = set_numbers[card.set_code]
		_accents[id] = CardDatabase.get_set(card.set_code).accent_color


## Places a card on top of the stack at p and files it in grid and chunk.
## The caller rebuilds the chunk's buffer.
func _put_on_floor(id: int, p: Vector2, rotation_y: float) -> void:
	var footprint := _footprint_points(p, rotation_y)
	var top := 0.0
	for q in footprint:
		top = maxf(top, _heights[_height_index(q)])
	var y := top + CARD_THICKNESS
	for q in footprint:
		_heights[_height_index(q)] = y
	_positions[id] = Vector3(p.x, y, p.y)
	_rotations[id] = rotation_y
	_grid_add(id)
	var chunk := _chunk_index(p)
	_chunk_of[id] = chunk
	var cards := _chunk_cards[chunk]
	_slot_of[id] = cards.size()
	cards.append(id)
	_chunk_cards[chunk] = cards


func _footprint_points(p: Vector2, rotation_y: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var half := CARD_SIZE / 2
	for fx in [-1.0, 0.0, 1.0]:
		for fz in [-1.0, 0.0, 1.0]:
			# Same rotation convention as Basis(Vector3.UP, rotation_y).
			var local := Vector2(fx * half.x, fz * half.y)
			points.append(p + Vector2(
				local.x * cos(rotation_y) + local.y * sin(rotation_y),
				-local.x * sin(rotation_y) + local.y * cos(rotation_y)))
	return points


func _covers(id: int, p: Vector2) -> bool:
	var d := p - Vector2(_positions[id].x, _positions[id].z)
	var r := _rotations[id]
	# Inverse of the footprint rotation above.
	var local := Vector2(d.x * cos(r) - d.y * sin(r), d.x * sin(r) + d.y * cos(r))
	return absf(local.x) <= CARD_SIZE.x / 2 and absf(local.y) <= CARD_SIZE.y / 2


func _card_transform(id: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, _rotations[id]), _positions[id])


func _instance_custom(id: int) -> Color:
	var card := CardDatabase.get_card(id)
	var rarity_and_highlight := float(card.rarity) + (4.0 if id == _highlighted else 0.0)
	return Color(card.collector_number, _set_numbers[id], rarity_and_highlight, _face_up[id])


func _update_instance_custom(id: int) -> void:
	_chunks[_chunk_of[id]].multimesh.set_instance_custom_data(_slot_of[id], _instance_custom(id))


func _rebuild_chunk(chunk: int) -> void:
	var cards := _chunk_cards[chunk]
	var multimesh := _chunks[chunk].multimesh
	multimesh.instance_count = cards.size()
	if cards.is_empty():
		return
	var buffer := PackedFloat32Array()
	buffer.resize(cards.size() * 20)
	var i := 0
	for id in cards:
		var xf := _card_transform(id)
		var b := xf.basis
		var o := xf.origin
		var accent := _accents[id]
		var custom := _instance_custom(id)
		buffer[i] = b.x.x; buffer[i + 1] = b.y.x; buffer[i + 2] = b.z.x; buffer[i + 3] = o.x
		buffer[i + 4] = b.x.y; buffer[i + 5] = b.y.y; buffer[i + 6] = b.z.y; buffer[i + 7] = o.y
		buffer[i + 8] = b.x.z; buffer[i + 9] = b.y.z; buffer[i + 10] = b.z.z; buffer[i + 11] = o.z
		buffer[i + 12] = accent.r; buffer[i + 13] = accent.g; buffer[i + 14] = accent.b; buffer[i + 15] = 1.0
		buffer[i + 16] = custom.r; buffer[i + 17] = custom.g; buffer[i + 18] = custom.b; buffer[i + 19] = custom.a
		i += 20
	multimesh.buffer = buffer


func _chunk_remove(id: int) -> void:
	var chunk := _chunk_of[id]
	var cards := _chunk_cards[chunk]
	var slot := _slot_of[id]
	var last := cards[cards.size() - 1]
	cards[slot] = last
	_slot_of[last] = slot
	cards.resize(cards.size() - 1)
	_chunk_cards[chunk] = cards
	_rebuild_chunk(chunk)


func _chunk_index(p: Vector2) -> int:
	var local := p - bounds.position
	var column := clampi(int(local.x / CHUNK_SIZE), 0, _chunk_columns - 1)
	var row := clampi(int(local.y / CHUNK_SIZE), 0, _chunks.size() / _chunk_columns - 1)
	return row * _chunk_columns + column


func _grid_cell(p: Vector2) -> Vector2i:
	var local := p - bounds.position
	return Vector2i(clampi(int(local.x / GRID_CELL), 0, _grid_columns - 1), clampi(int(local.y / GRID_CELL), 0, _grid_rows - 1))


func _grid_add(id: int) -> void:
	var cell := _grid_cell(Vector2(_positions[id].x, _positions[id].z))
	var index := cell.y * _grid_columns + cell.x
	var cards := _grid[index]
	cards.append(id)
	_grid[index] = cards


func _grid_remove(id: int) -> void:
	var cell := _grid_cell(Vector2(_positions[id].x, _positions[id].z))
	var index := cell.y * _grid_columns + cell.x
	var cards := _grid[index]
	var at := cards.find(id)
	if at >= 0:
		cards.remove_at(at)
		_grid[index] = cards


func _cards_near(p: Vector2) -> PackedInt32Array:
	var center := _grid_cell(p)
	var result := PackedInt32Array()
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := center.x + dx
			var y := center.y + dy
			if x >= 0 and y >= 0 and x < _grid_columns and y < _grid_rows:
				result.append_array(_grid[y * _grid_columns + x])
	return result


func _height_index(p: Vector2) -> int:
	var local := p - bounds.position
	var columns := _height_columns
	var rows := _heights.size() / columns
	return clampi(int(local.y / HEIGHT_CELL), 0, rows - 1) * columns + clampi(int(local.x / HEIGHT_CELL), 0, columns - 1)
