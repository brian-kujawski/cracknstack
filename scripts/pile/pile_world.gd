class_name PileWorld
extends Node3D
## Owns every card lying on the floor (plan §4.4). Cards are not nodes: they
## live in packed arrays indexed by card id (one instance per card), and are
## drawn by one MultiMesh per floor chunk.
##
## It also keeps track of the few cards lying on tables, which are nodes of
## their own (LooseCard) so they can sit at any height. The split is only for
## drawing them: anything that finds, lights up, flips or picks up a card
## lying about (is_lying) treats both kinds the same.
##
## The pile is static and deliberately klunky. Walking never moves a card,
## and picking one up leaves its neighbours where they lie. No physics.

const CARD_SIZE := Vector2(0.063, 0.088) # metres, real card size
## Three times a real card (about 0.3 mm): real thickness is too thin for a
## pile to read as a pile.
const CARD_THICKNESS := 0.0018
## Corner radii in metres: every set's, and Alpha's deeper cut (see
## CardData.has_alpha_corners). Keep in step with card_face.gdshaderinc.
const CORNER_RADIUS := 0.003
const ALPHA_CORNER_RADIUS := 0.0043
## Flat segments per rounded corner of the card mesh.
const CORNER_SEGMENTS := 3
const CHUNK_SIZE := 2.0
## Picking grid: each card is filed under the cell holding its centre. Cells
## are wider than half a card's diagonal, so a 3×3 query finds every card
## that could cover a point.
const GRID_CELL := 0.1
## Height map resolution used to stack cards on top of each other. Fine
## enough that a card only rests on cards that are really under it, rather
## than on anything nearby.
const HEIGHT_CELL := 0.015
## A pile flip tosses the topmost cards within this distance of where you aim.
const FLIP_RADIUS := 0.15
## A pile flip tosses cards lying within this height of where you aim, so
## one aimed at a table leaves the pile under it alone.
const FLIP_HEIGHT := 0.1
## Cards landing on a table (or the shelf top) stay this far in from its edge.
const TABLE_MARGIN := 0.01
## Collision layer of the pile's surface: a coarse height field that only
## binders collide with, so they can rest on the cards.
const SURFACE_LAYER := 8
## Surface grid: one height per this many height map cells (the highest).
const SURFACE_STRIDE := 3

## HELD is anywhere a card isn't lying about: in hand, in flight, in a
## binder or hovering (HoveringCard).
enum State { ON_FLOOR, HELD, ON_TABLE }

const Store := preload("res://scripts/store/store_builder.gd")

var bounds: Rect2
## Floor footprints nothing may overlap (walls are the edge of `bounds`).
var obstacles: Array[Rect2] = []
## Table tops and the like that cards landing on them are kept on, as x/z
## rectangles (Store.surfaces).
var surfaces: Array[Rect2] = []
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
var _chunk_rows := 0
## The last chunk isn't a patch of floor: it draws the rare cards lying on
## the floor, wherever they are, as foil and with their own back (see CardView).
var _foil_chunk := -1
var _chunks: Array[MultiMeshInstance3D] = []
var _chunk_cards: Array[PackedInt32Array] = []
var _chunk_of := PackedInt32Array()
var _slot_of := PackedInt32Array()

var _grid_columns := 0
var _grid_rows := 0
var _grid: Array[PackedInt32Array] = []
## Per card: the grid cell it's filed under, or -1.
var _grid_cell_of := PackedInt32Array()

var _height_columns := 0
var _heights := PackedFloat32Array()
## No card on the floor lies higher than this (it never comes down, so it may
## be a little high), so card_on_ray() only looks where the pile can be.
var _top := 0.0

## Cards lying on tables: card id -> LooseCard.
var _loose := {}

var _highlighted := -1
var _material: ShaderMaterial
var _mesh: ArrayMesh

## Cards glowing by magic (Chain Lightning, later Tithe): card id -> seconds
## left. A card stops glowing when it's picked up or its time runs out.
var _glowing := {}
## A glowing card is usually buried, so each also gets a soft light drawn
## over everything, where it lies: card id -> marker.
var _glow_markers := {}
var _glow_material: StandardMaterial3D
var _glow_time := 0.0

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


## Drops each set's binder closed somewhere on top of the pile, with room to
## open it where it lies.
func spawn_binders(random_seed: int) -> void:
	make_binders()
	scatter_binders(binders, random_seed)


