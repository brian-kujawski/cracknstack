class_name CardSorter
extends StaticBody3D
## The card sorter (Tools "sorter"): a desk-top machine in the look of a
## 90s money counter, in beige-box plastic with a green readout. It's
## fixed on the work table by the shipping corner (INSTALL_TABLE) and takes
## the table over: the machine at the back, its two pockets in front of
## it, the surplus chute's shipping box at its side, and room in front for
## an open binder.
##
## Click it with cards in hand and the whole hand goes into the hopper.
## It reads them one at a time (cards_per_second()) into two pockets,
## trays just like the Sorting Tray: Needed (a card the collection still
## needs, and not already in the pocket) and Surplus (everything else).
## With empty hands, click a pocket to take its stack into hand; with the
## Sorting Tray in hand, click the Surplus pocket to tip its stack onto
## the tray. Nothing is ever filed for you.
##
## It stops, its readout blinking amber, when the next card has nowhere to
## go: NEEDED FULL or SURPLUS FULL (POCKET cards each). With the Surplus
## Chute ("surplus_chute"), surplus is sold through Sales.sell into the
## shipping box set at the chute (dock_pose()) while that box has room,
## and only then into the pocket. With the Mk II ("sorter_mk2") it runs
## twice as fast, keeps Needed in collector-number order, and holds one
## set at a time: a card of another set than the one in Needed stops it
## (NEW SET) until the Needed stack is taken out.
##
## Its origin is the middle of the table top; the machine's front faces
## local +z, toward the door.

## Sells a surplus card down the chute: copy `id`, for `cents`.
signal card_sold(id: int, cents: int)

## The work table it's fixed on (StoreBuilder.TABLE_CENTERS), and its turn:
## front toward the door on the right-hand wall.
const INSTALL_TABLE := 3
const INSTALL_YAW := PI / 2
## The machine: outside size and its centre on the table (x, z).
const BODY := Vector3(0.45, 0.24, 0.32)
const BODY_AT := Vector2(0.05, -0.25)
## The card hopper on top: outside size, wall thickness.
const HOPPER := Vector3(0.2, 0.14, 0.18)
const HOPPER_WALL := 0.006
## The pockets' centres (x, z), Needed then Surplus (the chute's side).
const NEEDED_AT := Vector2(0.15, -0.01)
const SURPLUS_AT := Vector2(-0.05, -0.01)
## Where the chute's shipping box stands (x, z), and how near a box must
## be put down to snap into place there.
const DOCK_AT := Vector2(-0.43, -0.25)
const DOCK_SNAP := 0.3
## Cards a pocket holds before the machine stops.
const POCKET := 100
## How fast it reads cards, and the Mk II's speed-up (a first guess, to tune
## in playtests).
const CARDS_PER_SECOND := 2.5
const MK2_SPEEDUP := 2.0
## A card in the hopper adds this much to the stack there.
const CARD_STACK := 0.0004
const PLASTIC := Color(0.83, 0.79, 0.69)
const PLASTIC_DARK := Color(0.66, 0.62, 0.53)
const READOUT := Color(0.35, 1.0, 0.45)
const READOUT_STOPPED := Color(1.0, 0.68, 0.18)
const BLINK := 0.5
## Fewest seconds between two sale chimes from the chute.
const CHIME_GAP := 0.8

## Cards fed in and not yet read, the next one first.
var queue: Array[int] = []
var needed_tray: SortingTray
var surplus_tray: SortingTray
## Whether the collection still needs copy `id` (Hands.collection_needs).
var needs: Callable = func(_id: int) -> bool: return false
## Why it's stopped ("" while it can go on): the readout's message.
var stop_reason := ""

var _clock := 0.0
var _blink := 0.0
var _last_chime := -INF
var _readout: Label3D
var _hopper_stack: MeshInstance3D
var _window_card: MeshInstance3D
var _chute: Node3D
var _mk2_badge: Label3D
var _plastic: StandardMaterial3D
var _dark: StandardMaterial3D


func _init() -> void:
	name = "CardSorter"


## The sorter in `pile`, if there is one.
static func find(pile: Node) -> CardSorter:
	if pile == null:
		return null
	for child in pile.get_children():
		if child is CardSorter and not child.is_queued_for_deletion():
			return child
	return null


## Builds a sorter and fixes it on its table in `pile`. Returns it.
static func install(pile: Node3D) -> CardSorter:
	var sorter := CardSorter.new()
	sorter.build()
	pile.add_child(sorter)
	sorter.global_transform = install_pose()
	return sorter


