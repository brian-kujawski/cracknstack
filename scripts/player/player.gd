extends CharacterBody3D
## First-person controller: walk, look, crouch. What you do with your hands
## lives in Hands.

@export var walk_speed := 3.5
@export var crouch_speed := 1.6
@export var mouse_sensitivity := 0.0025
@export var stand_eye_height := 1.65
@export var crouch_eye_height := 0.9
## How fast the camera moves between standing and crouching heights.
@export var crouch_lerp_speed := 10.0

@onready var _camera: Camera3D = $Camera3D

var _pitch := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera.position.y = stand_eye_height


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -PI / 2 + 0.01, PI / 2 - 0.01)
		_camera.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	var crouching := Input.is_action_pressed(Controls.CROUCH)
	var target_eye := crouch_eye_height if crouching else stand_eye_height
	_camera.position.y = lerpf(_camera.position.y, target_eye, minf(1.0, crouch_lerp_speed * delta))

	if not is_on_floor():
		velocity += get_gravity() * delta

	var input := Input.get_vector(Controls.MOVE_LEFT, Controls.MOVE_RIGHT, Controls.MOVE_FORWARD, Controls.MOVE_BACK)
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := crouch_speed if crouching else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