## Makes one binder per set, in shelf order, into `binders`, without putting
## them anywhere yet (spawn_binders, or a save, does that).
func make_binders() -> void:
	binders.clear()
	for range_data in CardDatabase.all_binders():
		var binder := Binder.new()
		binder.setup(range_data, CardDatabase.get_set(range_data.set_code).accent_color, self)
		binders.append(binder)


## Drops binders closed at random on top of the pile. Where they land on each
## other they start a little apart, one above the other, and physics settles
## them.
func scatter_binders(dropped: Array[Binder], random_seed: int) -> void:
	var placements := PileGenerator.scatter(dropped.size(), bounds, obstacles, random_seed + 2, Binder.OPEN_HALF_FOOTPRINT)
	var reach := Binder.COVER.length() # centres closer than this may overlap
	var placed: Array[Binder] = []
	for other in binders:
		if other.is_inside_tree() and other not in dropped:
			placed.append(other)
	for i in dropped.size():
		var binder := dropped[i]
		var p := placements[i].position
		var y := height_under(p, Vector2(Binder.COVER.x, Binder.COVER.y) / 2, placements[i].rotation) + 0.01
		for other in placed:
			if other.state == Binder.State.CLOSED and Vector2(other.position.x, other.position.z).distance_to(p) < reach:
				y = maxf(y, other.position.y + other.thickness + 0.01)
		if binder.get_parent() == null:
			add_child(binder)
		binder.rotation = Vector3(0, placements[i].rotation, 0)
		binder.position = Vector3(p.x, y, p.y)
		binder.state = Binder.State.CLOSED
		binder.freeze = false
		placed.append(binder)


## Every card's place, for a save (ShopSave.snapshot): by card id, its
## state and floor pose (copied on write, so this is quick), and the cards
## on tables, id -> [position, turn, face up].
func snapshot_cards() -> Dictionary:
	var loose := {}
	for id in _loose:
		loose[id] = [_loose[id].position, _loose[id].rotation.y, _loose[id].face_up]
	return {"states": _states, "positions": _positions, "rotations": _rotations, "face_up": _face_up, "loose": loose}


## Builds the pile from a save instead of scattering it: every card the save
## had on the floor goes back exactly where it lay (no re-stacking), and
## every one it had on a table is laid there again. `cards` is the save's
## "cards" (ShopSave.finish) and `ids` maps each of its entries to a card id now (-1 for a card
## that's gone). Cards the save doesn't know (a set imported since) are
## scattered on top, as in a new game. Every other card starts in hand
## (HELD), for the save's binders and hands to take. A card where furniture
## now stands, or on a table that's gone, moves to the nearest clear spot
## on the floor; nothing else moves. Set `surfaces` first. Returns the ids
## scattered.
func restore_cards(floor_bounds: Rect2, floor_obstacles: Array[Rect2], cards: Dictionary, ids: PackedInt32Array,
		random_seed: int) -> PackedInt32Array:
	bounds = floor_bounds
	obstacles = floor_obstacles
	var count := CardDatabase.card_count()
	_allocate(count)
	_build_set_lookup()
	_states.fill(State.HELD)
	var where: PackedByteArray = cards.where
	var positions: PackedVector3Array = cards.positions
	var rotations: PackedFloat32Array = cards.rotations
	var face_up: PackedByteArray = cards.face_up
	var known := PackedByteArray()
	known.resize(count)
	var on_floor: Array[int] = []
	var on_tables: Array[int] = []
	for i in mini(ids.size(), where.size()):
		var id := ids[i]
		if id < 0 or known[id] == 1:
			continue
		known[id] = 1
		if where[i] == 0:
			on_floor.append(i)
		elif where[i] == 1:
			on_tables.append(i)
	# Lowest first, so each card's height map cells end up under the highest
	# card covering them.
	on_floor.sort_custom(func(a: int, b: int) -> bool: return positions[a].y < positions[b].y)
	# Cards where furniture now stands (or past a wall that moved), and table
	# cards whose table is gone, move to the nearest clear spot and go on
	# top there once the rest is down. Nothing else moves.
	var moved: Array[int] = []
	for i in on_floor:
		var p := Vector2(positions[i].x, positions[i].z)
		if not PileGenerator.footprint_clear(p, CARD_SIZE / 2, rotations[i], bounds, obstacles):
			moved.append(i)
			continue
		_states[ids[i]] = State.ON_FLOOR
		_face_up[ids[i]] = face_up[i]
		_put_on_floor(ids[i], p, rotations[i], positions[i].y)
	for i in on_tables.duplicate():
		if not surfaces.any(func(top: Rect2) -> bool: return top.has_point(Vector2(positions[i].x, positions[i].z))):
			on_tables.erase(i)
			moved.append(i)
	for i in moved:
		_states[ids[i]] = State.ON_FLOOR
		_face_up[ids[i]] = face_up[i]
		_put_on_floor(ids[i], clear_point(Vector2(positions[i].x, positions[i].z), CARD_SIZE / 2, rotations[i]), rotations[i])
	var unknown := PackedInt32Array()
	for id in count:
		if known[id] == 0:
			unknown.append(id)
	var placements := PileGenerator.scatter(unknown.size(), bounds, obstacles, random_seed)
	for k in unknown.size():
		var id := unknown[k]
		_states[id] = State.ON_FLOOR
		_face_up[id] = 1 if placements[k].face_up else 0
		_put_on_floor(id, placements[k].position, placements[k].rotation)
	for c in _chunks.size():
		_rebuild_chunk(c)
	_build_surface()
	for i in on_tables:
		lay_loose(ids[i], positions[i], rotations[i], face_up[i] == 1)
	return unknown


