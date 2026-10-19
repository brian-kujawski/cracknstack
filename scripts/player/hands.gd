class_name Hands
extends Node
## The player's hands. One thing at a time: a card or a binder.
##
## Keys and buttons are named here by their Controls actions (shown in
## comments as the default bindings). Left-click is context sensitive:
## - empty-handed: pick up the card under the crosshair (from the floor, a
##   table, or an unlocked card in an open binder), or pick up a closed
##   binder (off the floor, a table or a shelf);
## - holding a card: file it into the binder pocket you're looking at, or put
##   it down where you're looking (on the floor it rejoins the pile);
## - carrying a binder: set it down where you're looking, or stand it in the
##   shelf space you're looking at.
## Putting something down happens when the button comes back up. Hold the
## button and a ghost shows where it will go, following your aim, so you can
## place it carefully; a quick click just puts it where you're looking.
## Right-click tosses a held card back onto the pile. F brings the held card
## up close to inspect it (F again lowers it). E opens or closes the binder
## you're looking at, and the mouse wheel turns its pages.
##
## Cards and binders glide between the world and the hand rather than jumping;
## while one is on its way, the hands take no new orders.
##
## While a card is up close, the view holds still and the mouse tilts the card
## instead, directly and within a narrow range, like turning it in your hand.

signal held_changed(card: CardData, binder: BinderRange)
## The card whose details to show: the one in hand, or else a card lying on a
## table that you've held before (null for none).
signal shown_card_changed(card: CardData)
## What the binder under the crosshair holds and what you can do with it.
signal hint_changed(text: String)

enum Aim { NONE, FLOOR, SURFACE, BINDER, LOOSE_CARD, SHELF }

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
## How long a card or binder takes to come to hand or go where it's put, and
## how high a put-down arcs at its midpoint (metres).
@export var card_glide_seconds := 0.16
@export var binder_glide_seconds := 0.24
@export var put_down_lift := 0.04
## Filing: after gliding to just above its pocket, the card slides down into
## it, a little slower.
@export var pocket_slide_seconds := 0.22
## Holding the button this long before letting go shows the ghost.
@export var ghost_after_seconds := 0.12
## How far a card up close can tilt each way (degrees), on both axes. Kept
## narrow so the card never turns far enough to show it's a flat quad.
@export var inspect_tilt_degrees := 15.0

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
## Every card you've held at least once, by id. A card lying on a table is a
## mystery until you've picked it up; from then on you know what it is.
var seen_cards := {}

@onready var _camera: Camera3D = get_parent().get_node("Camera3D")
var _held_view: MeshInstance3D
var _zoomed := false
var _zoom_tween: Tween
## 0 = held low, 1 = up close; tweened, and the held card's pose follows it.
var _zoom_amount := 0.0
## Up-close tilt in radians: x tips the top toward or away from you, y turns
## the face left or right.
var _tilt := Vector2.ZERO
## The glide in progress, if any: something coming to hand or being put down.
var _glide: Tween
## While the button is held to put something down: how long it's been held.
## -1 when not placing.
var _placing := -1.0
var _ghost_card: MeshInstance3D
var _ghost_binder: MeshInstance3D

var _aim := Aim.NONE
var _aim_point := Vector3.ZERO
var _aim_binder: Binder
var _aim_pocket := -1
var _aim_loose_card: LooseCard
var _aim_shelf: ShelfUnit
var _aim_space := -1
var _hovered_binder: Binder
var _hint := ""
var _shown_card: CardData


func _ready() -> void:
	_held_view = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = PileWorld.CARD_SIZE
	_held_view.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/held_card.gdshader")
	_held_view.material_override = material
	_held_view.visible = false
	_camera.add_child(_held_view)
	_pose_held_card()

	var ghost_material := StandardMaterial3D.new()
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.albedo_color = Color(1, 1, 1, 0.35)
	ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_card = MeshInstance3D.new()
	_ghost_card.mesh = quad
	_ghost_binder = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Binder.SIZE
	_ghost_binder.mesh = box
	for ghost in [_ghost_card, _ghost_binder]:
		ghost.material_override = ghost_material
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.top_level = true
		ghost.visible = false
		add_child(ghost)


