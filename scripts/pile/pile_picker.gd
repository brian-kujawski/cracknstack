class_name PilePicker
extends Node
## The player's hands: aim at the floor to highlight the top card under the
## crosshair, left-click to pick it up, right-click to put it back down where
## you're aiming. Filing into binders comes in M3.

signal held_card_changed(card: CardData)

## How far from the eye the player can reach.
@export var reach := 2.6

var pile: PileWorld
var held_card_id := -1

@onready var _camera: Camera3D = get_parent().get_node("Camera3D")
var _held_view: MeshInstance3D
var _aim_point := Vector3.ZERO
var _aim_valid := false


func _ready() -> void:
	_held_view = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = PileWorld.CARD_SIZE
	_held_view.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/held_card.gdshader")
	_held_view.material_override = material
	_held_view.position = Vector3(0.075, -0.05, -0.2)
	_held_view.rotation = Vector3(0.12, -0.25, 0.04)
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
	if event.is_action_pressed("pick_up") and held_card_id < 0 and _aim_valid:
		var id := pile.top_card_at(_aim_point)
		if id >= 0:
			pile.pick_up(id)
			_hold(id)
	elif event.is_action_pressed("put_down") and held_card_id >= 0 and _aim_valid:
		pile.drop(held_card_id, _aim_point, randf() * TAU)
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


func _hold(id: int) -> void:
	held_card_id = id
	_held_view.visible = id >= 0
	if id < 0:
		held_card_changed.emit(null)
		return
	var card := CardDatabase.get_card(id)
	var material: ShaderMaterial = _held_view.material_override
	material.set_shader_parameter("accent", CardDatabase.get_set(card.set_code).accent_color)
	material.set_shader_parameter("set_number", CardDatabase.sets_in_shelf_order().find(CardDatabase.get_set(card.set_code)) + 1)
	material.set_shader_parameter("collector_number", card.collector_number)
	material.set_shader_parameter("rarity", card.rarity)
	held_card_changed.emit(card)