func card_count_on_floor() -> int:
	return _states.count(State.ON_FLOOR)


## Where a card lying on the floor or a table is, in the pile's space.
func card_position(id: int) -> Vector3:
	if _states[id] == State.ON_TABLE:
		return _loose[id].position
	return _positions[id]


func is_on_floor(id: int) -> bool:
	return _states[id] == State.ON_FLOOR


## Whether card `id` is lying about, on the floor or on a table, rather than
## in hand, in flight or in a binder.
func is_lying(id: int) -> bool:
	return _states[id] == State.ON_FLOOR or _states[id] == State.ON_TABLE


func is_face_up(id: int) -> bool:
	if _states[id] == State.ON_TABLE:
		return _loose[id].face_up
	return _face_up[id] == 1


## The LooseCard card `id` is lying on a table as, or null.
func loose_card(id: int) -> LooseCard:
	return _loose.get(id)


## Where a card lying on the floor or a table is, as a global pose for a
## card quad (see Glide).
func card_pose(id: int) -> Transform3D:
	if _states[id] == State.ON_TABLE:
		return _loose[id].card_pose()
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


## The first card on the floor that a ray from `from` to `to` (global
## points) meets, where it meets the card's face: {"id", "position"}, or
## empty. This is the card you see there, however high the pile under it.
func card_on_ray(from: Vector3, to: Vector3) -> Dictionary:
	var a := to_local(from)
	var b := to_local(to)
	var d := b - a
	# The part of the ray between the floor and the top of the pile.
	var t0 := 0.0
	var t1 := 1.0
	if absf(d.y) < 1e-6:
		if a.y < 0.0 or a.y > _top:
			return {}
	else:
		var at_top := (_top - a.y) / d.y
		var at_floor := -a.y / d.y
		t0 = maxf(t0, minf(at_top, at_floor))
		t1 = minf(t1, maxf(at_top, at_floor))
	if t0 > t1:
		return {}
	# Every card filed in a grid cell along that part could lie across it.
	var start := Vector2(a.x + d.x * t0, a.z + d.z * t0)
	var end := Vector2(a.x + d.x * t1, a.z + d.z * t1)
	var steps := ceili(start.distance_to(end) / (GRID_CELL / 2)) + 1
	var cells := {}
	for i in steps:
		var cell := _grid_cell(start.lerp(end, float(i) / maxi(steps - 1, 1)))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var x := cell.x + dx
				var y := cell.y + dy
				if x >= 0 and y >= 0 and x < _grid_columns and y < _grid_rows:
					cells[y * _grid_columns + x] = true
	var best := -1
	var best_t := INF
	for cell in cells:
		for id in _grid[cell]:
			if _states[id] != State.ON_FLOOR or absf(d.y) < 1e-6:
				continue
			var t := (_positions[id].y - a.y) / d.y
			if t < 0.0 or t > 1.0 or t >= best_t:
				continue
			if _covers(id, Vector2(a.x + d.x * t, a.z + d.z * t)):
				best_t = t
				best = id
	if best < 0:
		return {}
	return {"id": best, "position": to_global(a + d * best_t)}


