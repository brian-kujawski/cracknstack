class_name ProductBox
extends RigidBody3D
## A box of sealed product of one set, lying about (on the floor, a table)
## or in hand: a booster box of PackContents.BOX_PACKS packs, or a bulk box
## of PackContents.BULK_SIZE cards. Pick it up with an empty hand, put it
## down like a binder, and press Space (Controls.RIP) with it in hand or
## aimed at to open it: a booster box tips its packs out in a heap where it
## stood, to be picked up and ripped like any pack; a bulk box tips its cards
## out onto the floor or the table under it (PileWorld.tip_out).
##
## A booster box is printed in its set's colours for now, the booster
## wrapper's, with its name on; art can be dropped in later like the packs'.
## A bulk box is plain white cardboard with a printed label, "LEA Bulk".
##
## Its origin is the middle of its underside; it's on the binder collision
## layer, like cards on tables, so it can be aimed at and things rest on it.
## Like a binder it's a physics body while it lies about (see PutDown):
## it rests on whatever is under it, things stack on it, and it falls when
## what's under it goes. In hand, on its way somewhere, or part of something
## else (the card sorter's pockets), it's frozen. The laptop, shipping boxes
## and the sorting tray are ProductBoxes too, so all of that holds for them.

enum Kind { BOOSTER, BULK }

## Outside sizes (x wide, y tall, z deep), in metres: a booster box is
## about 6" x 4" tall x 5", a bulk box 12" x 8" tall x 10".
const BOOSTER_SIZE := Vector3(0.152, 0.102, 0.127)
const BULK_SIZE := Vector3(0.305, 0.203, 0.254)
const CARDBOARD := Color(0.93, 0.92, 0.88)
const LABEL_PAPER := Color(0.98, 0.98, 0.96)
const INK := Color(0.08, 0.08, 0.1)

var kind := Kind.BOOSTER
var set_code := ""


func _init() -> void:
	freeze = true
	add_to_group(PutDown.GROUP)
	mass = 1.0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.9
	physics_material_override.bounce = 0.0


## Put straight into the room (delivered, put back from a save, built with
## the shop), it rests there under physics.
func _ready() -> void:
	if get_parent() is PileWorld:
		let_go()


## Hands it to physics, at rest, where it is.
func let_go() -> void:
	collision_layer = Binder.PHYSICS_LAYER
	collision_mask = Binder.PHYSICS_MASK
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false


## Out of physics: held, or moving somewhere by script. `aimable` false
## takes it off every collision layer too (in hand, nothing aims at it).
func hold_still(aimable := true) -> void:
	freeze = true
	if not aimable:
		collision_layer = 0


## Builds a box of `box_kind` for set `code`.
func setup(box_kind: Kind, code: String) -> void:
	kind = box_kind
	set_code = code
	collision_layer = Binder.PHYSICS_LAYER
	collision_mask = Binder.PHYSICS_MASK
	var size := box_size()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y / 2
	add_child(shape)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var mesh := BoxMesh.new()
	mesh.size = size
	body.mesh = mesh
	body.position.y = size.y / 2
	var material := StandardMaterial3D.new()
	material.roughness = 0.85
	add_child(body)
	var set_data := CardDatabase.get_set(code)
	if kind == Kind.BOOSTER:
		material.albedo_color = set_data.accent_color.darkened(0.15)
		material.roughness = 0.45
		_print(BinderLettering.title_text(set_data), Vector3(0, size.y * 0.62, size.z / 2), Basis(), size.x * 0.85, 0.95)
		_print("BOOSTER BOX", Vector3(0, size.y * 0.3, size.z / 2), Basis(), size.x * 0.7, 0.6)
		_print("%d PACKS - %s" % [PackContents.BOX_PACKS, code], Vector3(0, size.y * 0.15, size.z / 2), Basis(), size.x * 0.6, 0.4)
		_print(BinderLettering.title_text(set_data), Vector3(0, size.y, 0), Basis(Vector3.RIGHT, -PI / 2), size.x * 0.85, 0.95)
	else:
		material.albedo_color = CARDBOARD
		var label := "%s Bulk" % code
		for face in [[Vector3(0, size.y * 0.55, size.z / 2), Basis()],
				[Vector3(0, size.y, 0), Basis(Vector3.RIGHT, -PI / 2)]]:
			var paper := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(size.x * 0.6, size.y * 0.3)
			paper.mesh = quad
			var paper_material := StandardMaterial3D.new()
			paper_material.albedo_color = LABEL_PAPER
			paper.material_override = paper_material
			paper.basis = face[1]
			paper.position = face[0] + face[1].z * 0.0008
			add_child(paper)
			_print(label, face[0], face[1], size.x * 0.5, 1.0, INK)
	body.material_override = material


func box_size() -> Vector3:
	return BOOSTER_SIZE if kind == Kind.BOOSTER else BULK_SIZE


## Its footprint's half size on the floor (x, z).
func half_footprint() -> Vector2:
	var size := box_size()
	return Vector2(size.x, size.z) / 2


## What it's called in the corner while in hand.
func details() -> String:
	return "%s\n%s" % [CardDatabase.get_set(set_code).name, "Booster Box" if kind == Kind.BOOSTER else "Bulk Box"]


## Printed lettering on a face: centred at `at` (box space), facing out
## along the face's +z, fitted to `width` metres; `share` sizes it against
## the box.
func _print(text: String, at: Vector3, face: Basis, width: float, share: float, colour := Color(0.97, 0.85, 0.5)) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = BinderLettering.FONT
	label.font_size = 64
	label.outline_size = 0
	label.modulate = colour
	label.shaded = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = 64 * 12
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.pixel_size = width / label.width * share
	label.basis = face
	label.position = at + face.z * 0.0015
	add_child(label)
