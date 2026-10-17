class_name Hands
extends Node
## The player's hands. One thing at a time: a card or a binder.
##
## Left-click is context sensitive:
## - empty-handed: pick up the card under the crosshair (from the floor, an
##   unsorted stack, or an unlocked card in an open binder), or pick up a
##   closed binder (off the floor, a table or a shelf);
## - holding a card: file it into the binder pocket you're looking at, put it
##   on the stack you're looking at, or else bring it up close to your face
##   (click again to lower it);
## - carrying a binder: set it down on the floor or a table, or stand it in
##   the shelf space you're looking at.
## Right-click tosses a held card back onto the pile. E opens or closes the
## binder you're looking at, the mouse wheel turns its pages, and F puts the
## held card on an unsorted stack (starting one where you're looking).

signal held_changed(card: CardData, binder: BinderRange)
## What the thing under the crosshair is and what you can do with it.
signal hint_changed(text: String)

enum Aim { NONE, FLOOR, SURFACE, BINDER, STACK, SHELF }

## How far from the eye the player can reach.
@export var reach := 2.6
## Toss: each throw picks its forward and upward speed (m/s) and its
## end-over-end flip rate (flips per second) at random between min and max.
## A gentle lob, not a throw.
@export var toss_forward_speed_min := 1.4
@export var toss_forward_speed_max := 1.8
@export var toss_up_speed_min := 0.8
@export var toss_up_speed_max := 1.2
@export var toss_flips_per_second_min := 0.8
@export var toss_flips_per_second_max := 1.8
## Slight wobble on the other two axes, up to this many turns per second
## either way: roll around the card's long axis, and spin flat like a
## frisbee. Keep these well under the flip rate so the flip still reads.
@export var toss_roll_per_second_max := 0.25
@export var toss_spin_per_second_max := 0.35
@export var zoom_seconds := 0.18

## Where the held card sits relative to the camera: low and to the right,
## or close up and square to your face.
const HELD_POSITION := Vector3(0.075, -0.05, -0.2)
const HELD_ROTATION := Vector3(0.12, -0.25, 0.04)
const ZOOMED_POSITION := Vector3(0.0, 0.0, -0.11)
const ZOOMED_ROTATION := Vector3.ZERO
## A carried binder: held low and to the right, cover tilted toward you.
const CARRIED_POSITION := Vector3(0.3, -0.36, -0.55)
const CARRIED_ROTATION := Vector3(0.7, -0.5, 0.0)

var pile: PileWorld
var held_card_id := -1
var carried_binder: Binder

@onready var _camera: Camera3D = get_parent().get_node("Camera3D")
var _held_view: MeshInstance3D
var _zoomed := false
var _zoom_tween: Tween

var _aim := Aim.NONE
var _aim_point := Vector3.ZERO
var _aim_binder: Binder
var _aim_pocket := -1
var _aim_stack: UnsortedStack
var _aim_shelf: ShelfUnit
var _aim_space := -1
var _hovered_binder: Binder
var _hint := ""


func _ready() -> void:
	_held_view = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = PileWorld.CARD_SIZE
	_held_view.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/held_card.gdshader")
	_held_view.material_override = material
	_held_view.position = HELD_POSITION
	_held_view.rotation = HELD_ROTATION
	_held_view.visible = false
	_camera.add_child(_held_view)


func _physics_process(_delta: float) -> void:
	if pile == null:
		return
	_update_aim()
	var target := pile.top_card_at(_aim_point) if _aim == Aim.FLOOR and _hands_empty() else -1
	pile.set_highlight(target)
	_update_hover()
	_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	if pile == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("use_hand"):
		_use_hand()
	elif event.is_action_pressed("toss") and held_card_id >= 0:
		_toss()
		_hold(-1)
	elif event.is_action_pressed("interact"):
		_toggle_binder()
	elif event.is_action_pressed("stack_card"):
		_stack_held_card()
	elif event.is_action_pressed("flip_next"):
		_flip(1)
	elif event.is_action_pressed("flip_previous"):
		_flip(-1)


func _hands_empty() -> bool:
	return held_card_id < 0 and carried_binder == null


func _use_hand() -> void:
	if carried_binder != null:
		match _aim:
			Aim.SHELF:
				_shelve_carried_binder()
			Aim.FLOOR, Aim.SURFACE:
				_set_binder_down()
		return
	if held_card_id >= 0:
		if _try_file_held_card():
			return
		if _aim == Aim.STACK:
			_aim_stack.push(held_card_id)
			_hold(-1)
		else:
			_set_zoomed(not _zoomed)
		return
	match _aim:
		Aim.FLOOR:
			var id := pile.top_card_at(_aim_point)
			if id >= 0:
				pile.pick_up(id)
				_hold(id)
		Aim.STACK:
			_hold(_aim_stack.pop())
		Aim.BINDER:
			if _aim_binder.is_open():
				var id := _aim_binder.take(_aim_pocket)
				if id >= 0:
					_hold(id)
			else:
				_carry(_aim_binder)


