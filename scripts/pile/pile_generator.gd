class_name PileGenerator
extends RefCounted
## Decides where every card and binder lands when the collection is dumped
## on the floor (plan §3.4: everything, all at once). Deterministic per seed.
##
## About half the cards land in heaps (where boxes and binders spilled);
## the rest spread out following a noise field with a bonus near walls, so
## the floor gets deep drifts and thin patches instead of an even carpet.

const MAX_TRIES := 40
const HEAP_SHARE := 0.35
const HEAP_COUNT := 18
const HEAP_RADIUS := Vector2(0.8, 1.8)


class Placement:
	var position: Vector2 # x, z on the floor
	var rotation: float
	var face_up: bool


static func scatter(count: int, bounds: Rect2, obstacles: Array[Rect2], random_seed: int) -> Array[Placement]:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var noise := FastNoiseLite.new()
	noise.seed = random_seed
	noise.frequency = 0.22
	var heaps: Array[Vector3] = [] # x, z, radius
	for h in HEAP_COUNT:
		var center := _sample_position(rng, noise, bounds, obstacles)
		heaps.append(Vector3(center.x, center.y, rng.randf_range(HEAP_RADIUS.x, HEAP_RADIUS.y)))
	var placements: Array[Placement] = []
	placements.resize(count)
	for i in count:
		var placement := Placement.new()
		if rng.randf() < HEAP_SHARE:
			placement.position = _sample_heap(rng, heaps[rng.randi_range(0, heaps.size() - 1)], bounds, obstacles)
		else:
			placement.position = _sample_position(rng, noise, bounds, obstacles)
		placement.rotation = rng.randf() * TAU
		placement.face_up = rng.randf() < 0.7
		placements[i] = placement
	return placements


static func _sample_position(rng: RandomNumberGenerator, noise: FastNoiseLite, bounds: Rect2, obstacles: Array[Rect2]) -> Vector2:
	var fallback := bounds.get_center()
	for attempt in MAX_TRIES:
		var p := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if _blocked(p, obstacles):
			continue
		fallback = p
		var clump := pow(noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5, 3.0)
		var wall_distance := minf(minf(p.x - bounds.position.x, bounds.end.x - p.x), minf(p.y - bounds.position.y, bounds.end.y - p.y))
		var weight := clampf(0.05 + clump + 0.7 * exp(-wall_distance / 0.8), 0.0, 1.0)
		if rng.randf() < weight:
			return p
	return fallback


## A point scattered around a heap centre, densest in the middle.
static func _sample_heap(rng: RandomNumberGenerator, heap: Vector3, bounds: Rect2, obstacles: Array[Rect2]) -> Vector2:
	for attempt in MAX_TRIES:
		var p := Vector2(heap.x, heap.y) + Vector2(rng.randfn(0.0, heap.z * 0.5), rng.randfn(0.0, heap.z * 0.5))
		if bounds.has_point(p) and not _blocked(p, obstacles):
			return p
	return Vector2(heap.x, heap.y)


static func _blocked(p: Vector2, obstacles: Array[Rect2]) -> bool:
	for rect in obstacles:
		if rect.has_point(p):
			return true
	return false