func _physics_process(delta: float) -> void:
	if pile == null:
		return
	_update_aim()
	var target := pile.top_card_at(_aim_point) if _aim == Aim.FLOOR and _hands_empty() else -1
	pile.set_highlight(target)
	_update_hover()
	_update_ghost(delta)
	_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	if pile == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		if _zoomed:
			# Hands sees input before the player, so marking it handled keeps
			# the view still while the card tilts.
			_tilt = inspect_tilt(_tilt, event.relative, get_parent().mouse_sensitivity, deg_to_rad(inspect_tilt_degrees))
			_pose_held_card()
			get_viewport().set_input_as_handled()
		return
	if _gliding():
		return
	if event.is_action_released(Controls.USE_HAND):
		if _placing >= 0.0:
			_placing = -1.0
			_put_down_where_aimed()
	elif _placing >= 0.0:
		return # One thing at a time while putting something down.
	elif event.is_action_pressed(Controls.USE_HAND):
		_use_hand()
	elif event.is_action_pressed(Controls.TOSS) and held_card_id >= 0:
		_toss()
		_hold(-1)
	elif event.is_action_pressed(Controls.INTERACT):
		_toggle_binder()
	elif event.is_action_pressed(Controls.INSPECT) and held_card_id >= 0:
		_set_zoomed(not _zoomed)
	elif event.is_action_pressed(Controls.FLIP_NEXT):
		_flip(1)
	elif event.is_action_pressed(Controls.FLIP_PREVIOUS):
		_flip(-1)


func _hands_empty() -> bool:
	return held_card_id < 0 and carried_binder == null


func _gliding() -> bool:
	return _glide != null and _glide.is_running()


func _use_hand() -> void:
	if carried_binder != null:
		if _aim == Aim.SHELF:
			_shelve_carried_binder()
		elif _can_put_down():
			_placing = 0.0
		return
	if held_card_id >= 0:
		if not _try_file_held_card() and _can_put_down():
			_placing = 0.0
		return
	match _aim:
		Aim.FLOOR:
			var id := pile.top_card_at(_aim_point)
			if id >= 0:
				var from := pile.card_pose(id)
				pile.pick_up(id)
				_hold(id, from)
		Aim.LOOSE_CARD:
			var card := _aim_loose_card
			var from := card.card_pose()
			card.queue_free()
			_hold(card.card_id, from)
		Aim.BINDER:
			if _aim_binder.is_open():
				if _aim_pocket < 0:
					return
				var from := _aim_binder.pocket_pose(_aim_pocket)
				var id := _aim_binder.take(_aim_pocket)
				if id >= 0:
					_hold(id, from)
			else:
				_carry(_aim_binder)


## Files the held card into the binder pocket under the crosshair. Returns
## false if there's no pocket there (so the click does something else).
func _try_file_held_card() -> bool:
	if _aim != Aim.BINDER or not _aim_binder.is_open() or _aim_pocket < 0:
		return false
	var binder := _aim_binder
	var pocket := _aim_pocket
	if binder.contents.card_at(pocket) >= 0:
		return true # The pocket's taken; the card stays in hand.
	var id := held_card_id
	_put_down_card(binder.pocket_pose(pocket), func() -> void: _file(binder, pocket, id),
		binder.pocket_entry_pose(pocket))
	return true


