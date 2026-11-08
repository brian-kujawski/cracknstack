class_name SortingTray
extends ProductBox
## The sorting tray (Tools "sorting_tray"): a long, narrow wooden box to keep
## on a table while you rip, the way people sort cards for real. Cards stand
## in it nearly upright, leaning back a few degrees, one in front of the
## other: the first against the back wall, the last one dropped at the front
## with its face toward you. It holds `capacity` cards (CAPACITY, or the
## sorter's POCKET for its pockets) and then takes no more.
##
## With a card in hand, click the tray to drop a duplicate in (a card the
## collection still needs stays in hand). Pick the tray up like a box, click
## a shipping box, and the cards are sold into it in one go, front card first
## (Hands.sell_tray), as many as the box has room for. It's handled like any
## box otherwise: put down, tossed, saved with the copies in it.
##
## Its origin is the middle of its underside; its front is its local +Z.

## How many cards the Sorting Tray holds.
const CAPACITY := 250
## How far the cards lean back from upright.
const LEAN := deg_to_rad(5.0)
## Each card in it takes this much room front to back.
const CARD_GAP := 0.0004
## The walls: a little over half a card high, so the front card shows.
const WALL_HEIGHT := 0.045
const WALL := 0.006
const BOTTOM := 0.004
## Room left in front of the front card when it's full.
const CLEARANCE := 0.008
const INNER_WIDTH := PileWorld.CARD_SIZE.x + 0.004
const WOOD := Color(0.42, 0.27, 0.16)

## The copies in it, the last one dropped at the front.
var cards: Array[int] = []
## How many it holds, and its outside size (walls only), which follows.
var capacity := CAPACITY
var size := sized(CAPACITY)
## How many of the last cards in `cards` are still dropping in (add).
var _arriving := 0
var _stack: MeshInstance3D
var _stack_material: ShaderMaterial
var _front_card: MeshInstance3D
var _back_card: MeshInstance3D


func _init() -> void:
	name = "SortingTray"


## The outside size of the walls of a tray that holds `holds` cards: long
## enough for them all, standing, plus a little room.
static func sized(holds: int) -> Vector3:
	var inner := (WALL_HEIGHT - BOTTOM) * tan(LEAN) + holds * CARD_GAP + CLEARANCE
	return Vector3(INNER_WIDTH + 2 * WALL, WALL_HEIGHT, inner + 2 * WALL)


## How tall it stands with cards in it: the cards stick up out of it.
static func standing_height() -> float:
	return BOTTOM + PileWorld.CARD_SIZE.y * cos(LEAN)


## Builds it (in place of ProductBox.setup), with `on` copies already in it
## (a saved tray), holding `holds` cards.
func build(on: Array[int] = [], holds := CAPACITY) -> void:
	set_code = ""
	capacity = holds
	size = sized(holds)
	collision_layer = Binder.PHYSICS_LAYER
	collision_mask = 0
	# Its whole height, cards and all, so aiming at a card's top edge
	# counts as aiming at the tray.
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = Vector3(size.x, standing_height(), size.z)
	shape.shape = collider
	shape.position.y = collider.size.y / 2
	add_child(shape)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = WOOD
	wood.roughness = 0.6
	_part(Vector3(size.x, BOTTOM, size.z), Vector3(0, BOTTOM / 2, 0), wood)
	for side in [-1.0, 1.0]:
		_part(Vector3(size.x, WALL_HEIGHT, WALL), Vector3(0, WALL_HEIGHT / 2, side * (size.z - WALL) / 2), wood)
		_part(Vector3(WALL, WALL_HEIGHT, size.z - 2 * WALL), Vector3(side * (size.x - WALL) / 2, WALL_HEIGHT / 2, 0), wood)
	_stack = MeshInstance3D.new()
	_stack.mesh = BoxMesh.new() # A unit box, stretched and leaned by its basis.
	_stack_material = ShaderMaterial.new()
	_stack_material.shader = preload("res://shaders/card_stack.gdshader")
	_stack.material_override = _stack_material
	add_child(_stack)
	_front_card = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = PileWorld.CARD_SIZE
	_front_card.mesh = quad
	var face := ShaderMaterial.new()
	face.shader = preload("res://shaders/binder_card.gdshader")
	_front_card.material_override = face
	add_child(_front_card)
	# The back of the last card, seen from behind over the back wall.
	_back_card = MeshInstance3D.new()
	_back_card.mesh = quad
	var back := StandardMaterial3D.new()
	back.albedo_texture = CardDatabase.card_back
	back.albedo_color = Color.WHITE if CardDatabase.card_back != null else Color(0.35, 0.25, 0.18)
	_back_card.material_override = back
	add_child(_back_card)
	cards.assign(on)
	_refresh()


