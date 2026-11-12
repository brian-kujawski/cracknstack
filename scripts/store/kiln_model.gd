class_name KilnModel
extends RefCounted
## Reads the parts out of a model built with Kiln (assets/models/<name>/,
## rebuilt from its .kiln.js with tools/kiln). Kiln names each part; Godot
## keeps only the meshes and their placement in the model, and puts its own
## materials on them, so Kiln's materials are only stand-ins.


## Each named part's mesh and its transform within the model, by name.
## A node counts as a part if its name contains one of `names` (the importer
## can add suffixes).
static func parts(model: PackedScene, names: Array) -> Dictionary:
	var found := {}
	var scene := model.instantiate()
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node
		for key: String in names:
			if instance.name.contains(key) and not found.has(key):
				found[key] = [instance.mesh, _within(instance, scene)]
	scene.free()
	for key: String in names:
		assert(found.has(key), "Kiln model is missing its %s part" % key)
	return found


## A part as a MeshInstance3D under `parent`, at `place` within it, with
## `material` on every surface.
static func add(parent: Node3D, part: Array, material: Material, place := Transform3D.IDENTITY) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = part[0]
	instance.material_override = material
	instance.transform = place * (part[1] as Transform3D)
	parent.add_child(instance)
	return instance


static func _within(node: Node3D, root: Node) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != root:
		if at is Node3D:
			transform = (at as Node3D).transform * transform
		at = at.get_parent()
	return transform