## Where it stands: the middle of its table's top, turned to the door.
static func install_pose() -> Transform3D:
	var store := preload("res://scripts/store/store_builder.gd")
	var table: Vector2 = store.TABLE_CENTERS[INSTALL_TABLE]
	return Transform3D(Basis(Vector3.UP, INSTALL_YAW), Vector3(table.x, store.TABLE_SIZE.y, table.y))


func build() -> void:
	collision_layer = Binder.PHYSICS_LAYER
	collision_mask = 0
	_plastic = _material(PLASTIC, 0.55)
	_dark = _material(PLASTIC_DARK, 0.6)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BODY.x, BODY.y + HOPPER.y, BODY.z)
	shape.shape = box
	shape.position = Vector3(BODY_AT.x, box.size.y / 2, BODY_AT.y)
	add_child(shape)
	_build_body()
	_build_hopper()
	_build_front()
	needed_tray = _pocket("NeededPocket", NEEDED_AT)
	surplus_tray = _pocket("SurplusPocket", SURPLUS_AT)
	_build_chute()
	refresh()


## Shows the upgrades owned (the chute, the Mk II badge).
func refresh() -> void:
	_chute.visible = has_chute()
	_mk2_badge.visible = is_mk2()
	_refresh_hopper()
	_show_readout()


func has_chute() -> bool:
	return Progression.has_tool("surplus_chute")


func is_mk2() -> bool:
	return Progression.has_tool("sorter_mk2")


func cards_per_second() -> float:
	return CARDS_PER_SECOND * (MK2_SPEEDUP if is_mk2() else 1.0)


## What it says in the corner while you aim at it.
func details() -> String:
	return "Card Sorter%s\n%d waiting  ·  %d needed  ·  %d surplus" % [" Mk II" if is_mk2() else "",
		queue.size(), needed_tray.cards.size(), surplus_tray.cards.size()]


## Cards go into the hopper, after those already waiting.
func feed(ids: Array[int]) -> void:
	queue.append_array(ids)
	_refresh_hopper()
	_show_readout()


## Where a fed card drops in (global): just over the hopper.
func hopper_pose() -> Transform3D:
	return global_transform * Transform3D(Basis(Vector3.RIGHT, -PI / 2),
		Vector3(BODY_AT.x, BODY.y + HOPPER.y + 0.03, BODY_AT.y - 0.01))


## Where the chute's shipping box stands (global), and the box there now, if
## an open one is (null if not, or without the chute).
func dock_pose() -> Transform3D:
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(DOCK_AT.x, 0, DOCK_AT.y))


func docked_box() -> ShippingBox:
	if not has_chute() or get_parent() == null:
		return null
	var dock := dock_pose().origin
	for child in get_parent().get_children():
		if child is ShippingBox and not child.sealed and not child.is_queued_for_deletion() \
				and absf(child.global_position.y - dock.y) < 0.05 \
				and Vector2(child.global_position.x - dock.x, child.global_position.z - dock.z).length() < 0.12:
			return child
	return null


## Whether a box put down at global point `at` snaps into the dock.
func snaps_to_dock(at: Vector3) -> bool:
	var dock := dock_pose().origin
	return has_chute() and absf(at.y - dock.y) < 0.05 and Vector2(at.x - dock.x, at.z - dock.z).length() < DOCK_SNAP


## Whether copy `id` goes to Needed: still needed, and no copy of its card
## is in the pocket already.
func goes_to_needed(id: int) -> bool:
	if not needs.call(id):
		return false
	var card := Collection.card_id(id)
	for other in needed_tray.cards:
		if Collection.card_id(other) == card:
			return false
	return true


## Why copy `id` can't be read now ("" if it can).
func blocker(id: int) -> String:
	if is_mk2() and not needed_tray.cards.is_empty() \
			and Collection.card(id).set_code != Collection.card(needed_tray.cards[0]).set_code:
		return "NEW SET: %s\nEMPTY NEEDED" % Collection.card(id).set_code
	if goes_to_needed(id):
		return "NEEDED FULL" if needed_tray.cards.size() >= POCKET else ""
	if docked_box() != null and docked_box().has_room():
		return ""
	return "SURPLUS FULL" if surplus_tray.cards.size() >= POCKET else ""


