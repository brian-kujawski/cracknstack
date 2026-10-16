extends CharacterBody3D
## First-person controller: walk, look, crouch. Hands live in PilePicker.

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
	_ensure_input_actions()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera.position.y = stand_eye_height


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -PI / 2 + 0.01, PI / 2 - 0.01)
		_camera.rotation.x = _pitch
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var crouching := Input.is_action_pressed("crouch")
	var target_eye := crouch_eye_height if crouching else stand_eye_height
	_camera.position.y = lerpf(_camera.position.y, target_eye, minf(1.0, crouch_lerp_speed * delta))

	if not is_on_floor():
		velocity += get_gravity() * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := crouch_speed if crouching else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()


## Registers WASD, crouch and the mouse buttons in code so the project file stays readable. Rebinding
## in Project Settings still works: existing actions are left alone.
static func _ensure_input_actions() -> void:
	var bindings := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"crouch": [KEY_CTRL, KEY_C],
	}
	var mouse_bindings := {
		"use_hand": MOUSE_BUTTON_LEFT,
		"toss": MOUSE_BUTTON_RIGHT,
	}
	for action in mouse_bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var button := InputEventMouseButton.new()
		button.button_index = mouse_bindings[action]
		InputMap.action_add_event(action, button)
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode in bindings[action]:
			var key := InputEventKey.new()
			key.physical_keycode = keycode
			InputMap.action_add_event(action, key)
