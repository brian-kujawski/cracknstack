class_name ShelfUnit
extends StaticBody3D
## One graybox shelving unit. Its origin is on the floor, centred under the
## unit, and its open front faces local +Z.
##
## Labelled units show each binder's set code and number range on the shelf
## lip under its space; the binders themselves arrive in M2/M3.

const SPACE_WIDTH := 0.1
const WIDTH := ShelfLayout.SPACES_PER_SHELF * SPACE_WIDTH
const DEPTH := 0.35
const HEIGHT := 2.2
const BOARD_THICKNESS := 0.04
const SIDE_THICKNESS := 0.03
## Height of each shelf board's top surface, top shelf first.
const SHELF_HEIGHTS := [1.75, 1.35, 0.95, 0.55, 0.15]

## Per space (shelf * SPACES_PER_SHELF + space): the binder that belongs
## there, or null. Empty for unlabelled units such as aisle gondolas.
var spaces: Array = []


## Builds the meshes, collision and labels. Call once before adding to the tree.
func build(space_binders: Array, material: Material) -> void:
	spaces = space_binders
	_add_box(Vector3(SIDE_THICKNESS, HEIGHT, DEPTH), Vector3(-(WIDTH + SIDE_THICKNESS) / 2, HEIGHT / 2, 0), material)
	_add_box(Vector3(SIDE_THICKNESS, HEIGHT, DEPTH), Vector3((WIDTH + SIDE_THICKNESS) / 2, HEIGHT / 2, 0), material)
	_add_box(Vector3(WIDTH, HEIGHT, 0.02), Vector3(0, HEIGHT / 2, -DEPTH / 2 + 0.01), material)
	_add_box(Vector3(WIDTH, BOARD_THICKNESS, DEPTH), Vector3(0, HEIGHT - BOARD_THICKNESS / 2, 0), material)
	for top in SHELF_HEIGHTS:
		_add_box(Vector3(WIDTH, BOARD_THICKNESS, DEPTH), Vector3(0, top - BOARD_THICKNESS / 2, 0), material)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH + 2 * SIDE_THICKNESS, HEIGHT, DEPTH)
	shape.shape = box
	shape.position.y = HEIGHT / 2
	add_child(shape)

	for i in spaces.size():
		var binder: BinderRange = spaces[i]
		if binder == null:
			continue
		var label := Label3D.new()
		label.text = "%s\n%d–%d" % [binder.set_code, binder.first, binder.last]
		label.font_size = 32
		label.pixel_size = 0.0007
		label.modulate = Color(0.15, 0.15, 0.15)
		label.outline_size = 0
		label.double_sided = false
		label.position = space_position(i / ShelfLayout.SPACES_PER_SHELF, i % ShelfLayout.SPACES_PER_SHELF)
		label.position.y -= BOARD_THICKNESS / 2
		label.position.z = DEPTH / 2 + 0.002
		label.set_meta("binder_label", binder.label)
		add_child(label)


## Local position of the centre of a space's floor (the top of its board).
func space_position(shelf: int, space: int) -> Vector3:
	return Vector3(-WIDTH / 2 + SPACE_WIDTH * (space + 0.5), SHELF_HEIGHTS[shelf], 0)


func _add_box(size: Vector3, center: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	add_child(instance)