## Lifts a card out of the pile or off its table. Nothing around it moves.
func pick_up(id: int) -> void:
	if _states[id] == State.ON_TABLE:
		if id == _highlighted:
			_highlighted = -1
		_stop_glow(id)
		_states[id] = State.HELD
		_loose[id].queue_free()
		_loose.erase(id)
		return
	if _states[id] != State.ON_FLOOR:
		return
	if id == _highlighted:
		set_highlight(-1)
	_stop_glow(id)
	_states[id] = State.HELD
	_grid_remove(id)
	_chunk_remove(id)
	_refresh_cells(_footprint_cells(Vector2(_positions[id].x, _positions[id].z), _rotations[id]))


## The binder card `id` belongs in, wherever it is now.
func binder_for(id: int) -> Binder:
	var card := CardDatabase.get_card(id)
	for binder in binders:
		if binder.binder.set_code == card.set_code and binder.binder.contains(card.collector_number):
			return binder
	return null


## Takes card `id` from wherever it lies: the floor, a table, hovering, or
## another binder's pocket it was misplaced in. Returns the global card pose
## it left (see Glide), or null if it can't be had (in hand, in flight, or
## locked into its own pocket).
func take_from_anywhere(id: int):
	if is_lying(id):
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


## Lays a held card on a table at `point` (global, its underside), turned to
## `yaw`, face up or down. Returns the card as it lies there.
func lay_loose(id: int, point: Vector3, yaw: float, face_up := true) -> LooseCard:
	if _states[id] != State.HELD:
		return null
	var card := LooseCard.new()
	add_child(card)
	card.setup(id, point, yaw, face_up)
	_states[id] = State.ON_TABLE
	_loose[id] = card
	return card


## A card coming down at `point` (global) without anyone placing it: tossed,
## flipped, or falling. It lands on whatever is under it: a table (or a card
## lying on one), kept clear of the table's edge, or else the pile. Binders,
## and anything in `exclude`, it falls past.
func land(id: int, point: Vector3, rotation_y: float, face_up := true, exclude: Array[RID] = []) -> void:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.03, Vector3(point.x, -1.0, point.z))
	query.collision_mask = 1 | Binder.PHYSICS_LAYER
	var skip := exclude.duplicate()
	query.exclude = skip
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	while not hit.is_empty() and hit.collider is Binder:
		skip.append(hit.rid)
		query.exclude = skip
		hit = space.intersect_ray(query)
	if hit.is_empty() or hit.position.y < 0.05 or hit.normal.y < 0.7:
		drop(id, point, rotation_y, face_up)
		return
	var on := Vector3(point.x, hit.position.y, point.z)
	var p := onto_surface(Vector2(on.x, on.z), rotation_y)
	lay_loose(id, Vector3(p.x, on.y, p.y), rotation_y, face_up)


## Nudges a card at `p` (x/z), turned by rotation_y, so all of it is on the
## table (or other surface) under it, if there is one. Anything else that
## lands there gives its own half size (a binder).
func onto_surface(p: Vector2, rotation_y: float, half := CARD_SIZE / 2) -> Vector2:
	var reach := Vector2(
		absf(cos(rotation_y)) * half.x + absf(sin(rotation_y)) * half.y,
		absf(sin(rotation_y)) * half.x + absf(cos(rotation_y)) * half.y)
	for surface in surfaces:
		# Grown a hair so a card landing right on the edge still counts.
		if surface.grow(0.001).has_point(p):
			var center := surface.get_center()
			var room := surface.size / 2 - Vector2(TABLE_MARGIN, TABLE_MARGIN) - reach
			var offset := p - center
			return center + Vector2(clampf(offset.x, -room.x, room.x), clampf(offset.y, -room.y, room.y))
	return p


## Where drop() would lay a card aimed at `point`, as a global pose for a
## card quad (see Glide).
func drop_pose(point: Vector3, rotation_y: float) -> Transform3D:
	var p := clear_point(Vector2(point.x, point.z), CARD_SIZE / 2, rotation_y)
	var top := 0.0
	for cell in _footprint_cells(p, rotation_y):
		top = maxf(top, _heights[cell])
	return Glide.flat_card(to_global(Vector3(p.x, top + CARD_THICKNESS, p.y)),
		global_basis * Basis(Vector3.UP, rotation_y))


## Lights up the card lying under the crosshair (on the floor or a table),
## or none for -1.
func set_highlight(id: int) -> void:
	if id == _highlighted:
		return
	var previous := _highlighted
	_highlighted = id
	if previous >= 0:
		_update_instance_custom(previous)
	if id >= 0:
		_update_instance_custom(id)


