class_name WallFrame
extends Node3D
## A picture frame hung on a wall: a dark wood moulding around a white mat,
## and behind the mat's window the art, or while there is none, plain white
## board (WallArt says when a frame is filled, and with what).
##
## Its origin is the frame's centre, against the wall, and it faces local
## +Z; local +X runs left to right as you face it. Nothing of it casts a
## shadow: it stands only a few centimetres off the wall, and the floor
## lamp below the reading corner's frames would throw their outlines up the
## plaster.

const DEPTH := 0.035
const MAT_THICKNESS := 0.004
## How far the art sits behind the mat's face, so the window shows an edge.
const ART_SET_BACK := 0.006
const MAT_COLOUR := Color(0.93, 0.92, 0.89)
const FADE_TIME := 2.0

## The art's size, the mat's width around it, and the moulding's.
var opening := Vector2.ONE
var mat := 0.0
var moulding := 0.0
var filled := false

var _art: MeshInstance3D
var _art_material: StandardMaterial3D


## Outside size of a frame with this art opening, mat and moulding.
static func outer_size(art_size: Vector2, mat_width: float, moulding_width: float) -> Vector2:
	return art_size + Vector2.ONE * 2 * (mat_width + moulding_width)


## Builds the meshes. Call once before adding to the tree.
func build(art_size: Vector2, mat_width: float, moulding_width: float, wood: Material) -> void:
	opening = art_size
	mat = mat_width
	moulding = moulding_width
	var outer := outer_size(opening, mat, moulding)
	var inner := outer - Vector2.ONE * 2 * moulding
	for side in [-1, 1]:
		_box(Vector3(outer.x, moulding, DEPTH), Vector3(0, side * (outer.y - moulding) / 2, DEPTH / 2), wood)
		_box(Vector3(moulding, inner.y, DEPTH), Vector3(side * (outer.x - moulding) / 2, 0, DEPTH / 2), wood)
	var board := StandardMaterial3D.new()
	board.albedo_color = MAT_COLOUR
	board.roughness = 0.95
	var mat_z := DEPTH - 0.012
	for side in [-1, 1]:
		_box(Vector3(inner.x, mat, MAT_THICKNESS), Vector3(0, side * (opening.y + mat) / 2, mat_z), board)
		_box(Vector3(mat, opening.y, MAT_THICKNESS), Vector3(side * (opening.x + mat) / 2, 0, mat_z), board)
	# The white board behind the window, and the art in front of it.
	var back_z := mat_z - MAT_THICKNESS / 2 - ART_SET_BACK
	_box(Vector3(opening.x, opening.y, 0.002), Vector3(0, 0, back_z - 0.001), board)
	_art_material = StandardMaterial3D.new()
	_art_material.roughness = 0.85
	_art = MeshInstance3D.new()
	_art.name = "Art"
	var quad := QuadMesh.new()
	quad.size = opening
	_art.mesh = quad
	_art.material_override = _art_material
	_art.position.z = back_z + 0.0005
	_art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_art.visible = false
	add_child(_art)


## Puts `texture` in the frame, showing its `region` (a UV rectangle) cropped
## to fill the window, centred. With `fade`, it fades in over the white.
func fill(texture: Texture2D, region := Rect2(0, 0, 1, 1), fade := false) -> void:
	filled = true
	if texture == null:
		return
	var crop := cover_crop(region, Vector2(texture.get_size()) * region.size, opening)
	_art_material.albedo_texture = texture
	_art_material.uv1_scale = Vector3(crop.size.x, crop.size.y, 1)
	_art_material.uv1_offset = Vector3(crop.position.x, crop.position.y, 0)
	_art.visible = true
	if not fade or not is_inside_tree():
		return
	_art_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_art_material.albedo_color.a = 0.0
	var tween := create_tween()
	tween.tween_property(_art_material, "albedo_color:a", 1.0, FADE_TIME)
	tween.tween_callback(func() -> void: _art_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED)


## The part of `region` (UVs) that fills a window of `window` shape when
## the region is `pixels` big: the middle of it, cut down on whichever side
## is too long.
static func cover_crop(region: Rect2, pixels: Vector2, window: Vector2) -> Rect2:
	var crop := region
	var aspect := pixels.x / maxf(pixels.y, 1.0)
	var wanted := window.x / window.y
	if aspect > wanted:
		crop.size.x = region.size.x * wanted / aspect
	else:
		crop.size.y = region.size.y * aspect / wanted
	crop.position += (region.size - crop.size) / 2
	return crop


func _box(size: Vector3, center: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.material_override = material
	part.position = center
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