## Reads the next card into its pocket (or down the chute). Returns whether
## one was read; if not, stop_reason says why.
func sort_next() -> bool:
	if queue.is_empty():
		return false
	var id: int = queue[0]
	stop_reason = blocker(id)
	if stop_reason != "":
		_show_readout()
		return false
	queue.pop_front()
	CardView.apply(_window_card.material_override, id)
	_window_card.visible = true
	if goes_to_needed(id):
		var cards: Array[int] = needed_tray.cards.duplicate()
		var at := cards.size()
		if is_mk2():
			# Kept highest number at the bottom, so the lowest is on top.
			var number := Collection.card(id).collector_number
			at = 0
			while at < cards.size() and Collection.card(cards[at]).collector_number > number:
				at += 1
		cards.insert(at, id)
		needed_tray.set_cards(cards)
	else:
		var box := docked_box()
		if box != null and box.has_room():
			var cents := Sales.sell(id)
			box.add_card(id)
			card_sold.emit(id, cents)
			var now := Time.get_ticks_msec() / 1000.0
			if now - _last_chime >= CHIME_GAP:
				_last_chime = now
				FeedbackSounds.play(get_parent(), box.global_position, FeedbackSounds.Kind.CARD_SOLD)
		else:
			surplus_tray.add(id)
	_refresh_hopper()
	_show_readout()
	return true


## The Needed stack, top card first, as it comes into hand (Mk II: in
## collector-number order). The pocket is left empty.
func take_needed() -> Array[int]:
	return _take(needed_tray)


## The Surplus stack, the same way.
func take_surplus() -> Array[int]:
	return _take(surplus_tray)


func _take(tray: SortingTray) -> Array[int]:
	var ids: Array[int] = tray.cards.duplicate()
	ids.reverse()
	tray.set_cards([])
	_show_readout()
	return ids


func _process(delta: float) -> void:
	_blink += delta
	if stop_reason != "":
		var lit := fmod(_blink, 2 * BLINK) < BLINK
		_readout.modulate = READOUT_STOPPED if lit else READOUT_STOPPED.darkened(0.7)
		# It starts again once what stopped it is out of the way.
		if not queue.is_empty() and blocker(queue[0]) == "":
			stop_reason = ""
			_show_readout()
		return
	if queue.is_empty():
		_clock = 0.0
		return
	_clock += delta
	var step := 1.0 / cards_per_second()
	while _clock >= step and stop_reason == "" and not queue.is_empty():
		_clock -= step
		sort_next()


func _show_readout() -> void:
	if _readout == null:
		return
	if stop_reason != "":
		_readout.text = stop_reason
		return
	_readout.modulate = READOUT
	if queue.is_empty():
		_readout.text = "READY"
		_window_card.visible = false
	else:
		_readout.text = "SORTING  %03d" % queue.size()


func _refresh_hopper() -> void:
	var height := minf(queue.size() * CARD_STACK, HOPPER.y - 0.01)
	_hopper_stack.visible = not queue.is_empty()
	_hopper_stack.scale.y = maxf(height, 0.0001)
	_hopper_stack.position.y = BODY.y + HOPPER_WALL + height / 2


## The case: a beige box with a darker base band and a sloped front panel.
func _build_body() -> void:
	_part(Vector3(BODY.x, BODY.y - 0.03, BODY.z), Vector3(BODY_AT.x, 0.03 + (BODY.y - 0.03) / 2, BODY_AT.y), _plastic)
	_part(Vector3(BODY.x + 0.01, 0.03, BODY.z + 0.01), Vector3(BODY_AT.x, 0.015, BODY_AT.y), _dark)
	# Vents along the sides.
	for side in [-1.0, 1.0]:
		for i in 5:
			_part(Vector3(0.002, 0.008, BODY.z * 0.5), Vector3(BODY_AT.x + side * (BODY.x / 2 + 0.001), 0.08 + i * 0.02, BODY_AT.y), _dark)


## The hopper on top: an open bin cards drop into, with the fed stack
## showing inside.
func _build_hopper() -> void:
	var at := Vector3(BODY_AT.x, BODY.y, BODY_AT.y - 0.01)
	_part(Vector3(HOPPER.x, HOPPER_WALL, HOPPER.z), at + Vector3(0, HOPPER_WALL / 2, 0), _dark)
	for side in [-1.0, 1.0]:
		_part(Vector3(HOPPER.x, HOPPER.y, HOPPER_WALL), at + Vector3(0, HOPPER.y / 2, side * (HOPPER.z - HOPPER_WALL) / 2), _plastic)
		_part(Vector3(HOPPER_WALL, HOPPER.y, HOPPER.z), at + Vector3(side * (HOPPER.x - HOPPER_WALL) / 2, HOPPER.y / 2, 0), _plastic)
	_hopper_stack = MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = Vector3(PileWorld.CARD_SIZE.x, 1.0, PileWorld.CARD_SIZE.y)
	_hopper_stack.mesh = block
	_hopper_stack.material_override = _material(Color(0.9, 0.9, 0.88), 0.8)
	_hopper_stack.position = Vector3(at.x, 0, at.z)
	add_child(_hopper_stack)


