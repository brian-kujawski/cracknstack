class_name Laptop
extends ProductBox
## The laptop in the room: a chunky 90s notebook, open, its screen lit with
## the teal desktop. It's handled like a box of product (ProductBox): click
## to pick it up, click to put it down on a table or the floor. It never
## opens like one; instead E (Controls.INTERACT), aimed at it or with it in
## hand, opens the laptop screen (LaptopScreen) for the Card Shop and the
## rest. A new game starts with it on the front left work table.
##
## Its origin is the middle of its base's underside; the screen faces +z.

## The base (x wide, y thick, z deep) and the lid's screen side, in metres:
## about 12" x 9.5", and 1.5" thick, like the notebooks of the day.
const BASE := Vector3(0.30, 0.036, 0.235)
const LID := Vector2(0.30, 0.225)
const LID_THICKNESS := 0.014
## How far the lid leans back past upright (radians).
const LID_LEAN := deg_to_rad(16.0)
const PLASTIC := Color(0.16, 0.16, 0.17)
const KEYS := Color(0.07, 0.07, 0.08)
const SCREEN_GLOW := 0.45


func _init() -> void:
	name = "Laptop"


## Builds it (in place of ProductBox.setup).
func build() -> void:
	set_code = ""
	collision_layer = Binder.PHYSICS_LAYER
	collision_mask = 0
	var plastic := StandardMaterial3D.new()
	plastic.albedo_color = PLASTIC
	plastic.roughness = 0.55
	var keys := StandardMaterial3D.new()
	keys.albedo_color = KEYS
	keys.roughness = 0.8

	_add_box("Base", BASE, Vector3(0, BASE.y / 2, 0), Basis(), plastic, true)
	# The keyboard, and the little trackpad in front of it.
	_add_box("Keyboard", Vector3(BASE.x * 0.86, 0.002, BASE.z * 0.45), Vector3(0, BASE.y + 0.001, -BASE.z * 0.12), Basis(), keys, false)
	_add_box("Trackpad", Vector3(0.06, 0.0015, 0.045), Vector3(0, BASE.y + 0.0008, BASE.z * 0.3), Basis(), keys, false)

	# The lid, hinged at the back of the base and leaning back.
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(0, BASE.y, -BASE.z / 2 + LID_THICKNESS / 2)
	hinge.rotation.x = -LID_LEAN
	add_child(hinge)
	var lid_basis := Basis()
	_add_box("Lid", Vector3(LID.x, LID.y, LID_THICKNESS), Vector3(0, LID.y / 2, 0), lid_basis, plastic, false, hinge)
	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	var quad := QuadMesh.new()
	quad.size = Vector2(LID.x * 0.84, LID.y * 0.78)
	screen.mesh = quad
	screen.position = Vector3(0, LID.y * 0.53, LID_THICKNESS / 2 + 0.0008)
	screen.material_override = _screen_material()
	hinge.add_child(screen)
	# A strip of taskbar along the bottom of the screen.
	var bar := MeshInstance3D.new()
	var bar_quad := QuadMesh.new()
	bar_quad.size = Vector2(quad.size.x, quad.size.y * 0.07)
	bar.mesh = bar_quad
	bar.position = screen.position + Vector3(0, -quad.size.y / 2 + bar_quad.size.y / 2, 0.0004)
	var bar_material := StandardMaterial3D.new()
	bar_material.albedo_color = Win95.FACE
	bar_material.emission_enabled = true
	bar_material.emission = Win95.FACE
	bar_material.emission_energy_multiplier = SCREEN_GLOW * 0.5
	bar.material_override = bar_material
	hinge.add_child(bar)
	# The lid's collider, so aiming at the screen finds the laptop too.
	var lid_shape := CollisionShape3D.new()
	var lid_box := BoxShape3D.new()
	lid_box.size = Vector3(LID.x, LID.y, LID_THICKNESS)
	lid_shape.shape = lid_box
	lid_shape.transform = hinge.transform * Transform3D(lid_basis, Vector3(0, LID.y / 2, 0))
	add_child(lid_shape)


func _screen_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Win95.DESKTOP.darkened(0.3)
	material.emission_enabled = true
	material.emission = Win95.DESKTOP
	material.emission_energy_multiplier = SCREEN_GLOW
	material.roughness = 0.2
	return material


func _add_box(part: String, box_size_: Vector3, at: Vector3, turn: Basis, material: Material, solid: bool, parent: Node3D = self) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = part
	var box := BoxMesh.new()
	box.size = box_size_
	mesh.mesh = box
	mesh.transform = Transform3D(turn, at)
	mesh.material_override = material
	parent.add_child(mesh)
	if solid:
		var shape := CollisionShape3D.new()
		var collider := BoxShape3D.new()
		collider.size = box_size_
		shape.shape = collider
		shape.position = at
		add_child(shape)


## Its whole size, the open lid included (for holding it, and the ghost).
func box_size() -> Vector3:
	return Vector3(BASE.x, BASE.y + LID.y * cos(LID_LEAN), BASE.z)


## Its footprint is the base's.
func half_footprint() -> Vector2:
	return Vector2(BASE.x, BASE.z) / 2


func details() -> String:
	return "Laptop"


## A new game's spot for it: on the front left work table (the one nearest
## the door on your left as you come in), screen toward the door. A floor
## point (x, z) and a yaw.
static func start_spot() -> Array:
	var tables: Array = preload("res://scripts/store/store_builder.gd").TABLE_CENTERS
	var table: Vector2 = tables[2]
	return [Vector2(table.x - 0.15, table.y + 0.25), deg_to_rad(20.0)]
