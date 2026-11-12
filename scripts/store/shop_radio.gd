class_name ShopRadio
extends StaticBody3D
## The shop's radio: a boombox on the reading corner's side table. Click it
## to open the Radio menu (the Q key opens the same menu). Two speakers, an
## AM/FM tuning window whose backlight is on while a song plays and whose
## needle moves along to each song, a tape deck, a carry handle and a
## telescopic antenna.
##
## Its origin is on the table top, centred under the body, and its front
## (speakers, tuning window) faces local +Z. Local +X runs left to right as
## you face it.

## The body; the handle and antenna stand above it.
const SIZE := Vector3(0.5, 0.26, 0.13)
const CORNER := 0.025
const SPEAKER_RADIUS := 0.075
const SPEAKER_X := 0.155
## The tuning window across the middle, and the frequencies marked on it.
const TAPE_SIZE := Vector2(0.13, 0.05)
const FM_MARKS := ["88", "92", "96", "100", "104", "108"]
const AM_MARKS := ["53", "60", "80", "100", "130", "160"]
const TAPE_GLOW := 1.2
const TAPE_LIGHT := Color(1.0, 0.75, 0.42)
const ANTENNA_LENGTH := 0.42

var _tape: StandardMaterial3D
var _needle: MeshInstance3D
var _tape_center: Vector3


## Builds the meshes and collision. Call once before adding to the tree.
func build() -> void:
	var plastic := _material(Color(0.07, 0.07, 0.075), 0.45)
	var panel := _material(Color(0.16, 0.16, 0.17), 0.5)
	var chrome := _material(Color(0.75, 0.76, 0.78), 0.25)
	chrome.metallic = 0.9
	var cone := _material(Color(0.03, 0.03, 0.03), 0.8)
	var front := SIZE.z / 2

	_add(ReadingCorner.rounded_box(SIZE, CORNER), plastic, Vector3(0, SIZE.y / 2, 0))
	_add(_box(Vector3(SIZE.x - 0.03, SIZE.y - 0.04, 0.004)), panel, Vector3(0, SIZE.y / 2, front + 0.001))

	# The speakers: a chrome rim round a dark cone with a dust cap.
	var speaker_y := SIZE.y * 0.47
	for side in [-1, 1]:
		var at := Vector3(side * SPEAKER_X, speaker_y, front)
		_add(_disc(SPEAKER_RADIUS + 0.008, SPEAKER_RADIUS + 0.008, 0.01), chrome, at + Vector3(0, 0, 0.004)).rotation.x = PI / 2
		_add(_disc(SPEAKER_RADIUS, SPEAKER_RADIUS * 0.3, 0.012), cone, at + Vector3(0, 0, 0.004)).rotation.x = PI / 2
		_add(_disc(0.018, 0.02, 0.012), panel, at + Vector3(0, 0, 0.008)).rotation.x = PI / 2

	# The tuning window: a backlit tape marked FM over AM, with a red needle.
	_tape_center = Vector3(0, SIZE.y * 0.7, front + 0.004)
	_tape = _material(Color(0.82, 0.78, 0.66), 0.4)
	_tape.emission_enabled = true
	_tape.emission = TAPE_LIGHT
	_add(_box(Vector3(TAPE_SIZE.x + 0.01, TAPE_SIZE.y + 0.01, 0.004)), chrome, _tape_center - Vector3(0, 0, 0.001))
	_add(_box(Vector3(TAPE_SIZE.x, TAPE_SIZE.y, 0.004)), _tape, _tape_center)
	_mark_row("FM", FM_MARKS, 0.011, panel)
	_mark_row("AM", AM_MARKS, -0.013, panel)
	var red := _material(Color(0.85, 0.08, 0.05), 0.4)
	red.emission_enabled = true
	red.emission = Color(0.6, 0.05, 0.02)
	_needle = _add(_box(Vector3(0.0015, TAPE_SIZE.y - 0.006, 0.002)), red, _tape_center + Vector3(0, 0, 0.003))

	# A tape deck under the window, and a knob under that.
	var deck := Vector3(0, SIZE.y * 0.33, front + 0.004)
	_add(_box(Vector3(0.12, 0.075, 0.004)), plastic, deck)
	_add(_box(Vector3(0.07, 0.022, 0.002)), cone, deck + Vector3(0, 0.008, 0.003))
	_add(_disc(0.014, 0.016, 0.014), chrome, Vector3(0.0, SIZE.y * 0.12, front + 0.008)).rotation.x = PI / 2

	# On top: a row of tape keys, the carry handle, and the antenna.
	for i in 5:
		_add(_box(Vector3(0.018, 0.01, 0.03)), chrome if i == 0 else panel,
			Vector3(-0.13 + i * 0.022, SIZE.y + 0.004, 0.015))
	const HANDLE_RISE := 0.055
	const HANDLE_HALF := 0.16
	for side in [-1, 1]:
		_add(_box(Vector3(0.018, HANDLE_RISE, 0.03)), plastic, Vector3(side * HANDLE_HALF, SIZE.y + HANDLE_RISE / 2, -0.02))
	var grip := _add(_disc(0.011, 0.011, 2 * HANDLE_HALF + 0.018), chrome, Vector3(0, SIZE.y + HANDLE_RISE, -0.02))
	grip.rotation = Vector3(0, 0, PI / 2)
	_build_antenna(chrome)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	shape.position.y = SIZE.y / 2
	add_child(shape)


