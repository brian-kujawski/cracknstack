class_name Nameplates
extends MeshInstance3D
## The nameplates on a shelf unit's front edge, one per space: a black enamel
## plate with its set code embossed in gold, which turns into a gold plate
## with black letters once its own completed binder stands above it. All the
## plates are one mesh (one draw call, always drawn, so nothing pops in); a
## plate that's turning gold is lifted out into its own mesh while it glows.

## Plate size (the band it's fixed to is BOARD_THICKNESS + BAND_DROP tall),
## and how far its face stands off the band.
const PLATE_SIZE := Vector2(0.057, 0.034)
const PLATE_THICKNESS := 0.0025
## How far the plate's edge bevels in, all round.
const BEVEL := 0.0012
## The letters: cap height, the most of the plate's width they may take, and
## how far they stand proud of the plate.
const TEXT_HEIGHT := 0.017
const TEXT_MARGIN := 0.005
const TEXT_DEPTH := 0.0008
## How long the glow takes to swell (the plate turns gold at its peak) and
## to fade.
const GLOW_UP := 0.5
const GLOW_DOWN := 1.4

## Colour, metallic, roughness.
const BLACK_ENAMEL := [Color(0.018, 0.018, 0.02), 0.2, 0.28]
const GOLD := [Color(0.93, 0.79, 0.46), 0.6, 0.3]
const BLACK_LETTERS := [Color(0.03, 0.026, 0.022), 0.3, 0.45]

## Per plate: its centre on the band, and whether it's gold now.
var _centers: Array[Vector3] = []
var _gold: Array[bool] = []
## Per plate: [black, gold] flat triangle arrays, made when first needed.
var _arrays: Array = []
var _codes: Array[String] = []
var _widths: Array[float] = []
## Per plate: the mesh it's glowing in while it turns, or null.
var _turning: Array = []
var _material := ShaderMaterial.new()


## One plate per code, centred on each point (its face looks along +z), each
## no wider than its space allows.
func build(codes: Array[String], centers: Array[Vector3], widths: Array[float]) -> void:
	_material.shader = preload("res://shaders/nameplate.gdshader")
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_codes = codes
	_centers = centers
	for i in codes.size():
		_widths.append(minf(PLATE_SIZE.x, widths[i]))
		_gold.append(false)
		_turning.append(null)
		_arrays.append([_plate_arrays(i, false), null])
	_rebuild()


func is_gold(plate: int) -> bool:
	return _gold[plate]


## Turns a plate gold or back to black. Turning gold with `animate` swells a
## glow and turns at its peak; everything else is instant.
func set_gold(plate: int, gold: bool, animate := true) -> void:
	if _gold[plate] == gold:
		return
	_gold[plate] = gold
	if _turning[plate] != null:
		_turning[plate].queue_free()
		_turning[plate] = null
	if not gold or not animate or not is_inside_tree():
		_rebuild()
		return
	var glowing := MeshInstance3D.new()
	glowing.mesh = _mesh_of([_variant(plate, false)])
	glowing.material_override = _material
	glowing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glowing)
	_turning[plate] = glowing
	_rebuild()
	var tween := glowing.create_tween()
	tween.tween_method(_set_glow.bind(glowing), 0.0, 1.0, GLOW_UP).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: glowing.mesh = _mesh_of([_variant(plate, true)]))
	tween.tween_method(_set_glow.bind(glowing), 1.0, 0.0, GLOW_DOWN).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_turning[plate] = null
		glowing.queue_free()
		_rebuild())


func _set_glow(amount: float, instance: MeshInstance3D) -> void:
	instance.set_instance_shader_parameter("glow", amount)


func _variant(plate: int, gold: bool) -> Dictionary:
	var pair: Array = _arrays[plate]
	if gold and pair[1] == null:
		pair[1] = _plate_arrays(plate, true)
	return pair[1] if gold else pair[0]


## Every plate not turning, merged into this one mesh, each at its centre.
func _rebuild() -> void:
	var parts: Array[Dictionary] = []
	for i in _codes.size():
		if _turning[i] == null:
			parts.append(_variant(i, _gold[i]))
	mesh = _mesh_of(parts)


func _mesh_of(parts: Array[Dictionary]) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for part in parts:
		verts.append_array(part["vertex"])
		normals.append_array(part["normal"])
		colors.append_array(part["color"])
		uvs.append_array(part["uv"])
	var built := ArrayMesh.new()
	if verts.is_empty():
		return built
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return built


## One plate's triangles, already at its place on the band: the bevelled
## plate, then the letters standing on its face.
func _plate_arrays(plate: int, gold: bool) -> Dictionary:
	var plate_finish: Array = GOLD if gold else BLACK_ENAMEL
	var letter_finish: Array = BLACK_LETTERS if gold else GOLD
	var out := {"vertex": PackedVector3Array(), "normal": PackedVector3Array(),
		"color": PackedColorArray(), "uv": PackedVector2Array()}
	var center := _centers[plate]
	var width := _widths[plate]
	_add_bevelled_slab(out, center, Vector2(width, PLATE_SIZE.y), plate_finish)
	_add_letters(out, center + Vector3(0, 0, PLATE_THICKNESS), _codes[plate], width - 2 * TEXT_MARGIN, letter_finish)
	return out


## A slab from z = 0 to PLATE_THICKNESS, its face inset by BEVEL with
## sloped edges round it. The back is against the band, so it's left off.
static func _add_bevelled_slab(out: Dictionary, center: Vector3, size: Vector2, finish: Array) -> void:
	var h := size / 2
	var i := h - Vector2(BEVEL, BEVEL)
	var t := PLATE_THICKNESS
	var outer := [Vector3(-h.x, -h.y, 0), Vector3(h.x, -h.y, 0), Vector3(h.x, h.y, 0), Vector3(-h.x, h.y, 0)]
	var inner := [Vector3(-i.x, -i.y, t), Vector3(i.x, -i.y, t), Vector3(i.x, i.y, t), Vector3(-i.x, i.y, t)]
	_add_quad(out, center, inner[0], inner[1], inner[2], inner[3], finish)
	for k in 4:
		var n := (k + 1) % 4
		_add_quad(out, center, outer[k], outer[n], inner[n], inner[k], finish)


## A quad given counter-clockwise as seen from the front, with a flat
## normal. Godot's front faces wind clockwise, so it goes in reversed.
static func _add_quad(out: Dictionary, center: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3, finish: Array) -> void:
	var normal := (b - a).cross(d - a).normalized()
	for v in [a, c, b, a, d, c]:
		_add_vertex(out, center + v, normal, finish)


static func _add_vertex(out: Dictionary, at: Vector3, normal: Vector3, finish: Array) -> void:
	out["vertex"].append(at)
	out["normal"].append(normal)
	out["color"].append((finish[0] as Color).srgb_to_linear())
	out["uv"].append(Vector2(finish[1], finish[2]))


## The code in extruded letters, centred on the point with their back on
## it, scaled to TEXT_HEIGHT caps (or down to fit `max_width`).
static func _add_letters(out: Dictionary, center: Vector3, code: String, max_width: float, finish: Array) -> void:
	var text := TextMesh.new()
	text.text = code
	text.font_size = 64
	text.pixel_size = 0.001
	text.depth = 1.0
	text.curve_step = 0.25
	var arrays := text.get_mesh_arrays()
	var aabb := text.get_aabb()
	if aabb.size.y <= 0.0:
		return
	var scale := minf(TEXT_HEIGHT / aabb.size.y, max_width / aabb.size.x)
	var depth_scale := TEXT_DEPTH / aabb.size.z
	var mid := aabb.get_center()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var stretch := Vector3(scale, scale, depth_scale)
	var order: PackedInt32Array = indices if not indices.is_empty() else PackedInt32Array(range(verts.size()))
	for index in order:
		var v := (verts[index] - mid) * stretch + Vector3(0, 0, TEXT_DEPTH / 2)
		# The letters' sides are square to the face, so squashing the
		# depth leaves every normal as it was.
		_add_vertex(out, center + v, normals[index], finish)
