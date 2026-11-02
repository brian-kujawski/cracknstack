class_name PileGenerator
extends RefCounted
## Decides where cards and binders land when they're tipped out on the
## floor (a bulk box, binders with nowhere else to go). Deterministic per
## seed.
##
## It's as if a few boxes of cards were tipped out near the middle of the
## room: most cards fall more or less straight down around where their box
## was tipped (a normal distribution), and some skid off toward the walls
## and corners, so the middle is deep and the edges are thin.
##
## Every placement is checked against the whole footprint, not just its
## centre: nothing may poke into a wall, a shelf or a table leg. The same
## check (footprint_clear, nearest_clear) is used whenever anything is put
## down later.

const MAX_TRIES := 40
## Boxes tipped out. Their centres are spread normally around the middle of
## the room, with this standard deviation as a share of the room's size.
const DUMP_COUNT := 8
const DUMP_SPREAD := 0.15
## Standard deviation (m) of where a card lands around its box.
const FALL_SPREAD := 0.5
## Share of cards that skid off toward the edges, and how far past the
## fall they go on average (m).
const DRIFT_SHARE := 0.15
const DRIFT_DISTANCE := 1.8
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
## They're tipped out around DUMP_COUNT spots near the middle of the room,
## or around the floor points in `around` if given (a bulk box tipped out
## where you stand).
static func scatter(count: int, bounds: Rect2, obstacles: Array[Rect2], random_seed: int,
		half_size := PileWorld.CARD_SIZE / 2, around: Array[Vector2] = []) -> Array[Placement]:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var middle := bounds.get_center()
	var inner := bounds.grow(-1.0)
	var dumps: Array[Vector2] = []
	for spot in around:
		dumps.append(spot.clamp(bounds.position, bounds.end))
	if dumps.is_empty():
		for d in DUMP_COUNT:
			var spot := middle + Vector2(rng.randfn(0.0, bounds.size.x * DUMP_SPREAD), rng.randfn(0.0, bounds.size.y * DUMP_SPREAD))
			dumps.append(spot.clamp(inner.position, inner.end))
	var placements: Array[Placement] = []
	placements.resize(count)
	for i in count:
		var placement := Placement.new()
		placement.rotation = rng.randf() * TAU
		placement.face_up = rng.randf() < 0.7
		placement.position = _sample(rng, dumps[rng.randi_range(0, dumps.size() - 1)], bounds, obstacles,
			half_size, placement.rotation)
		placements[i] = placement
	return placements


## Where one card from the box tipped at `dump` lands.
static func _sample(rng: RandomNumberGenerator, dump: Vector2, bounds: Rect2, obstacles: Array[Rect2],
		half_size: Vector2, rotation_y: float) -> Vector2:
	var drifts := rng.randf() < DRIFT_SHARE
	var p := dump
	for attempt in MAX_TRIES:
		var fall := Vector2(rng.randfn(0.0, FALL_SPREAD), rng.randfn(0.0, FALL_SPREAD))
		if drifts:
			# Exponential skid in the direction it was already falling.
			var skid := -DRIFT_DISTANCE * log(1.0 - rng.randf())
			fall += (fall.normalized() if not fall.is_zero_approx() else Vector2.RIGHT) * skid
		p = dump + fall
		if footprint_clear(p, half_size, rotation_y, bounds, obstacles):
			return p
	return nearest_clear(p.clamp(bounds.position, bounds.end), half_size, rotation_y, bounds, obstacles)


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
