class_name ShippingStation
extends StaticBody3D
## The shipping corner by the door, a placeholder until it's designed
## properly: a taped-off OUTGOING mat on the floor, and beside it a wooden
## crate of flat-packed shipping boxes. Click the crate with empty hands to
## take a new, empty ShippingBox; there are always more. At the end of the
## day (Main.end_day), every sealed box standing on the mat is collected.
##
## Its origin is on the floor at the middle of the mat, facing local +Z
## (into the room). The crate stands at the mat's end (CRATE_AT), and is
## the only part that collides (the mat is flat on the floor).

## The mat: x wide, z deep (metres).
const MAT := Vector2(1.0, 0.7)
const TAPE_WIDTH := 0.05
## The crate of flat-packed boxes: its outside size, and where its centre
## sits from the mat's centre (x, z on the floor).
const CRATE := Vector3(0.5, 0.42, 0.28)
const CRATE_AT := Vector2(-0.86, -0.12)
const FLAT_BOXES := 9
const TAPE := Color(0.95, 0.75, 0.1)


## Builds the mat and the crate, in `wood` (the furniture's).
func build(wood: Material) -> void:
	name = "ShippingStation"
	collision_layer = 1
	collision_mask = 0
	var mat := _material(Color(0.22, 0.22, 0.24), 0.95)
	_add(Vector3(MAT.x, 0.004, MAT.y), Vector3(0, 0.002, 0), mat)
	var tape := _material(TAPE, 0.6)
	for side in [-1, 1]:
		_add(Vector3(MAT.x, 0.0045, TAPE_WIDTH), Vector3(0, 0.00225, side * (MAT.y - TAPE_WIDTH) / 2), tape)
		_add(Vector3(TAPE_WIDTH, 0.0045, MAT.y), Vector3(side * (MAT.x - TAPE_WIDTH) / 2, 0.00225, 0), tape)
	var words := Label3D.new()
	words.text = "OUTGOING"
	# Printed on the mat: the machine voice, bold (style bible §5.3).
	words.font = UiStyle.machine_font(700)
	words.font_size = 64
	words.outline_size = 0
	words.modulate = TAPE
	words.shaded = true
	words.pixel_size = 0.0022
	words.basis = Basis(Vector3.RIGHT, -PI / 2)
	words.position = Vector3(0, 0.005, MAT.y / 2 - TAPE_WIDTH - 0.07)
	add_child(words)

	# The crate: a bottom and four sides of wood, open at the top, with flat
	# boxes standing in it on edge.
	var at := Vector3(CRATE_AT.x, 0, CRATE_AT.y)
	const BOARD := 0.018
	_add(Vector3(CRATE.x, BOARD, CRATE.z), at + Vector3(0, BOARD / 2, 0), wood)
	for side in [-1, 1]:
		_add(Vector3(CRATE.x, CRATE.y * 0.6, BOARD), at + Vector3(0, CRATE.y * 0.3, side * (CRATE.z - BOARD) / 2), wood)
		_add(Vector3(BOARD, CRATE.y, CRATE.z), at + Vector3(side * (CRATE.x - BOARD) / 2, CRATE.y / 2, 0), wood)
	var white := _material(ShippingBox.WHITE, 0.85)
	var blue := _material(ShippingBox.BLUE, 0.7)
	for i in FLAT_BOXES:
		var x := -CRATE.x / 2 + BOARD + 0.03 + i * (CRATE.x - 2 * BOARD - 0.06) / (FLAT_BOXES - 1)
		var lean := Basis(Vector3.BACK, deg_to_rad(6.0))
		var sheet := Vector3(0.006, CRATE.y * 1.15, CRATE.z - 2 * BOARD - 0.01)
		_add(sheet, at + Vector3(x, BOARD + sheet.y / 2, 0), white, lean)
		_add(Vector3(0.0065, sheet.y * 0.18, sheet.z + 0.001), at + Vector3(x, BOARD + sheet.y * 0.09, 0), blue, lean)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CRATE.x, CRATE.y * 1.15, CRATE.z)
	shape.shape = box
	shape.position = at + Vector3(0, box.size.y / 2, 0)
	add_child(shape)


## Whether a point (global) is on the mat.
func on_mat(point: Vector3) -> bool:
	var local := to_local(point)
	return absf(local.x) <= MAT.x / 2 and absf(local.z) <= MAT.y / 2


## The floor rect (x, z) the crate stands on, in the parent's space, to keep
## cards off it.
func crate_footprint() -> Rect2:
	var centre := transform * Vector3(CRATE_AT.x, 0, CRATE_AT.y)
	var turned := absf(sin(rotation.y)) > 0.5
	var size := Vector2(CRATE.z, CRATE.x) if turned else Vector2(CRATE.x, CRATE.z)
	return Rect2(Vector2(centre.x, centre.z) - size / 2, size)


## Where a new box taken from the crate starts (global): just above it.
func new_box_pose() -> Transform3D:
	return global_transform * Transform3D(Basis(), Vector3(CRATE_AT.x, CRATE.y + 0.05, CRATE_AT.y))


func _material(colour: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material


func _add(size: Vector3, at: Vector3, material: Material, turn := Basis()) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.transform = Transform3D(turn, at)
	mesh.material_override = material
	add_child(mesh)