## Files the held card into the binder pocket under the crosshair. Returns
## false if there's no pocket there (so the click does something else).
func _try_file_held_card() -> bool:
	if _aim != Aim.BINDER or not _aim_binder.is_open() or _aim_pocket < 0:
		return false
	var binder := _aim_binder
	var result := binder.insert(_aim_pocket, held_card_id)
	if result == BinderContents.Result.OCCUPIED:
		return true # The pocket's taken; the card stays in hand.
	var at := binder.to_global(binder.pocket_position(_aim_pocket))
	if result == BinderContents.Result.LOCKED:
		var page := _aim_pocket / BinderLayout.POCKETS_PER_PAGE
		var sound := FeedbackSounds.Kind.CARD_LOCKED
		if binder.contents.is_complete():
			sound = FeedbackSounds.Kind.BINDER_COMPLETE
		elif binder.contents.is_page_complete(page):
			sound = FeedbackSounds.Kind.PAGE_COMPLETE
		FeedbackSounds.play(pile, at, sound)
	# Misplaced: it stays in the pocket glowing red, and makes no sound.
	_hold(-1)
	return true


func _toggle_binder() -> void:
	if carried_binder != null or _aim != Aim.BINDER:
		return
	if _aim_binder.is_open():
		_aim_binder.close()
	elif _aim_binder.state == Binder.State.CLOSED:
		_aim_binder.open()


func _flip(direction: int) -> void:
	if _aim == Aim.BINDER and _aim_binder.is_open():
		_aim_binder.flip(direction)


func _stack_held_card() -> void:
	if held_card_id < 0:
		return
	if _aim == Aim.STACK:
		_aim_stack.push(held_card_id)
	elif _aim == Aim.FLOOR or _aim == Aim.SURFACE:
		var stack := UnsortedStack.new()
		stack.setup(pile)
		pile.add_child(stack)
		var yaw := _yaw_facing_player(_aim_point)
		stack.place(_clear_of_obstacles(_aim_point, PileWorld.CARD_SIZE / 2, yaw), yaw, _aim == Aim.FLOOR)
		stack.push(held_card_id)
	else:
		return
	_hold(-1)


func _carry(binder: Binder) -> void:
	if binder.state == Binder.State.SHELVED:
		binder.shelf_unit.unshelve(binder.shelf_space)
	binder.carry(_camera, CARRIED_POSITION, CARRIED_ROTATION)
	carried_binder = binder
	held_changed.emit(null, binder.binder)


func _set_binder_down() -> void:
	var yaw := _yaw_facing_player(_aim_point)
	carried_binder.put_down(pile, _clear_of_obstacles(_aim_point, Binder.OPEN_HALF_FOOTPRINT, yaw), yaw, _aim == Aim.FLOOR)
	carried_binder = null
	held_changed.emit(null, null)


func _shelve_carried_binder() -> void:
	if _aim_shelf.shelved[_aim_space] != null:
		return
	var binder := carried_binder
	carried_binder = null
	var correct := _aim_shelf.shelve(_aim_space, binder)
	held_changed.emit(null, null)
	if correct:
		var lit := _aim_shelf.is_section_complete(_aim_shelf.shelf_of(_aim_space))
		FeedbackSounds.play(pile, binder.global_position,
			FeedbackSounds.Kind.SECTION_COMPLETE if lit else FeedbackSounds.Kind.BINDER_SHELVED)


## On the floor, nudges a footprint at `point` clear of walls, shelves and
## table legs. Table tops are left as aimed.
func _clear_of_obstacles(point: Vector3, half_size: Vector2, yaw: float) -> Vector3:
	if _aim != Aim.FLOOR:
		return point
	var p := pile.clear_point(Vector2(point.x, point.z), half_size, yaw)
	return Vector3(p.x, point.y, p.y)


## Turned so its bottom edge (local +z) faces the player.
func _yaw_facing_player(point: Vector3) -> float:
	var to_player := _camera.global_position - point
	return atan2(to_player.x, to_player.z)


func _update_aim() -> void:
	_aim = Aim.NONE
	_aim_binder = null
	_aim_pocket = -1
	_aim_stack = null
	_aim_shelf = null
	_aim_space = -1
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * reach
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [(get_parent() as CollisionObject3D).get_rid()]
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	_aim_point = hit.position
	var collider: Object = hit.collider
	if collider is Binder:
		_aim = Aim.BINDER
		_aim_binder = collider
		_aim_pocket = _aim_binder.pocket_at(hit.position)
	elif collider is UnsortedStack:
		_aim = Aim.STACK
		_aim_stack = collider
	elif collider is ShelfUnit:
		var space: int = collider.space_at(hit.position)
		if space < 0:
			return
		if collider.shelved[space] != null:
			_aim = Aim.BINDER
			_aim_binder = collider.shelved[space]
		else:
			_aim = Aim.SHELF
			_aim_shelf = collider
			_aim_space = space
	elif hit.normal.y > 0.9:
		# The floor itself is at y = 0; anything higher is a table or counter.
		_aim = Aim.FLOOR if hit.position.y < 0.05 else Aim.SURFACE


func _update_hover() -> void:
	var binder := _aim_binder if _aim == Aim.BINDER else null
	if _hovered_binder != binder and is_instance_valid(_hovered_binder):
		_hovered_binder.set_hover(-1)
	_hovered_binder = binder
	if binder != null:
		binder.set_hover(_aim_pocket)


func _update_hint() -> void:
	var text := ""
	match _aim:
		Aim.BINDER:
			text = _binder_hint(_aim_binder)
		Aim.STACK:
			text = "Unsorted stack · %d card%s" % [_aim_stack.size(), "" if _aim_stack.size() == 1 else "s"]
			if _hands_empty():
				text += "\nclick: take the top card"
			elif held_card_id >= 0:
				text += "\nclick or F: add this card"
		Aim.SHELF:
			var space: BinderRange = _aim_shelf.spaces[_aim_space]
			text = "Shelf space for %s" % space.label
			if carried_binder != null:
				text += "\nclick: shelve this binder"
		Aim.FLOOR, Aim.SURFACE:
			if carried_binder != null:
				text = "click: set the binder down"
			elif held_card_id >= 0:
				text = "F: start an unsorted stack here"
			elif _aim == Aim.FLOOR and pile.top_card_at(_aim_point) >= 0:
				text = "click: pick up"
	if text.is_empty() and held_card_id >= 0:
		text = "click: look closer · right-click: toss"
	if text != _hint:
		_hint = text
		hint_changed.emit(text)


func _binder_hint(binder: Binder) -> String:
	var contents := binder.contents
	var text := "%s · %d of %d filed" % [binder.binder.label, contents.locked_count, contents.capacity()]
	match binder.state:
		Binder.State.SHELVED:
			var correct: bool = binder.shelf_unit.spaces[binder.shelf_space] == binder.binder
			text += "\n%s · click: take it down" % ("On its shelf" if correct else "Wrong shelf space")
		Binder.State.CLOSED:
			if carried_binder == null:
				text += "\nE: open · click: pick up"
		Binder.State.OPEN:
			var pages := BinderLayout.spread_pages(binder.binder, binder.spread)
			var shown := []
			for page in [pages.x, pages.y]:
				if page >= 0:
					shown.append(str(page + 1))
			text += "\npage %s of %d · scroll: turn pages · E: close" % [
				"–".join(shown) if not shown.is_empty() else "cover", BinderLayout.page_count(binder.binder)]
			if _aim_pocket >= 0:
				text += "\n" + _pocket_hint(binder, _aim_pocket)
	return text


func _pocket_hint(binder: Binder, pocket: int) -> String:
	var number := binder.binder.first + pocket
	var id := binder.contents.card_at(pocket)
	if id < 0:
		return "#%d · empty%s" % [number, " · click: file this card" if held_card_id >= 0 else ""]
	var card := CardDatabase.get_card(id)
	if binder.contents.is_locked(pocket):
		return "#%d · %s" % [number, card.name]
	return "#%d · %s %s #%d doesn't belong here%s" % [number, card.name, card.set_code, card.collector_number,
		" · click: take it out" if _hands_empty() else ""]


func _toss() -> void:
	var forward := -_camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var card := TossedCard.new()
	# The tossed card gets its own material so the next pick-up can change
	# the hand without changing the card in flight.
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/held_card.gdshader")
	CardView.apply(material, held_card_id)
	pile.add_child(card)
	card.exclude = [(get_parent() as CollisionObject3D).get_rid()]
	var velocity := forward * randf_range(toss_forward_speed_min, toss_forward_speed_max) \
			+ Vector3.UP * randf_range(toss_up_speed_min, toss_up_speed_max)
	# Turns per second around the card's own axes: mostly end over end
	# (left-right axis), with a little roll (long axis) and flat spin (face
	# normal) so no two tosses tumble quite the same.
	var flips := randf_range(toss_flips_per_second_min, toss_flips_per_second_max) * (1 if randf() < 0.5 else -1)
	var roll := randf_range(-toss_roll_per_second_max, toss_roll_per_second_max)
	var spin := randf_range(-toss_spin_per_second_max, toss_spin_per_second_max)
	card.launch(held_card_id, pile, material, _held_view.global_transform, velocity, Vector3(flips, roll, spin) * TAU)


func _set_zoomed(zoomed: bool) -> void:
	_zoomed = zoomed
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(_held_view, "position", ZOOMED_POSITION if zoomed else HELD_POSITION, zoom_seconds)
	_zoom_tween.tween_property(_held_view, "rotation", ZOOMED_ROTATION if zoomed else HELD_ROTATION, zoom_seconds)


func _hold(id: int) -> void:
	if _zoom_tween:
		_zoom_tween.kill()
	_zoomed = false
	_held_view.position = HELD_POSITION
	_held_view.rotation = HELD_ROTATION
	held_card_id = id
	_held_view.visible = id >= 0
	if id < 0:
		held_changed.emit(null, null)
		return
	CardView.apply(_held_view.material_override, id)
	held_changed.emit(CardDatabase.get_card(id), null)
