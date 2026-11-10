class_name PutDown
## Putting things down, the same way for everything you can hold (Hands): a
## card, a binder, a booster pack, or a box (booster, bulk or shipping box,
## the sorting tray, the laptop).
##
## A quick click puts what's in hand where you're aiming; holding the button
## shows a ghost of it there first (ghost_of: a see-through white copy of
## its real shape) that follows your aim, and letting go puts it exactly
## where the ghost was. The ghost and the put-down use the same pose, so
## they can't disagree.
##
## Everything stacks on everything: the top of a box, a closed binder, a
## pack or a card lying about is somewhere to put things, like a table top.
## Things go down flat, resting on the highest point under them (rest_pose).
##
## Binders, boxes and packs are physics bodies (in GROUP): once down they
## rest, and fall by themselves when what's under them goes. Cards lying on
## tables and on things (LooseCard) are static, since there can be
## thousands: whenever something is taken away from under them, disturb()
## drops any left with nothing under them onto what's below now.

## The physics bodies that rest on things (binders, boxes, packs).
const GROUP := &"rests"
## What resting things rest on: the store, each other and cards on tables,
## and the floor pile's surface.
const MASK := 1 | Binder.PHYSICS_LAYER | PileWorld.SURFACE_LAYER
## Things are lowered from this far over the point aimed at.
const DROP_HEIGHT := 0.4
## They come to rest this far over what they touch.
const CLEARANCE := 0.002
## How see-through a ghost is.
const GHOST_ALPHA := 0.5
## How long after a disturbance cards are looked at again, for anything
## that slid or fell in the meantime.
const RECHECK_SECONDS := 1.0
## How far above a disturbance to look for things resting on it.
const REACH_UP := 1.5


## Where a thing with collision `shape` (at `shape_local` in the thing's
## own frame) comes to rest, turned to `basis`, at global x, z `at`,
## lowered from `from_height` (the height of its lowest point at the start):
## the thing's global pose. `exclude` is never rested on.
static func rest_pose(space: PhysicsDirectSpaceState3D, shape: Shape3D, shape_local: Transform3D, basis: Basis,
		at: Vector2, from_height: float, exclude: Array[RID] = []) -> Transform3D:
	var bottom := lowest(shape, Transform3D(basis) * shape_local)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = MASK
	params.exclude = exclude
	var origin := Vector3(at.x, from_height - bottom, at.y)
	params.transform = Transform3D(basis, origin) * shape_local
	params.motion = Vector3(0, -(from_height + 0.5), 0)
	var safe: float = space.cast_motion(params)[0]
	origin.y += params.motion.y * safe + CLEARANCE
	return Transform3D(basis, origin)


## How far below the origin the lowest point of a box `shape`, placed at
## `xform` (in the frame of the thing it belongs to), is (negative below).
static func lowest(shape: Shape3D, xform: Transform3D) -> float:
	var half := (shape as BoxShape3D).size / 2 if shape is BoxShape3D else Vector3.ZERO
	var low := INF
	for x in [-1, 1]:
		for y in [-1, 1]:
			for z in [-1, 1]:
				low = minf(low, (xform * Vector3(half.x * x, half.y * y, half.z * z)).y)
	return low


## The height to lower a thing `height` tall from, over global `point`:
## DROP_HEIGHT over it, but under anything overhead (a table top, when
## aiming at the floor beneath it), so it never starts inside something.
static func drop_start(space: PhysicsDirectSpaceState3D, point: Vector3, height: float, exclude: Array[RID] = []) -> float:
	var top := point.y + DROP_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.005, Vector3(point.x, top + height, point.z), 1, exclude)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		top = minf(top, hit.position.y - height - 0.002)
	return maxf(top, point.y)