## The front: the green readout, the reading window with the card being
## read, the pocket labels and the Mk II badge.
func _build_front() -> void:
	var front := BODY_AT.y + BODY.z / 2
	var screen := _part(Vector3(0.2, 0.05, 0.004), Vector3(BODY_AT.x + 0.08, 0.19, front + 0.002), _material(Color(0.04, 0.06, 0.05), 0.3))
	screen.name = "ReadoutGlass"
	_readout = Label3D.new()
	_readout.name = "Readout"
	_readout.font_size = 40
	_readout.outline_size = 0
	_readout.pixel_size = 0.0007
	_readout.modulate = READOUT
	_readout.shaded = false
	_readout.double_sided = false
	_readout.position = Vector3(BODY_AT.x + 0.08, 0.19, front + 0.0045)
	add_child(_readout)
	# The reading window: a dark slot with the card showing through it.
	_part(Vector3(0.1, 0.07, 0.003), Vector3(BODY_AT.x - 0.12, 0.17, front + 0.0015), _material(Color(0.08, 0.08, 0.09), 0.2))
	_window_card = MeshInstance3D.new()
	_window_card.name = "WindowCard"
	var quad := QuadMesh.new()
	quad.size = PileWorld.CARD_SIZE * 0.85
	_window_card.mesh = quad
	_window_card.basis = Basis(Vector3.FORWARD, PI / 2) # On its side, read as it passes.
	_window_card.position = Vector3(BODY_AT.x - 0.12, 0.17, front + 0.0035)
	_window_card.scale = Vector3(0.75, 0.75, 1)
	var face := ShaderMaterial.new()
	face.shader = preload("res://shaders/binder_card.gdshader")
	_window_card.material_override = face
	_window_card.visible = false
	add_child(_window_card)
	for pocket in [[NEEDED_AT, "NEEDED"], [SURPLUS_AT, "SURPLUS"]]:
		var label := _print(pocket[1], Vector3(pocket[0].x, 0.06, front + 0.002))
		label.name = "%sLabel" % pocket[1].capitalize()
	_mk2_badge = _print("MK II", Vector3(BODY_AT.x - 0.17, 0.215, front + 0.002))
	_mk2_badge.name = "Mk2Badge"
	_print("CARD SORTER", Vector3(BODY_AT.x - 0.1, 0.225, front + 0.002)).font_size = 18


## The chute: a beige slide out of the left side down into the box at the dock.
func _build_chute() -> void:
	_chute = Node3D.new()
	_chute.name = "Chute"
	add_child(_chute)
	var side := BODY_AT.x - BODY.x / 2
	var length := 0.18
	var slide := Node3D.new()
	slide.position = Vector3(side - 0.07, 0.17, BODY_AT.y)
	slide.rotation.z = deg_to_rad(25.0)
	_chute.add_child(slide)
	_part(Vector3(length, 0.004, 0.1), Vector3.ZERO, _plastic, slide)
	for edge in [-1.0, 1.0]:
		_part(Vector3(length, 0.02, 0.004), Vector3(0, 0.01, edge * 0.05), _plastic, slide)
	_part(Vector3(0.012, 0.06, 0.11), Vector3(side - 0.006, 0.17, BODY_AT.y), _dark, _chute)


## One pocket: a tray like the Sorting Tray, fixed in front of the machine.
func _pocket(pocket_name: String, at: Vector2) -> SortingTray:
	var tray := SortingTray.new()
	tray.build()
	tray.name = pocket_name
	tray.set_meta("sorter_pocket", true)
	tray.position = Vector3(at.x, 0, at.y)
	add_child(tray)
	return tray


func _print(text: String, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 22
	label.outline_size = 0
	label.pixel_size = 0.0004
	label.modulate = Color(0.25, 0.22, 0.18)
	label.position = at
	add_child(label)
	return label


func _material(colour: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material


func _part(part_size: Vector3, at: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = part_size
	part.mesh = mesh
	part.position = at
	part.material_override = material
	parent.add_child(part)
	return part
