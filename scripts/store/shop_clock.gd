class_name ShopClock
extends StaticBody3D
## The longcase (grandfather) clock at the shelf end of the left-hand wall,
## in the tables' dark wood with brass fittings. Its hands show the shop's
## time of day (DayCycle), and behind the glass door in its trunk the
## pendulum swings from a pivot up in the hood, behind the dial.
##
## The pendulum keeps pace with the day: at the default day length it beats
## once a second like a real one, a shorter day swings it faster, a longer
## one slower, and with the clock stopped (Day length: Stopped) it hangs
## still where it was.
##
## Its origin is on the floor, centred under it, its back against the wall,
## and its face looks along local +Z. It's furniture: solid, and not a
## surface to put things down on.

const WIDTH := 0.5
const DEPTH := 0.32
const HEIGHT := 2.05
## The trunk's door: its glass, bottom and top.
const GLASS := Vector2(0.3, 1.2)
## The trunk's height range, between the plinth and the hood.
const TRUNK := Vector2(0.1625, 1.305)
const DIAL_HEIGHT := 1.6
const DIAL_RADIUS := 0.16
## The pendulum's pivot, behind the dial, and the bob's centre below it.
const PIVOT_HEIGHT := 1.55
const ROD_LENGTH := 1.05
const BOB_RADIUS := 0.075
## Half the swing, either side of hanging straight.
const SWING := deg_to_rad(4.5)
## Seconds for one swing there and back at the default day length.
const PERIOD := 2.0

## The clock it shows; null leaves the hands where they are.
var day: DayCycle
## Where the pendulum is in its swing, 0..TAU.
var phase := 0.0

var _pendulum: Node3D
var _hour_hand: Node3D
var _minute_hand: Node3D


## How fast the pendulum swings, as a share of a real one's: 1 at the default
## day length, more for a shorter day, 0 with the clock stopped.
static func pace(day_seconds: float) -> float:
	if day_seconds <= 0.0:
		return 0.0
	return Settings.DAY_LENGTHS[Settings.DEFAULTS["day_length"]] / day_seconds