func box_size() -> Vector3:
	return Vector3(size.x, standing_height(), size.z)


## What it's called in the corner while in hand.
func details() -> String:
	return "Sorting Tray\n%d/%d cards  ·  %s" % [cards.size(), capacity, Progression.money_text(stack_cents())]


## What the cards in it sell for now.
func stack_cents() -> int:
	var cents := 0
	for id in cards:
		cents += Prices.sale_cents(Collection.card(id))
	return cents


## How many more cards it takes.
func room() -> int:
	return maxi(capacity - cards.size(), 0)


func has_room() -> bool:
	return room() > 0


## Copy `id` has gone in at the front. With `arriving`, it's still on its
## way down: it counts (and is saved) at once, but the tray goes on showing
## the card in front before it until it lands (landed).
func add(id: int, arriving := false) -> void:
	cards.append(id)
	if arriving:
		_arriving += 1
	_refresh()


## The copy shown in front now (-1 for none): the last one in that's
## landed.
func front_shown() -> int:
	var shown := cards.size() - _arriving
	return cards[shown - 1] if shown > 0 else -1


## A card added `arriving` has landed: now it's the one shown in front.
func landed() -> void:
	_arriving = maxi(_arriving - 1, 0)
	_refresh()


## These copies go in at the front, in order (the last ends up in front),
## with one redraw for them all.
func add_cards(ids: Array[int]) -> void:
	cards.append_array(ids)
	_refresh()


## Takes the front `count` copies out (all of them by default), front first.
func take(count := -1) -> Array[int]:
	var taken: Array[int] = []
	while not cards.is_empty() and (count < 0 or taken.size() < count):
		taken.append(cards.pop_back())
	_arriving = mini(_arriving, cards.size())
	_refresh()
	return taken


## Puts these copies in in place of what was there, the last in front.
func set_cards(ids: Array[int]) -> void:
	cards.assign(ids)
	_arriving = 0
	_refresh()


## Where a dropped card ends up (global): standing in front of the others.
func card_slot_pose() -> Transform3D:
	return global_transform * _face_pose(cards.size() + 1)


## Where a dropped card comes in from (global): straight above its slot,
## so it drops in without passing through the walls.
func card_entry_pose() -> Transform3D:
	var slot := card_slot_pose()
	slot.origin += global_basis.y.normalized() * (PileWorld.CARD_SIZE.y * 0.7)
	return slot


## Where the front card stands now (global): what comes out first.
func front_card_pose() -> Transform3D:
	return global_transform * _face_pose(cards.size())


## The leaned-back turn of a card standing in it, face to the front.
static func _lean() -> Basis:
	return Basis(Vector3.RIGHT, -LEAN)


## Where the bottom edge of the first card sits, front to back: against the
## back wall, leaning on its top.
func _first_z() -> float:
	return -size.z / 2 + WALL + (WALL_HEIGHT - BOTTOM) * tan(LEAN)


## The face of the front card with `count` cards in (local), just proud of
## the stack.
func _face_pose(count: int) -> Transform3D:
	var lean := _lean()
	var shown := mini(count, capacity) # An over-full saved tray stays inside its walls.
	var bottom := Vector3(0, BOTTOM, _first_z() + shown * CARD_GAP)
	return Transform3D(lean, bottom + lean.y * (PileWorld.CARD_SIZE.y / 2) + lean.z * 0.0003)


func _refresh() -> void:
	var shown := cards.size() - _arriving # Those still on their way aren't in yet.
	var count := mini(shown, capacity)
	var empty := shown <= 0
	_stack.visible = not empty
	_front_card.visible = not empty
	_back_card.visible = not empty
	if empty:
		return
	var lean := _lean()
	var depth := maxf(count * CARD_GAP, 0.0002)
	# Sheared, not turned: the bottom stays flat on the tray and the faces
	# lean back with the cards.
	var shear := Basis(Vector3(PileWorld.CARD_SIZE.x, 0, 0), lean.y * PileWorld.CARD_SIZE.y, Vector3(0, 0, depth))
	_stack.transform = Transform3D(shear, Vector3(0, BOTTOM, _first_z() + depth / 2) + lean.y * (PileWorld.CARD_SIZE.y / 2))
	_stack_material.set_shader_parameter("cards", float(count))
	_front_card.transform = _face_pose(count)
	_back_card.transform = Transform3D(lean * Basis(Vector3.UP, PI),
		Vector3(0, BOTTOM, _first_z()) + lean.y * (PileWorld.CARD_SIZE.y / 2) - lean.z * 0.0003)
	CardView.apply(_front_card.material_override, cards[shown - 1])


func _part(part_size: Vector3, at: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = part_size
	part.mesh = mesh
	part.position = at
	part.material_override = material
	add_child(part)
