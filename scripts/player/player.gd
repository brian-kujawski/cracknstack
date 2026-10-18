extends CharacterBody3D
## First-person controller: walk, look, crouch. What you do with your hands
## lives in Hands.
##
## Crouching shrinks the body as well as lowering the eyes, so you can get
## under the work tables. You can't stand up while something's over your head:
## you stay crouched until there's room.

@export var walk_speed := 3.5
@export var crouch_speed := 1.6
@export var mouse_sensitivity := 0.0025
@export var stand_eye_height := 1.65
@export var crouch_eye_height := 0.5
## Body (capsule) height standing and crouched. Crouched fits under a table.
@export var stand_body_height := 1.8
@export var crouch_body_height := 0.6
## How fast the camera moves between standing and crouching heights.
@export var crouch_lerp_speed := 10.0
## Crouch key: hold to crouch (default), or press to toggle. A setting in the
## M4b menu.
@export var crouch_toggle := false

@onready var _camera: Camera3D = $Camera3D
@onready var _body: CollisionShape3D = $CollisionShape3D

var _pitch := 0.0
var _crouch_toggled := false
var _crouched := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera.position.y = stand_eye_height
	# Our own copy, since crouching resizes it.
	_body.shape = _body.shape.duplicate()
	_set_body_height(stand_body_height)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -PI / 2 + 0.01, PI / 2 - 0.01)
		_camera.rotation.x = _pitch
	elif crouch_toggle and event.is_action_pressed(Controls.CROUCH):
		_crouch_toggled = not _crouch_toggled


func _physics_process(delta: float) -> void:
	var wants_crouch := _crouch_toggled if crouch_toggle else Input.is_action_pressed(Controls.CROUCH)
	set_crouched(wants_crouch)
	var target_eye := crouch_eye_height if _crouched else stand_eye_height
	_camera.position.y = lerpf(_camera.position.y, target_eye, minf(1.0, crouch_lerp_speed * delta))

	if not is_on_floor():
		velocity += get_gravity() * delta

	var input := Input.get_vector(Controls.MOVE_LEFT, Controls.MOVE_RIGHT, Controls.MOVE_FORWARD, Controls.MOVE_BACK)
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := crouch_speed if _crouched else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()


func is_crouched() -> bool:
	return _crouched


## Crouches, or stands up if there's room overhead (otherwise stays down).
func set_crouched(crouched: bool) -> void:
	if crouched == _crouched or (not crouched and not can_stand()):
		return
	_crouched = crouched
	_set_body_height(crouch_body_height if crouched else stand_body_height)


## Whether there's room above the crouched body to stand up.
func can_stand() -> bool:
	var capsule: CapsuleShape3D = _body.shape
	var room := CapsuleShape3D.new()
	# The space a standing body adds on top of a crouched one, a hair narrower
	# and clear of the floor so only what's overhead counts.
	room.radius = capsule.radius - 0.01
	room.height = maxf(stand_body_height - crouch_body_height, room.radius * 2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = room
	query.transform = Transform3D(Basis(), global_position + Vector3.UP * (crouch_body_height + room.height / 2))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _set_body_height(height: float) -> void:
	var capsule: CapsuleShape3D = _body.shape
	capsule.height = height
	_body.position.y = height / 2
