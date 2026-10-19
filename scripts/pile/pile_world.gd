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
## Three times a real card (about 0.3 mm): real thickness is too thin for a
## pile to read as a pile.
const CARD_THICKNESS := 0.0018
const CHUNK_SIZE := 2.0
## Picking grid: each card is filed under the cell holding its centre. Cells
## are wider than half a card's diagonal, so a 3×3 query finds every card
## that could cover a point.
const GRID_CELL := 0.1
## Height map resolution used to stack cards on top of each other. Fine
## enough that a card only rests on cards that are really under it, rather
## than on anything nearby.
const HEIGHT_CELL := 0.015
const GAP_FILL_MAX_CARDS := 6
const GAP_FILL_PULL := 0.35 # fraction of the way toward the gap
const GAP_FILL_SECONDS := 0.18
const OVERLAP_DISTANCE := 0.075
## Collision layer of the pile's surface: a coarse height field that only
## binders collide with, so they can rest on the cards.
const SURFACE_LAYER := 8
## Surface grid: one height per this many height map cells (the highest).
const SURFACE_STRIDE := 3

enum State { ON_FLOOR, HELD }

var bounds: Rect2
## Floor footprints nothing may overlap (walls are the edge of `bounds`).
var obstacles: Array[Rect2] = []
## Every binder in the store, in shelf order (wherever each one is now).
var binders: Array[Binder] = []

var _positions := PackedVector3Array()
var _rotations := PackedFloat32Array()
var _face_up := PackedByteArray()
var _states := PackedByteArray()
var _set_numbers := PackedInt32Array()
var _accents := PackedColorArray()
## Per card: its slot in CardDatabase.face_atlas, or -1 for a placeholder face.
var _faces := PackedFloat32Array()

var _chunk_columns := 0
var _chunks: Array[MultiMeshInstance3D] = []
var _chunk_cards: Array[PackedInt32Array] = []
var _chunk_of := PackedInt32Array()
var _slot_of := PackedInt32Array()

var _grid_columns := 0
var _grid_rows := 0
var _grid: Array[PackedInt32Array] = []
## Per card: the grid cell it's filed under, or -1. Kept so a card that slid
## during gap fill is removed from the cell it was filed in, not the one it's
## over now.
var _grid_cell_of := PackedInt32Array()

var _height_columns := 0
var _heights := PackedFloat32Array()

var _highlighted := -1
var _material: ShaderMaterial
var _mesh: ArrayMesh

## card id -> {from: Vector3, to: Vector3, t: float}
var _slides := {}

var _surface: HeightMapShape3D
var _surface_columns := 0
var _surface_rows := 0
var _surface_heights := PackedFloat32Array()
## Surface cells whose height map cells changed since the last update.
var _surface_dirty := {}


## Scatters every card in the database over `floor_bounds`, avoiding the
## footprints in `obstacles`. Binders are placed separately by spawn_binders().
func build(floor_bounds: Rect2, floor_obstacles: Array[Rect2], random_seed: int) -> void:
	bounds = floor_bounds
	obstacles = floor_obstacles
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
	_build_surface()


## Drops each binder volume closed somewhere on top of the pile, with room to
## open it where it lies. Where binders land on each other they start a
## little apart, one above the other, and physics settles them.
func spawn_binders(random_seed: int) -> void:
	var ranges := CardDatabase.all_binders()
	var placements := PileGenerator.scatter(ranges.size(), bounds, obstacles, random_seed + 2, Binder.OPEN_HALF_FOOTPRINT)
	var reach := Binder.COVER.length() # centres closer than this may overlap
	for i in ranges.size():
		var binder := Binder.new()
		binder.setup(ranges[i], CardDatabase.get_set(ranges[i].set_code).accent_color, self)
		var p := placements[i].position
		var y := height_under(p, Vector2(Binder.COVER.x, Binder.COVER.y) / 2, placements[i].rotation) + 0.01
		for other in binders:
			if Vector2(other.position.x, other.position.z).distance_to(p) < reach:
				y = maxf(y, other.position.y + Binder.THICKNESS + 0.01)
		add_child(binder)
		binder.rotation = Vector3(0, placements[i].rotation, 0)
		binder.position = Vector3(p.x, y, p.y)
		binder.state = Binder.State.CLOSED
		binder.freeze = false
		binders.append(binder)


func card_count_on_floor() -> int:
	return _states.count(State.ON_FLOOR)


func card_position(id: int) -> Vector3:
	return _positions[id]


func is_on_floor(id: int) -> bool:
	return _states[id] == State.ON_FLOOR


