class_name PackEffects
extends Node
## The show around ripping a pack open (Hands does the ripping):
## - the veil: the room behind what's in your hand dims, a dark shell a
##   little way in front of the camera, past the pack and the cards up
##   close, darker toward the edges of the view;
## - the flash: the whole screen goes white for an instant as the pack
##   tears open;
## - the glow: a soft burst of colour behind the card up close when a rare
##   (gold) or a mythic (orange-red) is revealed.

## How far in front of the camera the veil hangs: behind anything held up
## close, in front of the room.
const VEIL_DISTANCE := 0.3
## How dark the veil gets at its darkest.
const VEIL_MAX := 0.72
## How fast the veil follows where it's headed (share per second).
const VEIL_RATE := 4.0
const FLASH_PEAK := 0.9
const FLASH_IN := 0.05
const FLASH_OUT := 0.45
const RARE_GLOW := Color(1.0, 0.78, 0.3)
const MYTHIC_GLOW := Color(1.0, 0.42, 0.12)
const GLOW_SECONDS := 1.6

var veil := 0.0
var _veil_target := 0.0
var _veil_mesh: MeshInstance3D
var _veil_material: ShaderMaterial
var _flash: ColorRect
var _glow_mesh: MeshInstance3D
var _glow_material: ShaderMaterial
var _glow_tween: Tween


## Hangs the veil and the glow off `camera` and the flash over the screen.
func setup(camera: Camera3D) -> void:
	_veil_material = ShaderMaterial.new()
	_veil_material.shader = preload("res://shaders/pack_veil.gdshader")
	_veil_mesh = MeshInstance3D.new()
	_veil_mesh.name = "PackVeil"
	var quad := QuadMesh.new()
	# Wide and tall enough to fill any view at this distance.
	quad.size = Vector2(4.0, 2.0)
	_veil_mesh.mesh = quad
	_veil_mesh.material_override = _veil_material
	_veil_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_veil_mesh.position = Vector3(0, 0, -VEIL_DISTANCE)
	_veil_mesh.visible = false
	camera.add_child(_veil_mesh)

	_glow_material = ShaderMaterial.new()
	_glow_material.shader = preload("res://shaders/pack_glow.gdshader")
	_glow_mesh = MeshInstance3D.new()
	_glow_mesh.name = "RevealGlow"
	var glow_quad := QuadMesh.new()
	glow_quad.size = Vector2(0.17, 0.17)
	_glow_mesh.mesh = glow_quad
	_glow_mesh.material_override = _glow_material
	_glow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow_mesh.visible = false
	camera.add_child(_glow_mesh)

	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_flash)


## Where the veil is headed, 0 (gone) to 1 (VEIL_MAX); `instant` puts it there.
func set_veil(amount: float, instant := false) -> void:
	_veil_target = clampf(amount, 0.0, 1.0)
	if instant:
		veil = _veil_target
		_apply_veil()


func _process(delta: float) -> void:
	if _veil_mesh == null or is_equal_approx(veil, _veil_target):
		return
	veil = move_toward(veil, _veil_target, maxf(VEIL_RATE * delta * absf(_veil_target - veil), delta * 0.2))
	_apply_veil()


func _apply_veil() -> void:
	_veil_material.set_shader_parameter("amount", veil * VEIL_MAX)
	_veil_mesh.visible = veil > 0.001


## A white flash over everything, peaking at once and fading.
func flash() -> void:
	var tween := _flash.create_tween()
	tween.tween_property(_flash, "color:a", FLASH_PEAK, FLASH_IN)
	tween.tween_property(_flash, "color:a", 0.0, FLASH_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## A burst of colour behind the card up close, at `at` in the camera's space
## (the glow sits just behind it).
func glow(colour: Color, at: Vector3) -> void:
	if _glow_tween:
		_glow_tween.kill()
	_glow_mesh.position = at + Vector3(0, 0, -0.01)
	_glow_material.set_shader_parameter("colour", Vector3(colour.r, colour.g, colour.b))
	_glow_mesh.visible = true
	_glow_tween = _glow_mesh.create_tween()
	_glow_tween.tween_method(_set_glow, 0.0, 1.0, 0.15).set_ease(Tween.EASE_OUT)
	_glow_tween.tween_method(_set_glow, 1.0, 0.35, GLOW_SECONDS * 0.4)
	_glow_tween.tween_method(_set_glow, 0.35, 0.0, GLOW_SECONDS * 0.6)
	_glow_tween.tween_callback(_glow_mesh.hide)


## Stops the glow at once (the card it was behind has gone).
func end_glow() -> void:
	if _glow_tween:
		_glow_tween.kill()
	_glow_mesh.visible = false


func _set_glow(amount: float) -> void:
	_glow_material.set_shader_parameter("amount", amount)
	_glow_mesh.scale = Vector3.ONE * (0.85 + 0.25 * amount)