## The held card has arrived in its pocket.
func _file(binder: Binder, pocket: int, id: int) -> void:
	var result := binder.insert(pocket, id)
	if result != BinderContents.Result.LOCKED:
		return # Misplaced: it stays in the pocket glowing red, and makes no sound.
	var page := pocket / BinderLayout.POCKETS_PER_PAGE
	var sound := FeedbackSounds.Kind.CARD_LOCKED
	if binder.contents.is_complete():
		sound = FeedbackSounds.Kind.BINDER_COMPLETE
	elif binder.contents.is_page_complete(page):
		sound = FeedbackSounds.Kind.PAGE_COMPLETE
	FeedbackSounds.play(pile, binder.to_global(binder.pocket_position(pocket)), sound)


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


## Whether what's in hand can be put down where you're aiming: the floor, a
## table, or (for a card) on top of a card lying on a table.
func _can_put_down() -> bool:
	return _aim == Aim.FLOOR or _aim == Aim.SURFACE or (_aim == Aim.LOOSE_CARD and held_card_id >= 0)


## Where what's in hand would go if put down now: a global pose (a card quad
## for a card, the binder's own pose for a binder), or null if there's
## nowhere to put it.
func _put_down_pose():
	if not _can_put_down():
		return null
	var yaw := _yaw_facing_player(_aim_point)
	if held_card_id >= 0:
		if _aim == Aim.FLOOR:
			return pile.drop_pose(_aim_point, yaw)
		return LooseCard.pose_at(_aim_point, yaw)
	var point := _clear_of_obstacles(_aim_point, Binder.OPEN_HALF_FOOTPRINT, yaw)
	var y := carried_binder.rest_height(Vector2(point.x, point.z), yaw, point.y + Binder.DROP_HEIGHT)
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(point.x, y, point.z))


## Shows the ghost of what's in hand where it would go, once the button has
## been held a moment.
## Pausing lets go of a put-down in progress: its release goes to the pause
## screen, not to us.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _placing >= 0.0:
		_placing = -1.0
		_ghost_card.visible = false
		_ghost_binder.visible = false


