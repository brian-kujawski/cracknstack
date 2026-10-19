class_name TossedCard
extends MeshInstance3D
## A card the player tossed: a short scripted arc that tumbles mostly end over end
## and lands on the pile. Not a physics body (the pile stays klunky): it
## integrates its own gentle arc, bounces softly off walls and furniture, and
## when it reaches the top of the pile it hands itself back to PileWorld,
## face up or down depending on how it landed. PileWorld nudges it clear of
## anything solid as it lands, so a card never ends up poking into a wall.

const GRAVITY := 9.8
const AIR_DRAG := 1.2 # per second, horizontal only; keeps the toss soft
## Share of horizontal speed kept after bouncing off a wall.
const BOUNCE := 0.35
## Look this far past the card's centre for walls (half a card's diagonal),
## so its edge, not its centre, is what bounces.
const EDGE_REACH := 0.055

var card_id: int
var pile: PileWorld
var velocity: Vector3
## Radians per second around the card's own axes: x is end over end, y
## rolls around the long axis, z spins flat.
var tumble: Vector3
var exclude: Array[RID] = []
## How it lands: -1 as the tumble leaves it, 1 face up, 0 face down (Unmask
## decides before the card comes down).
var land_face_up := -1


## Builds the visual from the held card's material and launches it.
func launch(id: int, world: PileWorld, material: Material, start: Transform3D, launch_velocity: Vector3, spin: Vector3) -> void:
	card_id = id
	pile = world
	velocity = launch_velocity
	tumble = spin
	var quad := QuadMesh.new()
	quad.size = PileWorld.CARD_SIZE
	mesh = quad
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	global_transform = start


func _physics_process(delta: float) -> void:
	var from := global_position
	velocity.y -= GRAVITY * delta
	var horizontal := Vector2(velocity.x, velocity.z) * maxf(0.0, 1.0 - AIR_DRAG * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	var to := from + velocity * delta

	# Anything solid in the way (wall, shelf, table leg) bounces the card
	# back softly; it stays where it is this step.
	var heading := Vector3(velocity.x, 0, velocity.z).normalized() * EDGE_REACH
	var query := PhysicsRayQueryParameters3D.create(from, to + heading)
	query.exclude = exclude
	query.collision_mask = 1 # the store itself, not binders or stacks
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.normal.y < 0.7:
		var wall := Vector2(hit.normal.x, hit.normal.z).normalized()
		var across := Vector2(velocity.x, velocity.z)
		if across.dot(wall) < 0.0:
			across = across.bounce(wall) * BOUNCE
		velocity.x = across.x
		velocity.z = across.y
		to = Vector3(from.x, to.y, from.z)
	elif not hit.is_empty():
		_land(Vector3(to.x, hit.position.y, to.z))
		return

	global_position = to
	if not tumble.is_zero_approx():
		rotate_object_local(tumble.normalized(), tumble.length() * delta)

	var floor_height := pile.height_at(Vector2(to.x, to.z))
	if to.y <= floor_height + PileWorld.CARD_THICKNESS:
		_land(to)


func _land(point: Vector3) -> void:
	# The quad's face points along its local +Z; face up if that ends up
	# pointing at the ceiling more than the floor.
	var face_up := global_transform.basis.z.y > 0.0 if land_face_up < 0 else land_face_up == 1
	var yaw := atan2(-global_transform.basis.y.x, -global_transform.basis.y.z)
	pile.drop(card_id, point, yaw, face_up)
	queue_free()
