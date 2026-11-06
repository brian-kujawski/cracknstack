class_name ShippingBox
extends ProductBox
## A shipping box for selling cards: white cardboard with a blue band and
## bold PRIORITY lettering (the look of a priority mail box, no real
## branding). It's handled like a box of product: click to pick it up,
## click to put it down. Take a new one from the flat-packed stack at the
## shipping corner by the door (ShippingStation).
##
## With a card in hand, click the box (standing on the floor or a table) to
## sell the card: it goes into a sleeve, gets a label with its price, drops
## in, and the money is yours at once (Hands.sell_held_card, Shipping.sell).
## Selling can't be undone. The box holds CAPACITY cards. E (aimed at it, or
## with it in hand) seals it shut; set a sealed box on the outgoing mat by
## the door and it's collected overnight when you end the day.
##
## Open, its flaps stand out and the sleeved cards show inside, stacking up
## as it fills. Sealed, its flaps are shut and taped, with a label on top.
## Its origin is the middle of its underside.

## How many cards a plain box holds. Bigger boxes come with tools
## (new_capacity()), and each box keeps the size it was made at.
const CAPACITY := 50
## Outside size (x wide, y tall, z deep), in metres: about 9.5" x 5.5" x 7.5".
const SIZE := Vector3(0.24, 0.14, 0.19)
const WALL := 0.004
## A sleeved card, lying in the box: a little bigger than the card.
const SLEEVE := Vector2(0.066, 0.091)
## Each sleeved card adds this much to the stack inside.
const CARD_STACK := 0.0018
const WHITE := Color(0.95, 0.95, 0.94)
const BLUE := Color(0.1, 0.22, 0.52)
const RED := Color(0.72, 0.12, 0.14)
const TAPE := Color(0.82, 0.74, 0.55, 0.85)
## How far the open flaps lean out past upright.
const FLAP_LEAN := deg_to_rad(35.0)

## How many cards this box holds, and its outside size, which grows with
## that (sized()).
var capacity := CAPACITY
var size := SIZE
## Cards in it.
var cards := 0
## Shut and taped: it takes no more cards, and ships from the outgoing mat.
var sealed := false

var _stack: MeshInstance3D
var _top_card: MeshInstance3D
var _flaps: Array[Node3D] = []
var _sealed_parts: Node3D
var _white: StandardMaterial3D


func _init() -> void:
	name = "ShippingBox"


## How many cards a new box holds: CAPACITY, or more with the bigger
## boxes (Tools "boxes_100", "boxes_300").
static func new_capacity() -> int:
	if Progression.has_tool("boxes_300"):
		return 300
	if Progression.has_tool("boxes_100"):
		return 100
	return CAPACITY


## The outside size of a box that holds `holds` cards: the plain box,
## taller for more.
static func sized(holds: int) -> Vector3:
	return Vector3(SIZE.x, SIZE.y * (1.0 + 0.5 * log(float(holds) / CAPACITY) / log(2.0)), SIZE.z) \
		if holds > CAPACITY else SIZE


## Each sleeved card adds this much to the stack inside, so a full box is
## nearly full to the top.
func card_stack() -> float:
	return minf(CARD_STACK, (size.y - 0.03) / capacity)


