class_name PilePicker
extends Node
## The player's hands. Aim at the floor to highlight the top card under the
## crosshair. Left-click is context sensitive: with empty hands it picks the
## card up; holding a card, it files the card into the binder pocket you're
## looking at (M3), or anywhere else brings the card up close to your face
## (click again to lower it). Right-click tosses the card back onto the pile.

signal held_card_changed(card: CardData)

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

var pile: PileWorld
var held_card_id := -1

@onready var _camera: Camera3D = get_parent().get_node("Camera3D")
var _held_view: MeshInstance3D
var _aim_point := Vector3.ZERO
var _aim_valid := false
var _zoomed := false
var _zoom_tween: Tween


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
	var target := pile.top_card_at(_aim_point) if _aim_valid and held_card_id < 0 else -1
	pile.set_highlight(target)


func _unhandled_input(event: InputEvent) -> void:
	if pile == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("use_hand"):
		if held_card_id < 0:
			if _aim_valid:
				var id := pile.top_card_at(_aim_point)
				if id >= 0:
					pile.pick_up(id)
					_hold(id)
		elif not _try_file_held_card():
			_set_zoomed(not _zoomed)
	elif event.is_action_pressed("toss") and held_card_id >= 0:
		_toss()
		_hold(-1)


func _update_aim() -> void:
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * reach
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [(get_parent() as CollisionObject3D).get_rid()]
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	# Only the floor counts: aiming at a shelf or table top reaches nothing.
	_aim_valid = not hit.is_empty() and hit.normal.y > 0.9 and hit.position.y < 0.05
	if _aim_valid:
		_aim_point = hit.position


func _toss() -> void:
	var forward := -_camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var card := TossedCard.new()
	# The tossed card gets its own material so the next pick-up can change
	# the hand without changing the card in flight.
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/held_card.gdshader")
	_apply_card(material, held_card_id)
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


## Files the held card into the binder pocket under the crosshair. Binders
## become interactive in M3; until then there's never a pocket to aim at.
func _try_file_held_card() -> bool:
	return false


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
		held_card_changed.emit(null)
		return
	_apply_card(_held_view.material_override, id)
	held_card_changed.emit(CardDatabase.get_card(id))


static func _apply_card(material: ShaderMaterial, id: int) -> void:
	var card := CardDatabase.get_card(id)
	var set_data := CardDatabase.get_set(card.set_code)
	var accent := set_data.accent_color
	material.set_shader_parameter("accent", Vector3(accent.r, accent.g, accent.b))
	material.set_shader_parameter("set_number", CardDatabase.sets_in_shelf_order().find(set_data) + 1)
	material.set_shader_parameter("collector_number", card.collector_number)
	material.set_shader_parameter("rarity", card.rarity)