func _update_ghost(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_placing = -1.0 # The release won't reach us; let it go.
	var pose = null
	if _placing >= 0.0:
		_placing += delta
		if _placing >= ghost_after_seconds:
			pose = _put_down_pose()
	var ghost := _ghost_card if held_card_id >= 0 else _ghost_binder
	_ghost_card.visible = pose != null and ghost == _ghost_card
	_ghost_binder.visible = pose != null and ghost == _ghost_binder
	if pose == null:
		return
	if ghost == _ghost_binder:
		# The box mesh is centred; a binder's origin is its underside.
		pose = pose.translated_local(Vector3(0, Binder.THICKNESS / 2, 0))
	ghost.global_transform = pose


## The button came up: put what's in hand down where you're aiming now, if
## that's somewhere it can go.
func _put_down_where_aimed() -> void:
	_ghost_card.visible = false
	_ghost_binder.visible = false
	if not _can_put_down():
		return
	if carried_binder != null:
		_set_binder_down()
		return
	var id := held_card_id
	var yaw := _yaw_facing_player(_aim_point)
	if _aim == Aim.FLOOR:
		var point := _aim_point
		_put_down_card(pile.drop_pose(point, yaw), func() -> void: pile.drop(id, point, yaw))
	else:
		var point := _aim_point
		_put_down_card(LooseCard.pose_at(point, yaw), func() -> void:
			var card := LooseCard.new()
			pile.add_child(card)
			card.setup(id, point, yaw))


## Glides the held card to `to` (a global card pose) and calls `land` when it
## gets there. Given `via`, it glides there first and then slides on to `to`.
## The hand is free at once; the card in flight is a copy.
func _put_down_card(to: Transform3D, land: Callable, via = null) -> void:
	var card := MeshInstance3D.new()
	card.mesh = _held_view.mesh
	# Its own material, so the next pick-up can change the hand without
	# changing the card in flight.
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/held_card.gdshader")
	CardView.apply(material, held_card_id)
	card.material_override = material
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pile.add_child(card)
	var from := _held_view.global_transform
	_hold(-1)
	if via is Transform3D:
		_glide = Glide.start(card, from, func() -> Transform3D: return via, card_glide_seconds, put_down_lift)
		Glide.then(_glide, card, via, to, pocket_slide_seconds)
	else:
		_glide = Glide.start(card, from, func() -> Transform3D: return to, card_glide_seconds, put_down_lift)
	_glide.tween_callback(func() -> void:
		land.call()
		card.queue_free())


func _carry(binder: Binder) -> void:
	if binder.state == Binder.State.SHELVED:
		binder.shelf_unit.unshelve(binder.shelf_space)
	var from := binder.global_transform
	binder.carry(_camera, CARRIED_POSITION, CARRIED_ROTATION)
	carried_binder = binder
	held_changed.emit(null, binder.binder)
	var carried := binder.transform
	_glide = Glide.start(binder, from, func() -> Transform3D: return _camera.global_transform * carried, binder_glide_seconds)


func _set_binder_down() -> void:
	var yaw := _yaw_facing_player(_aim_point)
	var binder := carried_binder
	var from := binder.global_transform
	binder.put_down(pile, _clear_of_obstacles(_aim_point, Binder.OPEN_HALF_FOOTPRINT, yaw), yaw)
	carried_binder = null
	held_changed.emit(null, null)
	# put_down() found where it rests; hold it still on the way there, then
	# hand it to physics.
	binder.freeze = true
	var to := binder.global_transform
	_glide = Glide.start(binder, from, func() -> Transform3D: return to, binder_glide_seconds, put_down_lift)
	_glide.tween_callback(binder.let_go)


func _shelve_carried_binder() -> void:
	if _aim_shelf.shelved[_aim_space] != null:
		return
	var binder := carried_binder
	carried_binder = null
	var shelf := _aim_shelf
	var from := binder.global_transform
	var correct := shelf.shelve(_aim_space, binder)
	held_changed.emit(null, null)
	var to := binder.global_transform
	_glide = Glide.start(binder, from, func() -> Transform3D: return to, binder_glide_seconds)
	if correct:
		var lit := shelf.is_section_complete(shelf.shelf_of(_aim_space))
		_glide.tween_callback(func() -> void:
			FeedbackSounds.play(pile, binder.global_position,
				FeedbackSounds.Kind.SECTION_COMPLETE if lit else FeedbackSounds.Kind.BINDER_SHELVED))


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
	_aim_loose_card = null
	_aim_shelf = null
	_aim_space = -1
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * reach
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [(get_parent() as CollisionObject3D).get_rid()]
	# The pile's surface collider is only for binders to rest on; aim at the
	# cards through it.
	query.collision_mask = ~PileWorld.SURFACE_LAYER
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	_aim_point = hit.position
	var collider: Object = hit.collider
	if collider is Binder:
		_aim = Aim.BINDER
		_aim_binder = collider
		_aim_pocket = _aim_binder.pocket_at(hit.position)
	elif collider is LooseCard:
		_aim = Aim.LOOSE_CARD
		_aim_loose_card = collider
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
	var text := _binder_hint(_aim_binder) if _aim == Aim.BINDER else ""
	if text != _hint:
		_hint = text
		hint_changed.emit(text)
	var shown: CardData = null
	if held_card_id >= 0:
		shown = CardDatabase.get_card(held_card_id)
	elif _aim == Aim.LOOSE_CARD and _hands_empty() and seen_cards.has(_aim_loose_card.card_id):
		shown = CardDatabase.get_card(_aim_loose_card.card_id)
	if shown != _shown_card:
		_shown_card = shown
		shown_card_changed.emit(shown)


## How a hint shows an action's key or button (see Controls).
func _key(action: StringName) -> String:
	return Controls.label(action)


func _binder_hint(binder: Binder) -> String:
	var contents := binder.contents
	var lines := PackedStringArray(["Cards Filled: %d/%d (%d%%)" % [
		contents.locked_count, contents.capacity(), floori(100.0 * contents.locked_count / contents.capacity())]])
	match binder.state:
		Binder.State.CLOSED:
			if carried_binder == null:
				lines.append("%s: Open Binder" % _key(Controls.INTERACT))
		Binder.State.OPEN:
			var pages := BinderLayout.spread_pages(binder.binder, binder.spread)
			var shown := []
			for page in [pages.x, pages.y]:
				if page >= 0:
					shown.append(str(page + 1))
			lines.append("%s %s of %d" % ["Pages" if shown.size() > 1 else "Page", "–".join(shown),
				BinderLayout.page_count(binder.binder)])
			lines.append("%s: Close Binder" % _key(Controls.INTERACT))
			# On top: the block is anchored at the bottom, so lines that come and
			# go as you aim grow it upward and leave the binder's lines in place.
			if _aim_pocket >= 0:
				lines.insert(0, _pocket_hint(binder, _aim_pocket))
	return "\n".join(lines)


## A pocket shows its number, and the card's name once its own card is locked
## in. Until then (empty, or holding the wrong card) the card is a mystery.
func _pocket_hint(binder: Binder, pocket: int) -> String:
	var set_data := CardDatabase.get_set(binder.binder.set_code)
	var number := "%s #%s" % [set_data.code, set_data.number_text(binder.binder.first + pocket)]
	if not binder.contents.is_locked(pocket):
		return number + ": ???"
	return "%s\n%s" % [number, CardDatabase.get_card(binder.contents.card_at(pocket)).name]


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


## Adds a mouse movement to the up-close tilt, one to one with mouse look's
## sensitivity, and clamps it to `limit` radians each way. Moving the mouse
## right turns the face to the right; moving it up tips the top away.
static func inspect_tilt(tilt: Vector2, mouse_relative: Vector2, sensitivity: float, limit: float) -> Vector2:
	return Vector2(
		clampf(tilt.x + mouse_relative.y * sensitivity, -limit, limit),
		clampf(tilt.y + mouse_relative.x * sensitivity, -limit, limit))


func _set_zoomed(zoomed: bool) -> void:
	_zoomed = zoomed
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_method(_set_zoom_amount, _zoom_amount, 1.0 if zoomed else 0.0, zoom_seconds)
	if not zoomed:
		# The tilt eases out with the lowering, so the card settles flat.
		_zoom_tween.parallel().tween_property(self, "_tilt", Vector2.ZERO, zoom_seconds)


func _set_zoom_amount(amount: float) -> void:
	_zoom_amount = amount
	_pose_held_card()


## Places the held card between its low and up-close poses, with the tilt on
## top. Tilt only shows up close, so it's scaled by how far up the card is.
func _pose_held_card() -> void:
	if _gliding() and held_card_id >= 0:
		return # Still on its way to the hand.
	_held_view.position = HELD_POSITION.lerp(ZOOMED_POSITION, _zoom_amount)
	_held_view.rotation = HELD_ROTATION.lerp(ZOOMED_ROTATION, _zoom_amount) \
			+ Vector3(_tilt.x, _tilt.y, 0.0) * _zoom_amount


## Puts card `id` in the hand (-1 empties it). Given `from`, a global card
## pose, the card glides up to the hand from there.
func _hold(id: int, from = null) -> void:
	if _zoom_tween:
		_zoom_tween.kill()
	_zoomed = false
	_zoom_amount = 0.0
	_tilt = Vector2.ZERO
	held_card_id = -1
	_pose_held_card()
	held_card_id = id
	if id >= 0 and from is Transform3D:
		var held := _held_view.transform
		_glide = Glide.start(_held_view, from, func() -> Transform3D: return _camera.global_transform * held, card_glide_seconds)
	_held_view.visible = id >= 0
	if id < 0:
		held_changed.emit(null, null)
		return
	seen_cards[id] = true
	CardView.apply(_held_view.material_override, id)
	held_changed.emit(CardDatabase.get_card(id), null)
