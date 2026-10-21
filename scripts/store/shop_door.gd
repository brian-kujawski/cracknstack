class_name ShopDoor
extends StaticBody3D
## The shop's front door (closed, not usable yet): a plain wooden door in a
## wooden frame, with a round brass knob and three butt hinges. Its origin is
## on the floor at the middle of the doorway, against the wall, and it faces
## local +Z.

## The whole door is drawn this much bigger than the sizes below, so it
## reads as a full-size door next to the player.
const SCALE := 1.2
## The door slab, and the frame (casing) round it.
const LEAF_SIZE := Vector2(1.0, 2.1)
const LEAF_DEPTH := 0.04
const CASING_WIDTH := 0.08
const CASING_DEPTH := 0.02
const JAMB := 0.02
## The frame's jambs stand this far out from the wall, the slab a little less.
const FRAME_DEPTH := 0.07
const LEAF_FRONT := 0.06
const KNOB_HEIGHT := 0.95
## How far the knob's centre is from the slab's latch edge.
const KNOB_INSET := 0.07
## The hinges are on this side of the slab (local x).
const HINGE_SIDE := 1.0


## Builds the meshes and collision, with `brass` for the knob and hinges.
## Call once before adding to the tree.
func build(brass: Material) -> void:
	var wood := _material(Color(0.45, 0.29, 0.17), 0.6)
	var frame := _material(Color(0.36, 0.23, 0.13), 0.6)
	var half := LEAF_SIZE.x / 2
	var top := LEAF_SIZE.y

	# The frame: a jamb lining each side and across the top, with a flat
	# casing on its face.
	for side in [-1, 1]:
		_box(Vector3(JAMB, top + JAMB, FRAME_DEPTH), Vector3(side * (half + JAMB / 2), (top + JAMB) / 2, FRAME_DEPTH / 2), frame)
		_box(Vector3(CASING_WIDTH, top + CASING_WIDTH, CASING_DEPTH),
			Vector3(side * (half + JAMB + CASING_WIDTH / 2), (top + CASING_WIDTH) / 2, FRAME_DEPTH + CASING_DEPTH / 2), frame)
	_box(Vector3(LEAF_SIZE.x, JAMB, FRAME_DEPTH), Vector3(0, top + JAMB / 2, FRAME_DEPTH / 2), frame)
	_box(Vector3(LEAF_SIZE.x + 2 * (JAMB + CASING_WIDTH), CASING_WIDTH, CASING_DEPTH),
		Vector3(0, top + JAMB + CASING_WIDTH / 2, FRAME_DEPTH + CASING_DEPTH / 2), frame)

	# The slab, a hair clear of the floor and the frame.
	const GAP := 0.004
	var slab := Vector3(LEAF_SIZE.x - 2 * GAP, top - 0.01 - GAP, LEAF_DEPTH)
	_box(slab, Vector3(0, 0.01 + slab.y / 2, LEAF_FRONT - LEAF_DEPTH / 2), wood)

	# Butt hinges: a leaf on the slab's face by the hinge edge and a knuckle.
	for y in [0.25, 1.05, 1.85]:
		var edge := HINGE_SIDE * (half - GAP)
		_box(Vector3(0.035, 0.1, 0.003), Vector3(edge - HINGE_SIDE * 0.0175, y, LEAF_FRONT + 0.0015), brass)
		_cylinder(0.007, 0.1, Vector3(edge, y, LEAF_FRONT + 0.004), brass)

	# The knob: a round rose on the slab, a short neck, and the knob itself.
	var knob_x := -HINGE_SIDE * (half - KNOB_INSET)
	_cylinder(0.028, 0.008, Vector3(knob_x, KNOB_HEIGHT, LEAF_FRONT + 0.004), brass).rotation.x = PI / 2
	_cylinder(0.009, 0.035, Vector3(knob_x, KNOB_HEIGHT, LEAF_FRONT + 0.025), brass).rotation.x = PI / 2
	var knob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.028
	sphere.height = 0.045
	knob.mesh = sphere
	knob.material_override = brass
	knob.position = Vector3(knob_x, KNOB_HEIGHT, LEAF_FRONT + 0.055)
	add_child(knob)

	for child in get_children():
		child.position *= SCALE
		child.scale *= SCALE

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(LEAF_SIZE.x + 2 * (JAMB + CASING_WIDTH), top + JAMB + CASING_WIDTH, FRAME_DEPTH + CASING_DEPTH) * SCALE
	shape.shape = box
	shape.position = box.size / 2 * Vector3(0, 1, 1)
	add_child(shape)


## The floor footprint (x across, z out from the wall), in local metres.
static func footprint() -> Rect2:
	var width := LEAF_SIZE.x + 2 * (JAMB + CASING_WIDTH)
	return Rect2(-width / 2 * SCALE, 0, width * SCALE, (FRAME_DEPTH + CASING_DEPTH) * SCALE)


func _box(size: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	add_child(instance)
	return instance


func _cylinder(radius: float, height: float, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	add_child(instance)
	return instance


static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
