class_name UnsortedStack
extends StaticBody3D
## A tidy stack of cards the player set aside, usually because their binder
## hasn't turned up yet (plan §3.2). Face up; only the top card can be taken.
## Like binders it's kinematic and on the binder collision layer.

var pile: PileWorld

var _cards: Array[int] = []
var _top: MeshInstance3D
var _side: MeshInstance3D
var _shape: BoxShape3D
var _collision: CollisionShape3D


func setup(world: PileWorld) -> void:
	pile = world
	collision_layer = Binder.PHYSICS_LAYER
	collision_mask = 0
	_shape = BoxShape3D.new()
	_collision = CollisionShape3D.new()
	_collision.shape = _shape
	add_child(_collision)

	_top = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = PileWorld.CARD_SIZE
	_top.mesh = quad
	_top.material_override = ShaderMaterial.new()
	_top.material_override.shader = preload("res://shaders/binder_card.gdshader")
	_top.rotation.x = -PI / 2
	add_child(_top)

	_side = MeshInstance3D.new()
	_side.mesh = BoxMesh.new()
	var side_material := StandardMaterial3D.new()
	side_material.albedo_color = Color(0.85, 0.83, 0.78)
	_side.material_override = side_material
	add_child(_side)


## Lays the (empty) stack on the floor pile or a table top.
func place(point: Vector3, yaw: float, on_floor: bool) -> void:
	rotation.y = yaw
	position = point
	if on_floor and pile != null:
		position.y = pile.height_under(Vector2(point.x, point.z), PileWorld.CARD_SIZE / 2, yaw)


func size() -> int:
	return _cards.size()


func top_card() -> int:
	return _cards[-1] if not _cards.is_empty() else -1


## Where the next card pushed will lie, as a global pose for a card quad
## (see Glide).
func next_card_pose() -> Transform3D:
	return Glide.flat_card(to_global(Vector3(0, (_cards.size() + 1) * PileWorld.CARD_THICKNESS, 0)), global_basis)


## Where the top card lies, as a global pose for a card quad.
func top_card_pose() -> Transform3D:
	return Glide.flat_card(_top.global_position, global_basis)


func push(card_id: int) -> void:
	_cards.append(card_id)
	_refresh()


## Takes the top card. The stack frees itself once it's empty.
func pop() -> int:
	if _cards.is_empty():
		return -1
	var id: int = _cards.pop_back()
	if _cards.is_empty():
		queue_free()
	else:
		_refresh()
	return id


func _refresh() -> void:
	var height := maxf(_cards.size() * PileWorld.CARD_THICKNESS, 0.001)
	(_side.mesh as BoxMesh).size = Vector3(PileWorld.CARD_SIZE.x, height, PileWorld.CARD_SIZE.y)
	_side.position.y = height / 2
	_top.position.y = height + 0.0005
	CardView.apply(_top.material_override, _cards[-1])
	# A little taller than the stack so even one card is easy to aim at.
	_shape.size = Vector3(PileWorld.CARD_SIZE.x, height + 0.01, PileWorld.CARD_SIZE.y)
	_collision.position.y = (height + 0.01) / 2