## Where a floor card lies, as a global pose for a card quad (see Glide).
func card_pose(id: int) -> Transform3D:
	return Glide.flat_card(to_global(_positions[id]), global_basis * Basis(Vector3.UP, _rotations[id]), _face_up[id] == 1)


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
	_refresh_cells(_footprint_cells(gap, _rotations[id]))
	_start_gap_fill(gap)


## Takes card `id` from wherever it lies: the floor, a table, or another
## binder's pocket it was misplaced in. Returns the global card pose it left
## (see Glide), or null if it can't be had (in hand, in flight, or locked
## into its own pocket).
func take_from_anywhere(id: int):
	if is_on_floor(id):
		var from := card_pose(id)
		pick_up(id)
		return from
	for child in get_children():
		if child is LooseCard and child.card_id == id and not child.is_queued_for_deletion():
			var from: Transform3D = child.card_pose()
			child.queue_free()
			return from
	for binder in binders:
		for pocket in binder.contents.capacity():
			if binder.contents.card_at(pocket) == id and not binder.contents.is_locked(pocket):
				var from := binder.pocket_pose(pocket)
				binder.take(pocket)
				return from
	return null


## Lays a held card on top of whatever is at `point`, face up or down.
func drop(id: int, point: Vector3, rotation_y: float, face_up := true) -> void:
	if _states[id] != State.HELD:
		return
	_states[id] = State.ON_FLOOR
	var p := clear_point(Vector2(point.x, point.z), CARD_SIZE / 2, rotation_y)
	_face_up[id] = 1 if face_up else 0
	_put_on_floor(id, p, rotation_y)
	_rebuild_chunk(_chunk_of[id])


## Where drop() would lay a card aimed at `point`, as a global pose for a
## card quad (see Glide).
func drop_pose(point: Vector3, rotation_y: float) -> Transform3D:
	var p := clear_point(Vector2(point.x, point.z), CARD_SIZE / 2, rotation_y)
	var top := 0.0
	for cell in _footprint_cells(p, rotation_y):
		top = maxf(top, _heights[cell])
	return Glide.flat_card(to_global(Vector3(p.x, top + CARD_THICKNESS, p.y)),
		global_basis * Basis(Vector3.UP, rotation_y))


func set_highlight(id: int) -> void:
	if id == _highlighted:
		return
	var previous := _highlighted
	_highlighted = id
	if previous >= 0 and _states[previous] == State.ON_FLOOR:
		_update_instance_custom(previous)
	if id >= 0:
		_update_instance_custom(id)


## The nearest floor point to p where a footprint (half size, turned by
## rotation_y) is inside the walls and clear of every obstacle.
func clear_point(p: Vector2, half_size: Vector2, rotation_y: float) -> Vector2:
	return PileGenerator.nearest_clear(p, half_size, rotation_y, bounds, obstacles)


## Top of the stack at a floor point (used to rest binders and dropped cards).
func height_at(p: Vector2) -> float:
	return _heights[_height_index(p)]


## Top of the pile anywhere under a rectangle (centre, half size, turned by
## rotation_y), so a binder or stack laid there rests on the highest card.
func height_under(center: Vector2, half_size: Vector2, rotation_y: float) -> float:
	var steps := Vector2i(ceili(half_size.x * 2 / HEIGHT_CELL) + 1, ceili(half_size.y * 2 / HEIGHT_CELL) + 1)
	var top := 0.0
	for i in steps.x:
		for j in steps.y:
			var local := Vector2(lerpf(-half_size.x, half_size.x, float(i) / (steps.x - 1)),
				lerpf(-half_size.y, half_size.y, float(j) / (steps.y - 1)))
			top = maxf(top, _heights[_height_index(center + _rotated(local, rotation_y))])
	return top


func _physics_process(_delta: float) -> void:
	if not _surface_dirty.is_empty():
		_update_surface()


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
		var from: Vector3 = _slides[id].from
		_slides.erase(id)
		_grid_remove(id)
		_grid_add(id)
		var cells := _footprint_cells(Vector2(from.x, from.z), _rotations[id])
		cells.append_array(_footprint_cells(Vector2(_positions[id].x, _positions[id].z), _rotations[id]))
		_refresh_cells(cells)


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
		if PileGenerator.footprint_clear(Vector2(to.x, to.z), CARD_SIZE / 2, _rotations[id], bounds, obstacles):
			_slides[id] = {"from": from, "to": to, "t": 0.0}