## Builds it, empty and open (in place of ProductBox.setup). `fill` and
## `shut` put back a saved box, and `holds` its capacity (new_capacity()
## when not given).
func build(fill := 0, shut := false, holds := -1) -> void:
	capacity = holds if holds > 0 else new_capacity()
	size = sized(capacity)
	set_code = ""
	collision_layer = Binder.PHYSICS_LAYER
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = size
	shape.shape = collider
	shape.position.y = size.y / 2
	add_child(shape)
	_white = _material(WHITE, 0.85)
	var blue := _material(BLUE, 0.7)
	var inside := _material(Color(0.78, 0.72, 0.6), 0.95)
	var half := size / 2
	# The bottom and four walls, white outside, plain cardboard inside.
	_add_part(Vector3(size.x, WALL, size.z), Vector3(0, WALL / 2, 0), _white)
	for side in [-1, 1]:
		_add_part(Vector3(size.x, size.y, WALL), Vector3(0, half.y, side * (half.z - WALL / 2)), _white)
		_add_part(Vector3(WALL, size.y, size.z - 2 * WALL), Vector3(side * (half.x - WALL / 2), half.y, 0), _white)
		_add_part(Vector3(size.x - 2 * WALL, size.y - WALL, 0.0005), Vector3(0, half.y + WALL / 2, side * (half.z - WALL - 0.00025)), inside)
	# The blue band round the bottom, and a thin red line over it.
	for side in [-1, 1]:
		_add_part(Vector3(size.x + 0.001, size.y * 0.22, 0.001), Vector3(0, size.y * 0.11, side * (half.z + 0.0005)), blue)
		_add_part(Vector3(0.001, size.y * 0.22, size.z + 0.001), Vector3(side * (half.x + 0.0005), size.y * 0.11, 0), blue)
		_add_part(Vector3(size.x + 0.0012, 0.005, 0.0012), Vector3(0, size.y * 0.22 + 0.0025, side * (half.z + 0.0006)), _material(RED, 0.7))
	for face in [[Vector3(0, size.y * 0.6, half.z), Basis()], [Vector3(0, size.y * 0.6, -half.z), Basis(Vector3.UP, PI)]]:
		_print("PRIORITY", face[0], face[1], size.x * 0.8, 2.2, BLUE)
		_print("PARCEL POST", face[0] - Vector3(0, size.y * 0.22, 0), face[1], size.x * 0.5, 1.4, BLUE)
	for side in [-1, 1]:
		_print("PRIORITY", Vector3(side * half.x, size.y * 0.6, 0), Basis(Vector3.UP, side * PI / 2), size.z * 0.8, 2.2, BLUE)

	# The cards inside: a stack of sleeves, and the last one sold on top.
	_stack = MeshInstance3D.new()
	_stack.name = "Stack"
	var stack_mesh := BoxMesh.new()
	stack_mesh.size = Vector3(SLEEVE.x, 1.0, SLEEVE.y)
	_stack.mesh = stack_mesh
	var sleeves := _material(Color(0.86, 0.87, 0.9), 0.3)
	_stack.material_override = sleeves
	add_child(_stack)
	_top_card = MeshInstance3D.new()
	_top_card.name = "TopCard"
	var quad := QuadMesh.new()
	quad.size = PileWorld.CARD_SIZE
	_top_card.mesh = quad
	_top_card.rotation.x = -PI / 2
	var face_material := ShaderMaterial.new()
	face_material.shader = preload("res://shaders/held_card.gdshader")
	_top_card.material_override = face_material
	_top_card.visible = false
	add_child(_top_card)

	# Four flaps, hinged on the top edges, standing open.
	for flap in [[Vector3(0, size.y, half.z), Vector3(size.x, half.z, WALL), Vector3.RIGHT, 1.0],
			[Vector3(0, size.y, -half.z), Vector3(size.x, half.z, WALL), Vector3.RIGHT, -1.0],
			[Vector3(half.x, size.y, 0), Vector3(WALL, half.z * 0.8, size.z), Vector3.BACK, -1.0],
			[Vector3(-half.x, size.y, 0), Vector3(WALL, half.z * 0.8, size.z), Vector3.BACK, 1.0]]:
		var hinge := Node3D.new()
		hinge.position = flap[0]
		hinge.set_meta("axis", flap[2])
		hinge.set_meta("side", flap[3])
		add_child(hinge)
		var panel := MeshInstance3D.new()
		var panel_mesh := BoxMesh.new()
		var panel_size: Vector3 = flap[1]
		panel_mesh.size = panel_size
		panel.mesh = panel_mesh
		panel.material_override = _white
		panel.position = Vector3(0, panel_size.y / 2, 0)
		hinge.add_child(panel)
		_flaps.append(hinge)

	# Sealed: a lid of shut flaps, a strip of tape, and a shipping label.
	_sealed_parts = Node3D.new()
	_sealed_parts.name = "Sealed"
	add_child(_sealed_parts)
	_add_part(Vector3(size.x, WALL, size.z), Vector3(0, size.y - WALL / 2, 0), _white, _sealed_parts)
	_add_part(Vector3(size.x * 0.98, 0.0006, 0.05), Vector3(0, size.y + 0.0003, 0), _material(TAPE, 0.3), _sealed_parts)
	_add_part(Vector3(0.05, 0.0006, size.z * 0.98), Vector3(0, size.y + 0.0004, 0), _material(TAPE, 0.3), _sealed_parts)
	var label_at := Vector3(size.x * 0.24, size.y + 0.0008, size.z * 0.1)
	_add_part(Vector3(0.09, 0.0005, 0.06), label_at, _material(ProductBox.LABEL_PAPER, 0.9), _sealed_parts)
	var top := Basis(Vector3.RIGHT, -PI / 2)
	_print_on(_sealed_parts, "PRIORITY", label_at + Vector3(0, 0.0004, -0.018), top, 0.08, 0.9, BLUE)
	_print_on(_sealed_parts, "TO: CARD BUYER", label_at + Vector3(0, 0.0004, 0.004), top, 0.08, 0.6, ProductBox.INK)
	_print_on(_sealed_parts, "|| ||| | || |||| | ||", label_at + Vector3(0, 0.0004, 0.02), top, 0.08, 0.7, ProductBox.INK)

	cards = clampi(fill, 0, capacity)
	sealed = shut and cards > 0
	_refresh()


