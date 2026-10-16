class_name PileGenerator
extends RefCounted
## Decides where every card and binder lands when the collection is dumped
## on the floor (plan §3.4: everything, all at once). Deterministic per seed.
##
## About half the cards land in heaps (where boxes and binders spilled);
## the rest spread out following a noise field with a bonus near walls, so
## the floor gets deep drifts and thin patches instead of an even carpet.
##
## Every placement is checked against the whole footprint, not just its
## centre: nothing may poke into a wall, a shelf or a table leg. The same
## check (footprint_clear, nearest_clear) is used whenever anything is put
## down later.

const MAX_TRIES := 40
const HEAP_SHARE := 0.5
const HEAP_COUNT := 8
const HEAP_RADIUS := Vector2(0.6, 1.3)
## How far nearest_clear() looks for a clear spot, and in what steps.
const SEARCH_RADIUS := 1.5
const SEARCH_STEP := 0.02
const SEARCH_ANGLES := 16


class Placement:
	var position: Vector2 # x, z on the floor
	var rotation: float
	var face_up: bool


## Places `count` things with footprint half-size `half_size` (a card by
## default) inside `bounds`, each clear of every rectangle in `obstacles`.
static func scatter(count: int, bounds: Rect2, obstacles: Array[Rect2], random_seed: int,
		half_size := PileWorld.CARD_SIZE / 2) -> Array[Placement]:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var noise := FastNoiseLite.new()
	noise.seed = random_seed
	noise.frequency = 0.22
	var heaps: Array[Vector3] = [] # x, z, radius
	for h in HEAP_COUNT:
		var center := _sample_position(rng, noise, bounds, obstacles, half_size, 0.0)
		heaps.append(Vector3(center.x, center.y, rng.randf_range(HEAP_RADIUS.x, HEAP_RADIUS.y)))
	var placements: Array[Placement] = []
	placements.resize(count)
	for i in count:
		var placement := Placement.new()
		placement.rotation = rng.randf() * TAU
		if rng.randf() < HEAP_SHARE:
			placement.position = _sample_heap(rng, heaps[rng.randi_range(0, heaps.size() - 1)], bounds, obstacles,
				half_size, placement.rotation)
		else:
			placement.position = _sample_position(rng, noise, bounds, obstacles, half_size, placement.rotation)
		placement.face_up = rng.randf() < 0.7
		placements[i] = placement
	return placements


static func _sample_position(rng: RandomNumberGenerator, noise: FastNoiseLite, bounds: Rect2, obstacles: Array[Rect2],
		half_size: Vector2, rotation_y: float) -> Vector2:
	var fallback := nearest_clear(bounds.get_center(), half_size, rotation_y, bounds, obstacles)
	for attempt in MAX_TRIES:
		var p := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if not footprint_clear(p, half_size, rotation_y, bounds, obstacles):
			continue
		fallback = p
		var clump := pow(noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5, 3.0)
		var wall_distance := minf(minf(p.x - bounds.position.x, bounds.end.x - p.x), minf(p.y - bounds.position.y, bounds.end.y - p.y))
		var weight := clampf(0.05 + clump + 0.7 * exp(-wall_distance / 0.8), 0.0, 1.0)
		if rng.randf() < weight:
			return p
	return fallback


## A point scattered around a heap centre, densest in the middle.
static func _sample_heap(rng: RandomNumberGenerator, heap: Vector3, bounds: Rect2, obstacles: Array[Rect2],
		half_size: Vector2, rotation_y: float) -> Vector2:
	for attempt in MAX_TRIES:
		var p := Vector2(heap.x, heap.y) + Vector2(rng.randfn(0.0, heap.z * 0.5), rng.randfn(0.0, heap.z * 0.5))
		if footprint_clear(p, half_size, rotation_y, bounds, obstacles):
			return p
	return nearest_clear(Vector2(heap.x, heap.y), half_size, rotation_y, bounds, obstacles)


## True if a rectangle (centre p, half size, turned by rotation_y the same
## way as PileWorld's cards) lies wholly inside `bounds` and overlaps none of
## `obstacles`.
static func footprint_clear(p: Vector2, half_size: Vector2, rotation_y: float, bounds: Rect2, obstacles: Array[Rect2]) -> bool:
	# The footprint's own axes, as in PileWorld._rotated().
	var u := Vector2(cos(rotation_y), -sin(rotation_y))
	var v := Vector2(sin(rotation_y), cos(rotation_y))
	var reach := Vector2(absf(u.x) * half_size.x + absf(v.x) * half_size.y, absf(u.y) * half_size.x + absf(v.y) * half_size.y)
	if p.x - reach.x < bounds.position.x or p.x + reach.x > bounds.end.x \
			or p.y - reach.y < bounds.position.y or p.y + reach.y > bounds.end.y:
		return false
	for rect in obstacles:
		var half := rect.size / 2
		var d := rect.get_center() - p
		# Separating axes: the world axes, then the footprint's own two.
		if absf(d.x) >= reach.x + half.x or absf(d.y) >= reach.y + half.y:
			continue
		if absf(d.dot(u)) >= half_size.x + absf(u.x) * half.x + absf(u.y) * half.y:
			continue
		if absf(d.dot(v)) >= half_size.y + absf(v.x) * half.x + absf(v.y) * half.y:
			continue
		return false
	return true


## The clear spot closest to p for this footprint (p itself if it's clear),
## searched in rings out to SEARCH_RADIUS. Falls back to p if nothing nearby
## is clear.
static func nearest_clear(p: Vector2, half_size: Vector2, rotation_y: float, bounds: Rect2, obstacles: Array[Rect2]) -> Vector2:
	if footprint_clear(p, half_size, rotation_y, bounds, obstacles):
		return p
	for ring in range(1, int(SEARCH_RADIUS / SEARCH_STEP) + 1):
		var radius := ring * SEARCH_STEP
		for a in SEARCH_ANGLES:
			var q := p + Vector2.from_angle(TAU * a / SEARCH_ANGLES) * radius
			if footprint_clear(q, half_size, rotation_y, bounds, obstacles):
				return q
	push_warning("PileGenerator: no clear spot within %.1f m of %s" % [SEARCH_RADIUS, p])
	return p
