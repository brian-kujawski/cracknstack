class_name FloorBinder
extends Node3D
## A binder lying closed on top of the pile, cover up, labelled with its set
## and number range. Picking binders up and filing into them is M3.

const THICKNESS := 0.06
const SIZE := Vector3(0.29, THICKNESS, 0.32)

var binder: BinderRange


func setup(range_data: BinderRange, accent: Color) -> void:
	binder = range_data
	var mesh := BoxMesh.new()
	mesh.size = SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = accent.darkened(0.35)
	material.roughness = 0.5
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.material_override = material
	add_child(body)

	var label := Label3D.new()
	label.text = "%s\n%d–%d" % [binder.set_code, binder.first, binder.last]
	label.font_size = 64
	label.pixel_size = 0.0009
	label.modulate = Color(0.95, 0.93, 0.88)
	label.rotation.x = -PI / 2
	label.position.y = THICKNESS / 2 + 0.001
	# Labels cost a draw call each; only draw the ones close enough to read.
	label.visibility_range_end = 6.0
	add_child(label)