## Makes cards lying about glow for `seconds`, wherever they lie, on the
## floor or a table. Cards not lying about are skipped.
func glow(ids: Array, seconds: float) -> void:
	for id in ids:
		if is_lying(id):
			_glowing[id] = seconds
			_update_instance_custom(id)
			if not _glow_markers.has(id):
				var marker := MeshInstance3D.new()
				var quad := QuadMesh.new()
				quad.size = Vector2(0.3, 0.3)
				marker.mesh = quad
				marker.material_override = _glow_marker_material()
				marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(marker)
				marker.position = card_position(id) + Vector3.UP * 0.02
				_glow_markers[id] = marker


func is_glowing(id: int) -> bool:
	return _glowing.has(id)


## The cards a pile flip aimed at `point` tosses: up to `count` of the
## topmost cards lying within FLIP_RADIUS, highest first. Aimed at the floor
## that's floor cards; aimed at a table, the cards lying on it there.
func flip_cards(point: Vector3, count: int) -> Array[int]:
	var p := Vector2(point.x, point.z)
	var found: Array[int] = []
	if point.y < height_at(p) + FLIP_HEIGHT:
		for id in _cards_near(p):
			if _states[id] == State.ON_FLOOR and Vector2(_positions[id].x, _positions[id].z).distance_to(p) < FLIP_RADIUS:
				found.append(id)
	for id in _loose:
		var at: Vector3 = _loose[id].position
		if Vector2(at.x, at.z).distance_to(p) < FLIP_RADIUS and absf(at.y - point.y) < FLIP_HEIGHT:
			found.append(id)
	found.sort_custom(func(a: int, b: int) -> bool: return card_position(a).y > card_position(b).y)
	return found.slice(0, count)


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
	_fade_glows(delta)

func _fade_glows(delta: float) -> void:
	if _glowing.is_empty():
		return
	_glow_time += delta
	_glow_material.albedo_color.a = 0.8 + 0.2 * sin(_glow_time * 5.0)
	for id in _glowing.keys():
		_glowing[id] -= delta
		if _glowing[id] <= 0.0:
			_stop_glow(id)
			_update_instance_custom(id)


func _stop_glow(id: int) -> void:
	_glowing.erase(id)
	if _loose.has(id):
		_loose[id].set_glowing(false)
	if _glow_markers.has(id):
		_glow_markers[id].queue_free()
		_glow_markers.erase(id)


## One shared material for every marker: a warm round glow that faces the
## camera and shows through the pile (and everything else).
func _glow_marker_material() -> StandardMaterial3D:
	if _glow_material == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 0.97, 0.8, 1.0))
		gradient.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
		gradient.add_point(0.4, Color(1.0, 0.75, 0.25, 0.95))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		_glow_material = StandardMaterial3D.new()
		_glow_material.albedo_texture = texture
		_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_glow_material.no_depth_test = true
	return _glow_material


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
	_chunk_rows = ceili(bounds.size.y / CHUNK_SIZE)
	_mesh = card_mesh(false)
	_material = _floor_material(preload("res://shaders/floor_card.gdshader"), false)
	for c in _chunk_columns * _chunk_rows:
		_add_chunk(_material)
	_foil_chunk = _chunks.size()
	_add_chunk(_floor_material(preload("res://shaders/floor_foil.gdshader"), true))

	_grid_columns = ceili(bounds.size.x / GRID_CELL)
	_grid_rows = ceili(bounds.size.y / GRID_CELL)
	_grid.resize(_grid_columns * _grid_rows)
	for i in _grid.size():
		_grid[i] = PackedInt32Array()

	_height_columns = ceili(bounds.size.x / HEIGHT_CELL)
	_heights.resize(_height_columns * ceili(bounds.size.y / HEIGHT_CELL))
	_heights.fill(0.0)
	_top = 0.0