## A see-through white copy of `thing`'s real shape (its visible meshes,
## where they are on it), with its origin at `thing`'s: put it where `thing`
## would go. Only the meshes are copied, not scripts or collision, so the
## ghost can't be aimed at, bumped into or saved.
static func ghost_of(thing: Node3D, material: Material) -> Node3D:
	var ghost := Node3D.new()
	ghost.name = "Ghost"
	var inverse := thing.global_transform.affine_inverse()
	var stack: Array[Node] = [thing]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var part := node as MeshInstance3D
		if part == null or part.mesh == null or not part.is_visible_in_tree():
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = part.mesh
		copy.transform = inverse * part.global_transform
		copy.material_override = material
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(copy)
	return ghost


## The look of every ghost: plain white, lit like the room, half see-through.
static func ghost_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 1, GHOST_ALPHA)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.9
	# A faint glow of its own, so it still shows in a dark corner.
	material.emission_enabled = true
	material.emission = Color(0.25, 0.25, 0.25)
	return material


## Everything `thing` looks like, as a global box (its meshes'), for
## disturb().
static func global_aabb(thing: Node3D) -> AABB:
	var box := AABB(thing.global_position, Vector3.ZERO)
	var stack: Array[Node] = [thing]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			box = box.merge((node as MeshInstance3D).global_transform * (node as MeshInstance3D).get_aabb())
	return box


## Something in `area` (a global box) has gone or changed shape: everything
## resting over it is told. Binders, boxes and packs wake and let physics
## settle them; an open binder is lowered onto what's under it now; a card
## lying there with nothing under it now falls onto what is. A moment later
## the cards there are looked at again, for anything that slid meanwhile.
## `exclude` (what went) is never counted as being under anything.
static func disturb(pile: PileWorld, area: AABB, exclude: Array[RID] = []) -> void:
	if pile == null or not pile.is_inside_tree():
		return
	var cards: Array[LooseCard] = []
	for body in resting_over(pile, area, exclude):
		if body is LooseCard:
			cards.append(body)
		elif body is Binder:
			(body as Binder).settle()
		elif body is RigidBody3D and not (body as RigidBody3D).freeze:
			(body as RigidBody3D).sleeping = false
	resettle_cards(pile, cards, exclude)
	var later := area.grow(0.15)
	pile.get_tree().create_timer(RECHECK_SECONDS).timeout.connect(func() -> void:
		if is_instance_valid(pile) and pile.is_inside_tree():
			var again: Array[LooseCard] = []
			for body in resting_over(pile, later):
				if body is LooseCard:
					again.append(body)
				elif body is Binder and (body as Binder).state == Binder.State.OPEN:
					(body as Binder).settle()
			resettle_cards(pile, again))


## Whatever can rest on things (Binder.PHYSICS_LAYER) in `area` or above
## it, up to REACH_UP.
static func resting_over(pile: PileWorld, area: AABB, exclude: Array[RID] = []) -> Array:
	var reach := area.grow(0.01)
	reach.size.y += REACH_UP
	var shape := BoxShape3D.new()
	shape.size = reach.size
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), reach.get_center())
	params.collision_mask = Binder.PHYSICS_LAYER
	params.exclude = exclude
	var found := []
	for hit in pile.get_world_3d().direct_space_state.intersect_shape(params, 256):
		if hit.collider != null and not (hit.collider as Node).is_queued_for_deletion():
			found.append(hit.collider)
	return found


## The cards among `cards` with nothing under them any more fall onto what
## is, lowest first (so one on another follows it down).
static func resettle_cards(pile: PileWorld, cards: Array[LooseCard], exclude: Array[RID] = []) -> void:
	cards.sort_custom(func(a: LooseCard, b: LooseCard) -> bool: return a.global_position.y < b.global_position.y)
	# A card that fell is gone at the end of the frame; until then it
	# mustn't hold up the one above.
	var gone := exclude.duplicate()
	for card in cards:
		if is_instance_valid(card) and not card.is_queued_for_deletion() and pile.resettle(card, gone):
			gone.append(card.get_rid())
