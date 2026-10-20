class_name LooseCard
extends StaticBody3D
## A single card the player set down on a table (or on another card lying on
## one), face up and turned toward them. Cards set down on the floor go back
## into the pile instead; only the pile can hold floor cards. Like binders
## it's kinematic and on the binder collision layer, so it can be aimed at,
## picked back up, and have binders and other cards rest on it.

var card_id := -1

var _top: MeshInstance3D


## Lays card `id` with its underside at `point` (global), turned to `yaw`.
func setup(id: int, point: Vector3, yaw: float) -> void:
	card_id = id
	collision_layer = Binder.PHYSICS_LAYER
	collision_mask = 0
	var shape := BoxShape3D.new()
	# A little thicker than the card so it's easy to aim at.
	shape.size = Vector3(PileWorld.CARD_SIZE.x, PileWorld.CARD_THICKNESS + 0.004, PileWorld.CARD_SIZE.y)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = shape.size.y / 2
	add_child(collision)

	var side := MeshInstance3D.new()
	side.mesh = PileWorld.card_mesh(CardDatabase.get_card(id).has_alpha_corners())
	var side_material := StandardMaterial3D.new()
	side_material.albedo_color = Color(0.85, 0.83, 0.78)
	side.material_override = side_material
	side.position.y = PileWorld.CARD_THICKNESS
	add_child(side)

	_top = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = PileWorld.CARD_SIZE
	_top.mesh = quad
	_top.material_override = ShaderMaterial.new()
	_top.material_override.shader = preload("res://shaders/binder_card.gdshader")
	_top.rotation.x = -PI / 2
	_top.position.y = PileWorld.CARD_THICKNESS + 0.0005
	add_child(_top)
	CardView.apply(_top.material_override, id)

	rotation.y = yaw
	position = point


## Where the card lies, as a global pose for a card quad (see Glide).
func card_pose() -> Transform3D:
	return Glide.flat_card(_top.global_position, global_basis)


## The pose a card laid at `point`, turned to `yaw`, will have (see Glide).
static func pose_at(point: Vector3, yaw: float) -> Transform3D:
	return Glide.flat_card(point + Vector3(0, PileWorld.CARD_THICKNESS + 0.0005, 0), Basis(Vector3.UP, yaw))