func _allocate(count: int) -> void:
	_positions.resize(count)
	_rotations.resize(count)
	_face_up.resize(count)
	_states.resize(count)
	_states.fill(State.ON_FLOOR)
	_chunk_of.resize(count)
	_slot_of.resize(count)
	_grid_cell_of.resize(count)
	_grid_cell_of.fill(-1)

	_chunk_columns = ceili(bounds.size.x / CHUNK_SIZE)
	var chunk_rows := ceili(bounds.size.y / CHUNK_SIZE)
	_mesh = _card_mesh()
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/floor_card.gdshader")
	if CardDatabase.face_atlas != null:
		CardDatabase.face_atlas.apply(_material)
	CardDatabase.apply_back(_material)
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
	_faces.resize(CardDatabase.card_count())
	for id in CardDatabase.card_count():
		var card := CardDatabase.get_card(id)
		_faces[id] = card.face_index
		_set_numbers[id] = set_numbers[card.set_code]
		_accents[id] = CardDatabase.get_set(card.set_code).accent_color


## The coarse collision surface binders rest on: each surface cell holds
## the highest of the SURFACE_STRIDE × SURFACE_STRIDE height map cells it
## covers, so the surface never dips below a card.
func _build_surface() -> void:
	var rows := _heights.size() / _height_columns
	_surface_columns = ceili(float(_height_columns) / SURFACE_STRIDE)
	_surface_rows = ceili(float(rows) / SURFACE_STRIDE)
	_surface_heights.resize(_surface_columns * _surface_rows)
	_surface_heights.fill(0.0)
	for cell in _heights.size():
		var h := _heights[cell]
		if h > 0.0:
			var index := (cell / _height_columns / SURFACE_STRIDE) * _surface_columns + (cell % _height_columns) / SURFACE_STRIDE
			_surface_heights[index] = maxf(_surface_heights[index], h)
	_surface = HeightMapShape3D.new()
	_surface.map_width = _surface_columns
	_surface.map_depth = _surface_rows
	_surface.map_data = _surface_heights
	var spacing := SURFACE_STRIDE * HEIGHT_CELL
	var shape := CollisionShape3D.new()
	shape.shape = _surface
	# Heights sit at surface cell centres; the shape is centred on its node
	# and one unit per sample, so scale it down to the cell spacing.
	shape.scale = Vector3(spacing, 1.0, spacing)
	shape.position = Vector3(
		bounds.position.x + spacing * _surface_columns / 2.0,
		0.0,
		bounds.position.y + spacing * _surface_rows / 2.0)
	var body := StaticBody3D.new()
	body.name = "Surface"
	body.collision_layer = SURFACE_LAYER
	body.collision_mask = 0
	body.add_child(shape)
	add_child(body)
	_surface_dirty.clear()


func _mark_surface_dirty(cell: int) -> void:
	_surface_dirty[(cell / _height_columns / SURFACE_STRIDE) * _surface_columns + (cell % _height_columns) / SURFACE_STRIDE] = true


## Recomputes the surface cells under changed cards and wakes any binder
## resting there, so it settles onto the new surface.
func _update_surface() -> void:
	if _surface == null:
		_surface_dirty.clear()
		return
	var rows := _heights.size() / _height_columns
	var spacing := SURFACE_STRIDE * HEIGHT_CELL
	var changed := Rect2()
	for index in _surface_dirty:
		var sx: int = index % _surface_columns
		var sy: int = index / _surface_columns
		var top := 0.0
		for y in range(sy * SURFACE_STRIDE, mini((sy + 1) * SURFACE_STRIDE, rows)):
			for x in range(sx * SURFACE_STRIDE, mini((sx + 1) * SURFACE_STRIDE, _height_columns)):
				top = maxf(top, _heights[y * _height_columns + x])
		_surface_heights[index] = top
		var cell_rect := Rect2(bounds.position + Vector2(sx, sy) * spacing, Vector2(spacing, spacing))
		changed = cell_rect if changed.size == Vector2.ZERO else changed.merge(cell_rect)
	_surface_dirty.clear()
	_surface.map_data = _surface_heights
	var near := changed.grow(Binder.COVER.length() / 2)
	for binder in binders:
		if binder.state == Binder.State.CLOSED and binder.get_parent() == self \
				and near.has_point(Vector2(binder.position.x, binder.position.z)):
			binder.sleeping = false


## A card with thickness: the face on top (a PlaneMesh, so floor_card's UVs
## still apply) and four edges running down CARD_THICKNESS below it. Edge
## vertices get UV (-1, -1) so the shader can paint them as card edge.
static func _card_mesh() -> ArrayMesh:
	var plane := PlaneMesh.new()
	plane.size = CARD_SIZE
	var arrays := plane.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var half := CARD_SIZE / 2
	var corners := [Vector3(-half.x, 0, -half.y), Vector3(half.x, 0, -half.y), Vector3(half.x, 0, half.y), Vector3(-half.x, 0, half.y)]
	var down := Vector3(0, -CARD_THICKNESS, 0)
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var normal := Vector3(a.x + b.x, 0, a.z + b.z).normalized()
		var first := vertices.size()
		for v in [a, b, b + down, a + down]:
			vertices.append(v)
			normals.append(normal)
			uvs.append(Vector2(-1, -1))
		indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = vertices
	surface[Mesh.ARRAY_NORMAL] = normals
	surface[Mesh.ARRAY_TEX_UV] = uvs
	surface[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	return mesh


## Places a card on top of the stack at p and files it in grid and chunk.
## The caller rebuilds the chunk's buffer.
func _put_on_floor(id: int, p: Vector2, rotation_y: float) -> void:
	var footprint := _footprint_cells(p, rotation_y)
	var top := 0.0
	for cell in footprint:
		top = maxf(top, _heights[cell])
	var y := top + CARD_THICKNESS
	for cell in footprint:
		_heights[cell] = y
		_mark_surface_dirty(cell)
	_positions[id] = Vector3(p.x, y, p.y)
	_rotations[id] = rotation_y
	_grid_add(id)
	var chunk := _chunk_index(p)
	_chunk_of[id] = chunk
	var cards := _chunk_cards[chunk]
	_slot_of[id] = cards.size()
	cards.append(id)
	_chunk_cards[chunk] = cards


## Recomputes height map cells from the cards still on the floor, so a
## cleared patch drops back down instead of remembering the pile that used to
## be there.
func _refresh_cells(cells: PackedInt32Array) -> void:
	var done := {}
	for cell in cells:
		if done.has(cell):
			continue
		done[cell] = true
		var center := _height_cell_center(cell)
		var top := 0.0
		for id in _cards_near(center):
			if _states[id] == State.ON_FLOOR and _positions[id].y > top and _covers(id, center):
				top = _positions[id].y
		_heights[cell] = top
		_mark_surface_dirty(cell)


## The height map cells whose centres a card at p, turned by rotation_y,
## covers (at least the one under its centre).
func _footprint_cells(p: Vector2, rotation_y: float) -> PackedInt32Array:
	var cells := PackedInt32Array()
	var half := CARD_SIZE / 2
	var reach := Vector2(
		absf(cos(rotation_y)) * half.x + absf(sin(rotation_y)) * half.y,
		absf(sin(rotation_y)) * half.x + absf(cos(rotation_y)) * half.y)
	var columns := _height_columns
	var rows := _heights.size() / columns
	var lo := ((p - reach - bounds.position) / HEIGHT_CELL).floor()
	var hi := ((p + reach - bounds.position) / HEIGHT_CELL).floor()
	var c := cos(rotation_y)
	var s := sin(rotation_y)
	for row in range(maxi(0, int(lo.y)), mini(rows - 1, int(hi.y)) + 1):
		for column in range(maxi(0, int(lo.x)), mini(columns - 1, int(hi.x)) + 1):
			var d := bounds.position + Vector2(column + 0.5, row + 0.5) * HEIGHT_CELL - p
			# Inverse of _rotated(), as in _covers().
			if absf(d.x * c - d.y * s) <= half.x and absf(d.x * s + d.y * c) <= half.y:
				cells.append(row * columns + column)
	if cells.is_empty():
		cells.append(_height_index(p))
	return cells


func _height_cell_center(cell: int) -> Vector2:
	return bounds.position + Vector2(cell % _height_columns + 0.5, cell / _height_columns + 0.5) * HEIGHT_CELL


## An x/z offset turned the same way as Basis(Vector3.UP, rotation_y).
static func _rotated(local: Vector2, rotation_y: float) -> Vector2:
	return Vector2(
		local.x * cos(rotation_y) + local.y * sin(rotation_y),
		-local.x * sin(rotation_y) + local.y * cos(rotation_y))


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
		buffer[i + 12] = accent.r; buffer[i + 13] = accent.g; buffer[i + 14] = accent.b; buffer[i + 15] = _faces[id]
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
	_grid_cell_of[id] = index


func _grid_remove(id: int) -> void:
	var index := _grid_cell_of[id]
	if index < 0:
		return
	_grid_cell_of[id] = -1
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
