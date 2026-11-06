class_name SortingTray
extends ProductBox
## The sorting tray (Tools "sorting_tray"): a shallow wooden tray to keep
## on a table while you rip. With a card in hand, click the tray to drop a
## duplicate on it (a card the collection still needs stays in hand). Pick
## the tray up like a box, click a shipping box, and the whole stack is
## sold into it in one go (Hands.sell_tray), as much as the box has room
## for. It's handled like any box otherwise: put down, tossed, saved with
## the copies on it.
##
## Its origin is the middle of its underside.

## Outside size: a little bigger than a card lying flat, a lip high.
const SIZE := Vector3(0.11, 0.025, 0.14)
const RIM := 0.008
## Each card on it adds this much to the stack, up to the rim and beyond.
const CARD_STACK := 0.0004
const WOOD := Color(0.42, 0.27, 0.16)

## The copies on it, the last one dropped on top.
var cards: Array[int] = []
var _stack: MeshInstance3D
var _top_card: MeshInstance3D


func _init() -> void:
	name = "SortingTray"


## Builds it (in place of ProductBox.setup), with `on` copies already on
## it (a saved tray).
func build(on: Array[int] = []) -> void:
	set_code = ""
	collision_layer = Binder.PHYSICS_LAYER
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = SIZE
	shape.shape = collider
	shape.position.y = SIZE.y / 2
	add_child(shape)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = WOOD
	wood.roughness = 0.6
	_part(Vector3(SIZE.x, RIM / 2, SIZE.z), Vector3(0, RIM / 4, 0), wood)
	for side in [-1.0, 1.0]:
		_part(Vector3(SIZE.x, SIZE.y, RIM), Vector3(0, SIZE.y / 2, side * (SIZE.z - RIM) / 2), wood)
		_part(Vector3(RIM, SIZE.y, SIZE.z - 2 * RIM), Vector3(side * (SIZE.x - RIM) / 2, SIZE.y / 2, 0), wood)
	_stack = MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = Vector3(PileWorld.CARD_SIZE.x, 1.0, PileWorld.CARD_SIZE.y)
	_stack.mesh = block
	var edges := StandardMaterial3D.new()
	edges.albedo_color = Color(0.9, 0.9, 0.88)
	_stack.material_override = edges
	add_child(_stack)
	_top_card = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = PileWorld.CARD_SIZE
	_top_card.mesh = quad
	_top_card.basis = Basis(Vector3.RIGHT, -PI / 2)
	var face := ShaderMaterial.new()
	face.shader = preload("res://shaders/binder_card.gdshader")
	_top_card.material_override = face
	add_child(_top_card)
	cards.assign(on)
	_refresh()


func box_size() -> Vector3:
	return SIZE


## What it's called in the corner while in hand.
func details() -> String:
	return "Sorting Tray\n%d %s  ·  %s" % [cards.size(), "card" if cards.size() == 1 else "cards",
		Progression.money_text(stack_cents())]


## What the stack sells for now.
func stack_cents() -> int:
	var cents := 0
	for id in cards:
		cents += Prices.sale_cents(Collection.card(id))
	return cents


## Copy `id` has landed on top.
func add(id: int) -> void:
	cards.append(id)
	_refresh()


## Takes the top `count` copies off (all of them by default), top first.
func take(count := -1) -> Array[int]:
	var taken: Array[int] = []
	while not cards.is_empty() and (count < 0 or taken.size() < count):
		taken.append(cards.pop_back())
	_refresh()
	return taken


## Where a dropped card goes (global): flat on top of the stack.
func card_slot_pose() -> Transform3D:
	return global_transform * Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, RIM / 2 + cards.size() * CARD_STACK + 0.001, 0))


func _refresh() -> void:
	var height := cards.size() * CARD_STACK
	_stack.visible = not cards.is_empty()
	_stack.scale.y = maxf(height, 0.0001)
	_stack.position.y = RIM / 2 + height / 2
	_top_card.visible = _stack.visible
	_top_card.position.y = RIM / 2 + height + 0.0004
	if not cards.is_empty():
		CardView.apply(_top_card.material_override, cards.back())


func _part(part_size: Vector3, at: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = part_size
	part.mesh = mesh
	part.position = at
	part.material_override = material
	add_child(part)
