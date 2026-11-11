class_name Furniture
extends RefCounted
## Shared parts that keep the library's furniture in one style with the
## bookcase: fluted tapered legs in brass foot caps (assets/models/furniture),
## and the bookcase's mouldings (assets/models/bookcase) laid along an edge.

const PARTS := preload("res://assets/models/furniture/furniture.glb")
const MOULDINGS := preload("res://assets/models/bookcase/bookcase.glb")
const ROOM_MOULDINGS := preload("res://assets/models/mouldings/mouldings.glb")

static var _legs := {}
static var _mouldings := {}


## A fluted leg standing on the floor at `foot` (in `parent`'s space), `top`
## wide at the top and `height` tall, in a brass foot cap.
static func leg(parent: Node3D, foot: Vector3, top: float, height: float, wood: Material, brass: Material) -> void:
	if _legs.is_empty():
		_legs = KilnModel.parts(PARTS, ["FlutedLeg", "LegBlock", "FootCap"])
	var place := Transform3D(Basis.from_scale(Vector3(top, height, top)), foot)
	KilnModel.add(parent, _legs["FlutedLeg"], wood, place)
	KilnModel.add(parent, _legs["LegBlock"], wood, place)
	KilnModel.add(parent, _legs["FootCap"], brass, place)


## One of the bookcase's mouldings ("ShelfEdge", "Crown", "BaseCap",
## "Pilaster") or the room's "Skirting", as a 1 m part (see KilnModel.parts).
static func moulding(name: String) -> Array:
	if _mouldings.is_empty():
		_mouldings = KilnModel.parts(MOULDINGS, ["ShelfEdge", "Crown", "BaseCap", "Pilaster"])
		_mouldings["Skirting"] = KilnModel.parts(ROOM_MOULDINGS, ["Skirting"])["Skirting"]
	return _mouldings[name]


## A moulding laid from `start` along `along` for `length`, its face toward
## `facing`. `along` must turn into `facing` seen from above (along × up =
## facing), or it comes out mirrored.
static func run(parent: Node3D, name: String, start: Vector3, along: Vector3, length: float, facing: Vector3, material: Material) -> void:
	var basis := Basis(along, Vector3.UP, facing)
	KilnModel.add(parent, moulding(name), material, Transform3D(basis.scaled_local(Vector3(length, 1, 1)), start))


## A moulding round all four sides of a rectangle `size` (x by z) centred
## on `center`, its top at `center.y`, faces out. The front and back runs
## reach past the corners by `depth` (the moulding's own depth) to close them.
static func ring(parent: Node3D, name: String, center: Vector3, size: Vector2, depth: float, material: Material) -> void:
	var hx := size.x / 2
	var hz := size.y / 2
	run(parent, name, center + Vector3(-hx - depth, 0, hz), Vector3.RIGHT, size.x + 2 * depth, Vector3.BACK, material)
	run(parent, name, center + Vector3(hx + depth, 0, -hz), Vector3.LEFT, size.x + 2 * depth, Vector3.FORWARD, material)
	run(parent, name, center + Vector3(hx, 0, hz), Vector3.FORWARD, size.y, Vector3.RIGHT, material)
	run(parent, name, center + Vector3(-hx, 0, -hz), Vector3.BACK, size.y, Vector3.LEFT, material)
