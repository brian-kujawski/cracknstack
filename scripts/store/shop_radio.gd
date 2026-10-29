class_name ShopRadio
extends StaticBody3D
## The shop's radio: an old wooden tabletop set on the reading corner's side
## table. Click it to open the Radio menu (the Q key opens the same menu).
## Its dial lights up while a song is playing.
##
## Its origin is on the table top, centred under the set, and its front (the
## speaker cloth, the dial and the knobs) faces local +Z. Local +X runs left
## to right as you face it.

const SIZE := Vector3(0.36, 0.24, 0.2)
## How round the cabinet's edges are.
const CORNER := 0.03
## The dial's glow while playing, and its colour.
const DIAL_GLOW := 1.4
const DIAL_LIGHT := Color(1.0, 0.72, 0.4)

var _dial: StandardMaterial3D


## Builds the meshes and collision. `wood` is the store's furniture wood,
## `cloth` the speaker cloth, `brass` the dial's bezel. Call once before
## adding to the tree.
func build(wood: StandardMaterial3D, cloth: Material, brass: Material) -> void:
	var front := SIZE.z / 2
	var case := MeshInstance3D.new()
	case.mesh = ReadingCorner.rounded_box(SIZE, CORNER)
	case.material_override = wood
	case.position.y = SIZE.y / 2
	add_child(case)

	# The speaker on the left: cloth behind three wooden bars.
	var speaker := Vector2(0.17, 0.15)
	var speaker_x := -SIZE.x / 2 + 0.04 + speaker.x / 2
	_box(Vector3(speaker.x, speaker.y, 0.004), Vector3(speaker_x, SIZE.y / 2, front + 0.001), cloth)
	for i in 3:
		var x := speaker_x + (i - 1) * speaker.x / 3
		_box(Vector3(0.012, speaker.y, 0.01), Vector3(x, SIZE.y / 2, front + 0.004), wood)

	# The dial on the right: a lit round face in a brass bezel, and two knobs under it.
	var dial_x := SIZE.x / 2 - 0.085
	var bezel := _cylinder(0.045, 0.008, brass)
	bezel.position = Vector3(dial_x, SIZE.y * 0.62, front + 0.002)
	_dial = StandardMaterial3D.new()
	_dial.albedo_color = Color(0.9, 0.84, 0.68)
	_dial.roughness = 0.4
	_dial.emission_enabled = true
	_dial.emission = DIAL_LIGHT
	var face := _cylinder(0.036, 0.004, _dial)
	face.position = bezel.position + Vector3(0, 0, 0.004)
	var needle := _box(Vector3(0.002, 0.03, 0.002), face.position + Vector3(0.008, 0.008, 0.003), brass)
	needle.rotation.z = -0.4
	var knob_material := ReadingCorner.tinted(wood, 0.45)
	for side in [-1, 1]:
		var knob := _cylinder(0.016, 0.018, knob_material)
		knob.position = Vector3(dial_x + side * 0.03, SIZE.y * 0.24, front + 0.009)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	shape.position.y = SIZE.y / 2
	add_child(shape)


func _ready() -> void:
	Radio.changed.connect(_light_dial)
	_light_dial()


## The dial glows while a song is playing.
func _light_dial() -> void:
	if _dial != null:
		_dial.emission_energy_multiplier = DIAL_GLOW if Radio.playing else 0.0


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	return instance


## A short cylinder facing out of the front (+Z).
func _cylinder(radius: float, depth: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = depth
	mesh.radial_segments = 24
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.rotation.x = PI / 2
	add_child(instance)
	return instance