func _floor_material(shader: Shader, rare: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	if CardDatabase.face_atlas != null:
		CardDatabase.face_atlas.apply(material)
	CardDatabase.apply_back(material)
	if rare:
		CardDatabase.apply_rare_images(material)
	return material


func _add_chunk(material: ShaderMaterial) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = _mesh
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_chunks.append(instance)
	_chunk_cards.append(PackedInt32Array())


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
		_set_numbers[id] = set_numbers.get(card.set_code, 0) # 0: the rare cards
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


## A card with thickness: the face on top and edges running down
## CARD_THICKNESS below it, its corners rounded with Alpha's cut or the usual
## one. The face's UVs read like a PlaneMesh's (u along +x, v along +z);
## edge vertices get UV (-1, -1) so floor_card can paint them as card edge.
## UV2 holds each vertex's x/z with Alpha's corners, so floor_card can
## recut a usual card for Alpha without a second mesh.
static func card_mesh(alpha_corners: bool) -> ArrayMesh:
	var index := 1 if alpha_corners else 0
	if _card_meshes[index] == null:
		var outline := _card_outline(ALPHA_CORNER_RADIUS if alpha_corners else CORNER_RADIUS)
		_card_meshes[index] = _build_card_mesh(outline, _card_outline(ALPHA_CORNER_RADIUS))
	return _card_meshes[index]


static var _card_meshes: Array[ArrayMesh] = [null, null]


## The card's outline seen from above, clockwise from the top-left corner.
## Each corner's flat segments sit just outside the true curve, so the
## shaders can round the face off exactly inside them.
static func _card_outline(radius: float) -> PackedVector2Array:
	var outline := PackedVector2Array()
	var half := CARD_SIZE / 2 - Vector2(radius, radius)
	var step := PI / 2 / CORNER_SEGMENTS
	var reach := radius / cos(step / 2)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var start := PI + outline.size() / CORNER_SEGMENTS * PI / 2
		for k in CORNER_SEGMENTS:
			var angle := start + (k + 0.5) * step
			outline.append(corner * half + Vector2(cos(angle), sin(angle)) * reach)
	return outline


static func _build_card_mesh(outline: PackedVector2Array, alpha_outline: PackedVector2Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	var count := outline.size()
	for i in count:
		vertices.append(Vector3(outline[i].x, 0, outline[i].y))
		normals.append(Vector3.UP)
		uvs.append(outline[i] / CARD_SIZE + Vector2(0.5, 0.5))
		uv2s.append(alpha_outline[i])
	for i in range(1, count - 1):
		indices.append_array([0, i, i + 1])
	var down := Vector3(0, -CARD_THICKNESS, 0)
	for i in count:
		var j := (i + 1) % count
		var a := Vector3(outline[i].x, 0, outline[i].y)
		var b := Vector3(outline[j].x, 0, outline[j].y)
		var along := (b - a).normalized()
		var normal := Vector3(along.z, 0, -along.x)
		var first := vertices.size()
		for v in [a, b, b + down, a + down]:
			vertices.append(v)
			normals.append(normal)
			uvs.append(Vector2(-1, -1))
		uv2s.append_array([alpha_outline[i], alpha_outline[j], alpha_outline[j], alpha_outline[i]])
		indices.append_array([first, first + 2, first + 1, first, first + 3, first + 2])
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = vertices
	surface[Mesh.ARRAY_NORMAL] = normals
	surface[Mesh.ARRAY_TEX_UV] = uvs
	surface[Mesh.ARRAY_TEX_UV2] = uv2s
	surface[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	return mesh


## Places a card on top of the stack at p and files it in grid and chunk,
## or at height `at_height` if given (a card put back from a save). The
## caller rebuilds the chunk's buffer.
func _put_on_floor(id: int, p: Vector2, rotation_y: float, at_height := -1.0) -> void:
	var footprint := _footprint_cells(p, rotation_y)
	var y := at_height
	if y < 0.0:
		for cell in footprint:
			y = maxf(y, _heights[cell])
		y = maxf(y, 0.0) + CARD_THICKNESS
	for cell in footprint:
		_heights[cell] = maxf(_heights[cell], y)
		_mark_surface_dirty(cell)
	_top = maxf(_top, y)
	_positions[id] = Vector3(p.x, y, p.y)
	_rotations[id] = rotation_y
	_grid_add(id)
	var chunk := _foil_chunk if CardDatabase.is_rare(id) else _chunk_index(p)
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
	var flags := float(card.rarity) + (4.0 if id == _highlighted else 0.0) + (8.0 if _glowing.has(id) else 0.0) \
		+ (16.0 if card.has_alpha_corners() else 0.0)
	return Color(card.collector_number, _set_numbers[id], flags, _face_up[id])


## Shows a card's highlight and glow, on the floor or a table.
func _update_instance_custom(id: int) -> void:
	if _states[id] == State.ON_TABLE:
		_loose[id].set_highlighted(id == _highlighted)
		_loose[id].set_glowing(_glowing.has(id))
	elif _states[id] == State.ON_FLOOR:
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
	var row := clampi(int(local.y / CHUNK_SIZE), 0, _chunk_rows - 1)
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
