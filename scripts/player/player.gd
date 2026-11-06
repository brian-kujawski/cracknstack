extends CharacterBody3D
## First-person controller: walk, look, crouch. What you do with your hands
## lives in Hands.
##
## Crouching shrinks the body as well as lowering the eyes, so you can get
## under the work tables. You can't stand up while something's over your head:
## you stay crouched until there's room.
##
## Standing, you can step a little way into a work table (StoreBuilder's
## TABLE_LEAN): with no body drawn, that reads as leaning over it, and the
## eyes dip a touch the further in you lean.
##
## Binders don't collide with you, so you wade through them on the floor.

const Store := preload("res://scripts/store/store_builder.gd")

@export var walk_speed := 3.5
@export var crouch_speed := 1.6
@export var stand_eye_height := 1.65
@export var crouch_eye_height := 0.5
## Body (capsule) height standing and crouched. Crouched fits under a table.
@export var stand_body_height := 1.8
@export var crouch_body_height := 0.6
## How far the eyes drop leaning all the way over a table.
@export var lean_eye_dip := 0.12
## How fast the camera moves between standing and crouching heights.
@export var crouch_lerp_speed := 10.0
## Crouch key: hold to crouch (default), or press to toggle. Follows the
## Crouch setting.
var crouch_toggle := false

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
	collision_mask |= Store.LEAN_STOP_LAYER
	# Nothing collides with you: you walk through binders rather than kick
	# them about, or push one off a table you lean over.
	collision_layer = 0
	# Once the store has built its tables.
	_lean_over_tables.call_deferred()
	Settings.changed.connect(_apply_settings.unbind(1))
	_apply_settings()


## Mouse look, crouch mode and field of view, from Settings.
func _apply_settings() -> void:
	if crouch_toggle and not Settings.value("crouch_toggle"):
		_crouch_toggled = false
	crouch_toggle = Settings.value("crouch_toggle")
	_camera.fov = Settings.value("field_of_view")


## Mouse look in radians per pixel; inspect tilt uses it too.
func mouse_sensitivity() -> float:
	return Settings.look_sensitivity()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	elif crouch_toggle and event.is_action_pressed(Controls.CROUCH):
		_crouch_toggled = not _crouch_toggled


## Turns the view by a mouse movement: raw and 1:1, never smoothed.
func look(relative: Vector2) -> void:
	var sensitivity := mouse_sensitivity()
	var vertical := -1.0 if Settings.value("invert_y") else 1.0
	rotate_y(-relative.x * sensitivity)
	_pitch = clampf(_pitch - relative.y * sensitivity * vertical, -PI / 2 + 0.01, PI / 2 - 0.01)
	_camera.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	var wants_crouch := _crouch_toggled if crouch_toggle else Input.is_action_pressed(Controls.CROUCH)
	set_crouched(wants_crouch)
	var target_eye := crouch_eye_height if _crouched else stand_eye_height - lean_eye_dip * lean()
	_camera.position.y = lerpf(_camera.position.y, target_eye, minf(1.0, crouch_lerp_speed * delta))

	if not is_on_floor():
		velocity += get_gravity() * delta

	var input := Input.get_vector(Controls.MOVE_LEFT, Controls.MOVE_RIGHT, Controls.MOVE_FORWARD, Controls.MOVE_BACK)
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := move_speed()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()


## Where you stand and look, for a save (ShopSave).
func save_state() -> Dictionary:
	return {"position": global_position, "yaw": rotation.y, "pitch": _pitch, "crouched": _crouched}


## Stands (or crouches) where a save left you, looking the same way. In
## Hold mode you stand back up once there's room, unless Crouch is held.
func restore_state(saved: Dictionary) -> void:
	global_position = saved.get("position", global_position)
	rotation.y = saved.get("yaw", rotation.y)
	_pitch = saved.get("pitch", 0.0)
	_camera.rotation.x = _pitch
	if saved.get("crouched", false):
		_crouch_toggled = crouch_toggle
		set_crouched(true)
		_camera.position.y = crouch_eye_height


## Walking or crouch-walking speed.
func move_speed() -> float:
	return crouch_speed if _crouched else walk_speed


func is_crouched() -> bool:
	return _crouched


## How far over a table you're leaning: 0 where its edge used to stop the
## body, 1 all the way in.
func lean() -> float:
	var radius: float = (_body.shape as CapsuleShape3D).radius
	var half := Vector2(Store.TABLE_SIZE.x, Store.TABLE_SIZE.z) / 2
	var amount := 0.0
	for top: Node3D in get_tree().get_nodes_in_group(Store.TABLE_TOPS):
		var offset := (global_position - top.global_position).abs()
		var outside := maxf(offset.x - half.x, offset.z - half.y)
		amount = maxf(amount, clampf((radius - outside) / Store.TABLE_LEAN, 0.0, 1.0))
	return amount


## Table tops don't stop you; the smaller block under each one does.
func _lean_over_tables() -> void:
	for top in get_tree().get_nodes_in_group(Store.TABLE_TOPS):
		add_collision_exception_with(top)


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
	# Nor the table tops you can lean over.
	var exclude: Array[RID] = [get_rid()]
	for body in get_collision_exceptions():
		exclude.append(body.get_rid())
	query.exclude = exclude
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _set_body_height(height: float) -> void:
	var capsule: CapsuleShape3D = _body.shape
	capsule.height = height
	_body.position.y = height / 2