func box_size() -> Vector3:
	return size


## What it's called in the corner while in hand.
func details() -> String:
	if sealed:
		return "Shipping Box\nSealed: %d cards" % cards
	return "Shipping Box\n%d/%d cards" % [cards, capacity]


## Whether a card can go in: open, and not full.
func has_room() -> bool:
	return not sealed and cards < capacity


## Whether E seals it now: open, with something in it.
func can_seal() -> bool:
	return not sealed and cards > 0


## A sold card has dropped in (copy `id`, shown on top if it's given).
func add_card(id := -1) -> void:
	if not has_room():
		return
	cards += 1
	if id >= 0:
		CardView.apply(_top_card.material_override, id)
		_top_card.set_meta("card_id", id)
	_refresh()


## Shuts and tapes it. Returns whether it was sealed now.
func seal() -> bool:
	if not can_seal():
		return false
	sealed = true
	_refresh()
	return true


## Where a sold card goes in (global): lying flat on the stack inside.
func card_slot_pose() -> Transform3D:
	var at := Vector3(0, WALL + cards * card_stack() + 0.002, 0)
	return global_transform * Transform3D(Basis(Vector3.RIGHT, -PI / 2), at)


## Just above the opening, where a sold card waits a moment before it drops.
func card_entry_pose() -> Transform3D:
	return global_transform * Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, size.y + 0.06, 0))


func _refresh() -> void:
	var height := cards * card_stack()
	_stack.visible = cards > 0 and not sealed
	_stack.scale.y = maxf(height, 0.0001)
	_stack.position.y = WALL + height / 2
	_top_card.visible = _stack.visible and _top_card.has_meta("card_id")
	_top_card.position.y = WALL + height + 0.0004
	for hinge in _flaps:
		hinge.visible = not sealed
		var axis: Vector3 = hinge.get_meta("axis")
		var side: float = hinge.get_meta("side")
		hinge.basis = Basis(axis, side * FLAP_LEAN)
	_sealed_parts.visible = sealed


func _material(colour: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _add_part(part_size: Vector3, at: Vector3, material: Material, parent: Node3D = self) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = part_size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = material
	parent.add_child(mesh)


## ProductBox._print, onto `parent` instead of the box itself.
func _print_on(parent: Node3D, text: String, at: Vector3, face: Basis, width: float, share: float, colour: Color) -> void:
	var before := get_child_count()
	_print(text, at, face, width, share, colour)
	var label := get_child(before)
	remove_child(label)
	parent.add_child(label)