func _ready() -> void:
	Radio.changed.connect(_follow_radio)
	_follow_radio()


## The tape's backlight is on while a song plays, and the needle sits at the
## song's place along the dial.
func _follow_radio() -> void:
	if _tape == null:
		return
	_tape.emission_energy_multiplier = TAPE_GLOW if Radio.playing else 0.0
	var share := 0.5
	if Radio.current >= 0 and Radio.songs.size() > 0:
		share = (Radio.current + 0.5) / Radio.songs.size()
	_needle.position.x = _tape_center.x + (share - 0.5) * (TAPE_SIZE.x - 0.01)


## One row of the dial: its band's name at the left, and ticks with
## frequencies spread along it.
func _mark_row(band: String, marks: Array, y: float, ink: Material) -> void:
	var left := _tape_center.x - TAPE_SIZE.x / 2
	var span := TAPE_SIZE.x - 0.024
	add_child(_label(band, Vector3(left + 0.008, _tape_center.y + y, _tape_center.z + 0.0025), true))
	for i in marks.size():
		var x := left + 0.02 + span * i / (marks.size() - 1)
		var tick_y := _tape_center.y + y + (0.0055 if y > 0 else -0.0055)
		_add(_box(Vector3(0.0008, 0.004, 0.001)), ink, Vector3(x, tick_y, _tape_center.z + 0.0025))
		add_child(_label(marks[i], Vector3(x, _tape_center.y + y, _tape_center.z + 0.0025), false))


func _label(text: String, at: Vector3, bold: bool) -> Label3D:
	var label := Label3D.new()
	label.text = text
	# Silk-screened on the casing: the machine voice (style bible §5.3).
	label.font = UiStyle.machine_font(700 if bold else 500)
	label.font_size = 28 if bold else 22
	label.outline_size = 0
	label.pixel_size = 0.00018
	label.modulate = Color(0.12, 0.1, 0.08)
	label.position = at
	return label


## Three chrome sections, each thinner than the last, tipped with a ball,
## swung up from the back right corner and leaning over the top.
func _build_antenna(chrome: Material) -> void:
	var antenna := Node3D.new()
	antenna.position = Vector3(SIZE.x / 2 - 0.03, SIZE.y - 0.005, -SIZE.z / 2 + 0.02)
	antenna.rotation = Vector3(-0.2, 0, 0.55)
	add_child(antenna)
	_add(_disc(0.008, 0.008, 0.02), chrome, Vector3(0, 0.005, 0), antenna)
	var section := ANTENNA_LENGTH / 3
	for i in 3:
		var radius := 0.0035 - i * 0.0009
		_add(_disc(radius, radius, section + 0.01), chrome, Vector3(0, section * (i + 0.5), 0), antenna)
	var tip := SphereMesh.new()
	tip.radius = 0.004
	tip.height = 0.008
	_add(tip, chrome, Vector3(0, ANTENNA_LENGTH, 0), antenna)


func _add(mesh: Mesh, material: Material, at: Vector3, parent: Node = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


## A round part along local Y, `front` its top radius; turned a quarter about
## X, it faces out of the front (+Z).
static func _disc(front: float, back: float, depth: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = front
	mesh.bottom_radius = back
	mesh.height = depth
	mesh.radial_segments = 32
	return mesh


static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
