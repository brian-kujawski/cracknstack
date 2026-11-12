class_name WallPanelling
extends Node3D
## The library's walls below the dado (room plan phase 1): walnut panelling
## to window-sill height, a skirting board at the floor, a dado rail along
## the panelling's top and a cornice under the ceiling. The three mouldings
## are Kiln-built profiles (assets/models/mouldings, a 1 m length each along
## +X with its face toward +Z) stretched to each wall run; the panels are
## one merged mesh of boxes. All of it is only for looking at: the walls'
## own bodies still do the colliding.

## Top of the panelling, the dado rail's top, and the windows' sill.
const HEIGHT := 0.9
## The mouldings, as their nodes are named in the GLB.
const MOULDINGS := preload("res://assets/models/mouldings/mouldings.glb")
const DADO_HEIGHT := 0.06
const CORNICE_HEIGHT := 0.15
## The panelling's back board, and the frame (stiles and rails) proud of it.
const BOARD_DEPTH := 0.012
const FRAME_DEPTH := 0.022
const STILE_WIDTH := 0.07
const RAIL_HEIGHT := 0.07
## About how far apart the stiles stand; each run divides evenly.
const PANEL_SPACING := 0.6
## The bottom rail sits on the skirting; the top rail under the dado.
const SKIRTING_HEIGHT := 0.16


## One stretch of wall: from `start` along `along` (unit, horizontal) for
## `length` metres, the room side being `inward`. `cornice_only` runs (over
## the door) get just the cornice.
class Run:
	var start: Vector3
	var along: Vector3
	var inward: Vector3
	var length: float
	var cornice_only := false

	func _init(from: Vector3, direction: Vector3, room_side: Vector3, metres: float, top_only := false) -> void:
		start = from
		along = direction
		inward = room_side
		length = metres
		cornice_only = top_only


## Builds the panelling along every run, in `wood`, under a ceiling at
## `ceiling` metres.
func build(runs: Array[Run], wood: Material, ceiling: float) -> void:
	var meshes := _moulding_meshes()
	var panels := SurfaceTool.new()
	panels.begin(Mesh.PRIMITIVE_TRIANGLES)
	for run in runs:
		var basis := Basis(run.along, Vector3.UP, run.inward)
		_moulding(meshes["Cornice"], run, basis, ceiling - CORNICE_HEIGHT, wood)
		if run.cornice_only:
			continue
		_moulding(meshes["Skirting"], run, basis, 0.0, wood)
		_moulding(meshes["Dado"], run, basis, HEIGHT - DADO_HEIGHT, wood)
		_panel_boxes(panels, run, basis)
	var panel_mesh := MeshInstance3D.new()
	panel_mesh.name = "Panels"
	panel_mesh.mesh = panels.commit()
	panel_mesh.material_override = wood
	add_child(panel_mesh)


## The wall runs of a `width` x `depth` room whose door, `door_width` wide,
## is centred at `door_z` on the x = width wall.
static func room_runs(width: float, depth: float, door_z: float, door_width: float) -> Array[Run]:
	var half := door_width / 2
	return [
		Run.new(Vector3(0, 0, 0), Vector3.RIGHT, Vector3.BACK, width),
		Run.new(Vector3(width, 0, depth), Vector3.LEFT, Vector3.FORWARD, width),
		Run.new(Vector3(0, 0, depth), Vector3.FORWARD, Vector3.RIGHT, depth),
		Run.new(Vector3(width, 0, 0), Vector3.BACK, Vector3.LEFT, door_z - half),
		Run.new(Vector3(width, 0, door_z - half), Vector3.BACK, Vector3.LEFT, door_width, true),
		Run.new(Vector3(width, 0, door_z + half), Vector3.BACK, Vector3.LEFT, depth - door_z - half),
	]


static func _moulding_meshes() -> Dictionary:
	var meshes := {}
	var scene := MOULDINGS.instantiate()
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node
		for key in ["Skirting", "Dado", "Cornice"]:
			if instance.name.contains(key):
				meshes[key] = instance.mesh
	scene.free()
	return meshes


func _moulding(mesh: Mesh, run: Run, basis: Basis, height: float, wood: Material) -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = wood
	piece.transform = Transform3D(basis.scaled_local(Vector3(run.length, 1, 1)), run.start + Vector3.UP * height)
	add_child(piece)


## The back board, then stiles and top and bottom rails proud of it.
func _panel_boxes(tool: SurfaceTool, run: Run, basis: Basis) -> void:
	var bottom := SKIRTING_HEIGHT
	var top := HEIGHT - DADO_HEIGHT
	_box(tool, run, basis, 0.0, run.length, 0.0, top, BOARD_DEPTH)
	_box(tool, run, basis, 0.0, run.length, bottom, bottom + RAIL_HEIGHT, FRAME_DEPTH)
	_box(tool, run, basis, 0.0, run.length, top - RAIL_HEIGHT, top, FRAME_DEPTH)
	var bays := maxi(1, roundi(run.length / PANEL_SPACING))
	for i in bays + 1:
		var at := clampf(run.length * i / bays, STILE_WIDTH / 2, run.length - STILE_WIDTH / 2)
		_box(tool, run, basis, at - STILE_WIDTH / 2, at + STILE_WIDTH / 2, bottom, top, FRAME_DEPTH)


## A box from `a` to `b` along the run, `y0` to `y1` up, `depth` out from the wall.
func _box(tool: SurfaceTool, run: Run, basis: Basis, a: float, b: float, y0: float, y1: float, depth: float) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(b - a, y1 - y0, depth)
	var centre := run.start + basis * Vector3((a + b) / 2, (y0 + y1) / 2, depth / 2)
	tool.append_from(box, 0, Transform3D(basis, centre))