## Builds the meshes and the solid body. Call once before adding to the tree.
func build(wood: Material, brass: Material) -> void:
	add_to_group(ReadingCorner.FURNITURE)
	var dark := ReadingCorner.tinted(wood as StandardMaterial3D, 0.7)
	var front := DEPTH / 2
	# Plinth, trunk with its waist mouldings, hood and crown.
	_part(Vector3(WIDTH, 0.14, DEPTH), Vector3(0, 0.07, 0), wood)
	_part(Vector3(WIDTH + 0.02, 0.025, DEPTH + 0.02), Vector3(0, 0.15, 0), wood)
	_part(Vector3(WIDTH, 0.03, DEPTH), Vector3(0, 1.32, 0), wood)
	_part(Vector3(0.46, 0.6, DEPTH - 0.02), Vector3(0, 1.63, -0.01), wood)
	_part(Vector3(WIDTH + 0.04, 0.04, DEPTH + 0.03), Vector3(0, 1.95, 0), wood)
	_part(Vector3(WIDTH - 0.04, 0.06, DEPTH - 0.04), Vector3(0, 2.0, -0.01), dark)
	# The trunk is a hollow case, 40 cm across and 26 deep: sides, a dark
	# back, and a door with a frame round the glass.
	var trunk_h := TRUNK.y - TRUNK.x
	var trunk_mid := (TRUNK.x + TRUNK.y) / 2
	for side in [-1, 1]:
		_part(Vector3(0.03, trunk_h, 0.26), Vector3(side * 0.185, trunk_mid, -0.03), wood)
	_part(Vector3(0.34, trunk_h, 0.01), Vector3(0, trunk_mid, -0.155), dark)
	var door_z := 0.1
	var glass_w := 0.26
	var glass_h := GLASS.y - GLASS.x
	var glass_mid := (GLASS.x + GLASS.y) / 2
	for side in [-1, 1]:
		_part(Vector3(0.07, trunk_h, 0.02), Vector3(side * (glass_w / 2 + 0.035), trunk_mid, door_z), wood)
	_part(Vector3(glass_w, GLASS.x - TRUNK.x, 0.02), Vector3(0, (TRUNK.x + GLASS.x) / 2, door_z), wood)
	_part(Vector3(glass_w, TRUNK.y - GLASS.y, 0.02), Vector3(0, (GLASS.y + TRUNK.y) / 2, door_z), wood)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.9, 0.95, 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	_part(Vector3(glass_w, glass_h, 0.004), Vector3(0, glass_mid, door_z), glass)
	# The two driving weights hanging either side, still.
	for side in [-1, 1]:
		var weight := _cylinder(0.03, 0.2, Vector3(side * 0.09, 0.88, -0.07), brass)
		weight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_part(Vector3(0.004, 0.4, 0.004), Vector3(side * 0.09, 1.18, -0.07), brass)
	# Dial: a brass bezel round a cream face, hour marks, two hands.
	var dial_z := front - 0.01
	var bezel := _cylinder(DIAL_RADIUS + 0.015, 0.012, Vector3(0, DIAL_HEIGHT, dial_z), brass)
	bezel.rotation.x = PI / 2
	var face_material := StandardMaterial3D.new()
	face_material.albedo_color = Color(0.94, 0.91, 0.82)
	face_material.roughness = 0.6
	var face := _cylinder(DIAL_RADIUS, 0.014, Vector3(0, DIAL_HEIGHT, dial_z + 0.001), face_material)
	face.rotation.x = PI / 2
	var ink := ReadingCorner.tinted(face_material, 0.12)
	for hour in 12:
		var angle := hour * TAU / 12
		var mark := _part(Vector3(0.008, 0.028 if hour % 3 == 0 else 0.016, 0.003),
			Vector3(sin(angle), cos(angle), 0) * (DIAL_RADIUS - 0.022) + Vector3(0, DIAL_HEIGHT, dial_z + 0.009), ink)
		mark.rotation.z = -angle
	_hour_hand = _hand(0.1, 0.012, dial_z + 0.011, ink)
	_minute_hand = _hand(0.14, 0.007, dial_z + 0.013, ink)
	var boss := _cylinder(0.012, 0.006, Vector3(0, DIAL_HEIGHT, dial_z + 0.015), brass)
	boss.rotation.x = PI / 2
	# Pendulum: a thin rod from the pivot, a brass bob on the end.
	_pendulum = Node3D.new()
	_pendulum.name = "Pendulum"
	_pendulum.position = Vector3(0, PIVOT_HEIGHT, -0.03)
	add_child(_pendulum)
	var rod := _add(_pendulum, _box(Vector3(0.008, ROD_LENGTH, 0.004)), dark)
	rod.position.y = -ROD_LENGTH / 2
	var bob := _add(_pendulum, _disc(BOB_RADIUS, 0.018), brass)
	bob.position.y = -ROD_LENGTH
	bob.rotation.x = PI / 2
	for mesh in _pendulum.get_children():
		(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, HEIGHT, DEPTH)
	shape.shape = box
	shape.position.y = HEIGHT / 2
	add_child(shape)


func _process(delta: float) -> void:
	if day == null:
		return
	phase = fposmod(phase + delta * TAU / PERIOD * pace(Settings.day_seconds()), TAU)
	show_time(day.hour)


## Turns the hands to `hour` (0..24) and the pendulum to where `phase` has it.
func show_time(hour: float) -> void:
	_hour_hand.rotation.z = -fposmod(hour, 12.0) / 12.0 * TAU
	_minute_hand.rotation.z = -fposmod(hour, 1.0) * TAU
	_pendulum.rotation.z = SWING * sin(phase)


## A hand pointing at twelve, turning about the dial's centre.
func _hand(length: float, width: float, z: float, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0, DIAL_HEIGHT, z)
	add_child(pivot)
	var hand := _add(pivot, _box(Vector3(width, length, 0.002)), material)
	hand.position.y = length / 2 - 0.015
	return pivot


func _part(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var part := _add(self, _box(size), material)
	part.position = at
	return part


func _cylinder(radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var part := _add(self, _disc(radius, height), material)
	part.position = at
	return part


static func _add(parent: Node3D, mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _disc(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh
