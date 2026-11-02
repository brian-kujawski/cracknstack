class_name BoosterPack
extends Node3D
## A sealed booster pack of one set: a pillowy foil wrapper, crimped top and
## bottom, drawn by booster_pack.gdshader. Its origin is the middle of the
## pack; the front faces +z, the top is +y.
##
## The strip above the tear line is a mesh of its own on a hinge at its
## right-hand end, so ripping (set_tear) peels it up from the left as the
## wrapper tears across, and burst() flings it away.
##
## Each set's wrapper art can be dropped in as assets/packs/<CODE>.png (the
## front) and <CODE>_back.png, any size of the pack's shape (66 x 117 mm,
## portrait); see assets/packs/README.txt. Without it the wrapper is a
## stand-in in the set's colour with its name on.

const SIZE := Vector2(0.066, 0.117)
## How thick the pack is through the middle; it thins to nothing at the
## crimped seams.
const THICKNESS := 0.006
## Crimps top and bottom, and the tear just under the top one, as a share of
## the height from the top.
const CRIMP := 0.075
const TEAR_V := 0.1
## How far the strip above the tear swings up on its hinge by the time the
## tear reaches the far side (radians).
const CAP_PEEL := 0.2
const ART_PATH := "res://assets/packs/%s"
## Lettering masks are drawn this fine (pixels per metre): about as fine as
## the pack ever shows on screen, up close.
const LETTERING_DENSITY := 6000.0
const COLUMNS := 10
const ROWS := 18

static var _meshes: Array[ArrayMesh] = []
## Per set code: [front lettering, back lettering, front art or null,
## back art or null].
static var _looks := {}

var set_code := ""
var tear := 0.0
var _materials: Array[ShaderMaterial] = []
var _cap_pivot: Node3D
var _cap: MeshInstance3D


func _init() -> void:
	if _meshes.is_empty():
		_meshes = [_slab(TEAR_V, 1.0), _slab(0.0, TEAR_V)]
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _meshes[0]
	add_child(body)
	# The strip's hinge is the right-hand end of the tear line.
	_cap_pivot = Node3D.new()
	_cap_pivot.name = "CapHinge"
	_cap_pivot.position = Vector3(SIZE.x / 2, (0.5 - TEAR_V) * SIZE.y, 0)
	add_child(_cap_pivot)
	_cap = MeshInstance3D.new()
	_cap.name = "Cap"
	_cap.mesh = _meshes[1]
	_cap.position = -_cap_pivot.position
	_cap_pivot.add_child(_cap)
	for part in [body, _cap]:
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/booster_pack.gdshader")
		material.set_shader_parameter("crimp", CRIMP)
		material.set_shader_parameter("tear_v", TEAR_V)
		material.set_shader_parameter("cap", part == _cap)
		part.material_override = material
		_materials.append(material)


## Dresses the wrapper as a pack of `code`'s set.
func setup(code: String) -> void:
	set_code = code
	var look: Array = _look(code)
	var accent := CardDatabase.get_set(code).accent_color
	for material in _materials:
		material.set_shader_parameter("accent", Vector3(accent.r, accent.g, accent.b))
		material.set_shader_parameter("lettering", look[0])
		material.set_shader_parameter("back_lettering", look[1])
		material.set_shader_parameter("has_art", look[2] != null)
		material.set_shader_parameter("art", look[2])
		material.set_shader_parameter("has_back_art", look[3] != null)
		material.set_shader_parameter("back_art", look[3])


## How far the wrapper has torn across, 0 to 1. The strip above the tear
## lifts as it goes.
func set_tear(amount: float) -> void:
	tear = clampf(amount, 0.0, 1.0)
	for material in _materials:
		material.set_shader_parameter("tear", tear)
	_cap_pivot.rotation.z = CAP_PEEL * tear * tear


## Torn right off: the strip flies up and away, spinning, and fades out.
func burst(seconds: float) -> void:
	set_tear(1.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(_cap_pivot, "position", _cap_pivot.position + Vector3(0.05, 0.09, 0.02), seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_cap_pivot, "rotation:z", 2.5, seconds)
	tween.tween_property(_cap_pivot, "rotation:x", -1.2, seconds)


func cap_visible() -> bool:
	return _cap.visible


## The wrapper's look for a set, made once and shared by all its packs.
static func _look(code: String) -> Array:
	if not _looks.has(code):
		var set_data := CardDatabase.get_set(code)
		var front := BinderLettering.panel_mask(SIZE, [
			{text = "BOOSTER PACK", center = Vector2(SIZE.x / 2, 0.0145), box = Vector2(0.05, 0.004),
				cap = Vector2(0.0012, 0.0022), lines = 1},
			{text = BinderLettering.title_text(set_data), center = Vector2(SIZE.x / 2, 0.0802),
				box = Vector2(0.056, 0.019), cap = Vector2(0.0018, 0.0055), lines = 3},
			{text = set_data.code, center = Vector2(SIZE.x / 2, 0.0975), box = Vector2(0.03, 0.005),
				cap = Vector2(0.0015, 0.003), lines = 1},
		], LETTERING_DENSITY)
		var back := BinderLettering.panel_mask(SIZE, [
			{text = "BOOSTER PACK", center = Vector2(SIZE.x / 2, 0.048), box = Vector2(0.05, 0.005),
				cap = Vector2(0.0015, 0.003), lines = 1},
			{text = "%d CARDS" % PackContents.SIZE, center = Vector2(SIZE.x / 2, 0.057), box = Vector2(0.04, 0.004),
				cap = Vector2(0.0012, 0.0022), lines = 1},
			{text = set_data.code, center = Vector2(SIZE.x / 2, 0.072), box = Vector2(0.03, 0.006),
				cap = Vector2(0.0015, 0.0035), lines = 1},
		], LETTERING_DENSITY)
		_looks[code] = [front, back, _art(ART_PATH % code), _art((ART_PATH % code) + "_back")]
	return _looks[code]


static func _art(base: String) -> Texture2D:
	var path := RareCards.find_image(base)
	if path.is_empty():
		return null
	var image := FaceAtlas.load_image(path)
	if image == null or image.is_empty():
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## Half the pack's thickness at (u, v) in its front-face space: full through
## the middle, easing to almost nothing at the crimps and along the sides.
static func half_thickness(u: float, v: float) -> float:
	var across := smoothstep(0.0, 0.12, u) * smoothstep(1.0, 0.88, u)
	var along := smoothstep(CRIMP, CRIMP + 0.1, v) * smoothstep(1.0 - CRIMP, 1.0 - CRIMP - 0.1, v)
	return 0.0003 + (THICKNESS / 2 - 0.0003) * sqrt(across * along)


## The wrapper between v_from and v_to (front-face space, 0 at the top):
## its front, its back and the rim joining them all round.
static func _slab(v_from: float, v_to: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := maxi(2, roundi(ROWS * (v_to - v_from)))
	for side in [1, -1]:
		for row in rows:
			for col in COLUMNS:
				var u0 := float(col) / COLUMNS
				var u1 := float(col + 1) / COLUMNS
				var v0 := lerpf(v_from, v_to, float(row) / rows)
				var v1 := lerpf(v_from, v_to, float(row + 1) / rows)
				var a := [u0, v0]
				var b := [u1, v0]
				var c := [u1, v1]
				var d := [u0, v1]
				for tri in [[a, b, c], [a, c, d]]:
					_face_triangle(tool, tri, side)
	# The rim, all round the outline.
	var outline: Array = []
	for col in COLUMNS + 1:
		outline.append([float(col) / COLUMNS, v_from])
	for row in range(1, rows + 1):
		outline.append([1.0, lerpf(v_from, v_to, float(row) / rows)])
	for col in range(COLUMNS - 1, -1, -1):
		outline.append([float(col) / COLUMNS, v_to])
	for row in range(rows - 1, -1, -1):
		outline.append([0.0, lerpf(v_from, v_to, float(row) / rows)])
	var middle := _point(0.5, (v_from + v_to) / 2, 0)
	for i in outline.size() - 1:
		var p: Array = outline[i]
		var q: Array = outline[i + 1]
		var corners := [_point(p[0], p[1], 1), _point(q[0], q[1], 1), _point(q[0], q[1], -1), _point(p[0], p[1], -1)]
		var mid: Vector3 = (corners[0] + corners[1]) / 2
		var outward := Vector3(mid.x - middle.x, mid.y - middle.y, 0).normalized()
		if absf(p[1] - q[1]) < 0.0001:
			outward = Vector3(0, signf(mid.y - middle.y), 0)
		elif absf(p[0] - q[0]) < 0.0001:
			outward = Vector3(signf(mid.x - middle.x), 0, 0)
		for tri in [[0, 1, 2], [0, 2, 3]]:
			var points := [corners[tri[0]], corners[tri[1]], corners[tri[2]]]
			var uvs := [p, q, q, p]
			_add_triangle(tool, points, outward, [outward, outward, outward],
				[Vector2(uvs[tri[0]][0], uvs[tri[0]][1]), Vector2(uvs[tri[1]][0], uvs[tri[1]][1]), Vector2(uvs[tri[2]][0], uvs[tri[2]][1])], 2.0)
	tool.generate_tangents()
	return tool.commit()


static func _face_triangle(tool: SurfaceTool, corners: Array, side: int) -> void:
	var points := []
	var normals := []
	var uvs := []
	for corner: Array in corners:
		points.append(_point(corner[0], corner[1], side))
		normals.append(_normal(corner[0], corner[1], side))
		uvs.append(Vector2(corner[0], corner[1]))
	_add_triangle(tool, points, Vector3(0, 0, side), normals, uvs, 0.0 if side > 0 else 1.0)


## Adds a triangle wound so it faces `outward` (Godot's front faces are
## clockwise as you look at them).
static func _add_triangle(tool: SurfaceTool, points: Array, outward: Vector3, normals: Array, uvs: Array, surface: float) -> void:
	var order := [0, 1, 2]
	if (points[1] - points[0]).cross(points[2] - points[0]).dot(outward) > 0.0:
		order = [0, 2, 1]
	for i in order:
		tool.set_normal(normals[i])
		tool.set_uv(uvs[i])
		tool.set_uv2(Vector2(surface, 0))
		tool.add_vertex(points[i])


static func _point(u: float, v: float, side: int) -> Vector3:
	return Vector3((u - 0.5) * SIZE.x, (0.5 - v) * SIZE.y, side * half_thickness(u, v))


static func _normal(u: float, v: float, side: int) -> Vector3:
	const STEP := 0.002
	var du := (half_thickness(u + STEP, v) - half_thickness(u - STEP, v)) / (2 * STEP)
	var dv := (half_thickness(u, v + STEP) - half_thickness(u, v - STEP)) / (2 * STEP)
	# Front: (-H du, W dv, W H). The back slopes the same way across and
	# along the pack; only its depth is mirrored.
	return Vector3(-SIZE.y * du, SIZE.x * dv, SIZE.x * SIZE.y * side).normalized()
