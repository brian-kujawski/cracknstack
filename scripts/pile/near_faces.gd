class_name NearFaces
extends RefCounted
## Near faces for the floor (card-face-lod-plan.md): sharp faces for the few
## hundred cards close to the player's eyes, drawn over the always-loaded far
## faces (FaceAtlas). They live in a fixed pool of layers on the GPU.
## PileWorld says which cards it wants, nearest first (request()); their
## files load on worker threads, a few are uploaded each frame (update()),
## and cards no longer wanted give up their layer to the next arrival.
##
## The floor shader finds a card's near face in a small lookup texture: per
## face index, its layer (-1 for none), when it arrived (on `clock`, so it
## fades in) and whether it arrived late, after its card was already close
## enough to need it.

## Debug view (pause menu, debug builds): near faces as normal, far faces
## only, or late arrivals tinted red.
enum DebugView { NORMAL, FAR_ONLY, SHOW_LATE }

## Cards across one row of the lookup texture.
const LOOKUP_WIDTH := 256
## Most near faces sent to the GPU in one frame.
const UPLOADS_PER_FRAME := 12
## Most files being read at once.
const MAX_LOADING := 48

## Seconds a near face takes to fade in over the far face.
static var fade_time := 0.25
static var debug_view := DebugView.NORMAL

## How many cards the pool holds.
var capacity := 0
var pool: Texture2DArray
var lookup: ImageTexture
## Seconds since the pool was made: the shader's clock for fading in.
var clock := 0.0
## Near faces shown so far, and how many of them arrived late.
var arrived_count := 0
var late_count := 0

var _paths: PackedStringArray
var _size: Vector2i
var _lookup_image: Image
var _lookup_dirty := false
var _layer_of := {} # face index -> layer
var _face_in := PackedInt32Array() # layer -> face index, or -1
var _free: Array[int] = []
## Layers whose cards weren't in the latest request: the first to give up.
var _spare: Array[int] = []
var _wanted := {} # face index -> true, for the latest request
var _needed := {} # face index -> true: close enough to need its near face now
var _loading := {} # face index -> worker task id
var _inbox := Inbox.new()
var _arrived: Array = [] # [face index, Image or null], waiting to be uploaded


## Where worker threads leave the faces they've read.
class Inbox:
	var mutex := Mutex.new()
	var faces: Array = []


## A pool of `capacity` near faces of `size` px for the cards whose near
## files are `paths` (by face index; "" for a card with none).
func _init(paths: PackedStringArray, size: Vector2i, pool_capacity: int) -> void:
	_paths = paths
	_size = size
	capacity = pool_capacity
	var blank := Image.create_empty(size.x, size.y, true, Image.FORMAT_DXT1)
	var layers: Array[Image] = []
	for layer in capacity:
		layers.append(blank)
		_free.append(capacity - 1 - layer)
	_face_in.resize(capacity)
	_face_in.fill(-1)
	pool = Texture2DArray.new()
	pool.create_from_images(layers)
	_lookup_image = Image.create_empty(LOOKUP_WIDTH, maxi(1, ceili(float(paths.size()) / LOOKUP_WIDTH)), false, Image.FORMAT_RGBF)
	_lookup_image.fill(Color(-1.0, 0.0, 0.0))
	lookup = ImageTexture.create_from_image(_lookup_image)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for task in _loading.values():
			WorkerThreadPool.wait_for_task_completion(task)


## Hands the pool to a floor shader (floor_card.gdshaderinc).
func apply(material: ShaderMaterial) -> void:
	material.set_shader_parameter("near_on", true)
	material.set_shader_parameter("near_faces", pool)
	material.set_shader_parameter("near_lookup", lookup)
	material.set_shader_parameter("near_fade_time", fade_time)


## Per frame, with update(): the clock and debug view.
func apply_frame(material: ShaderMaterial) -> void:
	material.set_shader_parameter("near_time", clock)
	material.set_shader_parameter("near_on", debug_view != DebugView.FAR_ONLY)
	material.set_shader_parameter("near_show_late", debug_view == DebugView.SHOW_LATE)


## The cards that should have near faces, nearest first (only the first
## `capacity` count), and those of them close enough to need one already.
func request(wanted: PackedInt32Array, needed: PackedInt32Array) -> void:
	_wanted.clear()
	for i in mini(wanted.size(), capacity):
		_wanted[wanted[i]] = true
	_needed.clear()
	for face in needed:
		_needed[face] = true
	_spare.clear()
	for layer in capacity:
		if _face_in[layer] >= 0 and not _wanted.has(_face_in[layer]):
			_spare.append(layer)
	for i in mini(wanted.size(), capacity):
		var face := wanted[i]
		if _loading.size() >= MAX_LOADING:
			break
		if _layer_of.has(face) or _loading.has(face) or _paths[face].is_empty():
			continue
		_loading[face] = WorkerThreadPool.add_task(_read.bind(face, _paths[face], _size, _inbox))


## Whether card face `face` has its near face on the GPU.
func has_face(face: int) -> bool:
	return _layer_of.has(face)


## Faces being read, not yet shown.
func loading_count() -> int:
	return _loading.size() + _arrived.size()


## Per frame: sends the faces that have been read to the GPU, a few at a time.
func update(delta: float) -> void:
	clock += delta
	_inbox.mutex.lock()
	_arrived.append_array(_inbox.faces)
	_inbox.faces.clear()
	_inbox.mutex.unlock()
	var uploads := 0
	while not _arrived.is_empty() and uploads < UPLOADS_PER_FRAME:
		var entry: Array = _arrived.pop_front()
		var face: int = entry[0]
		WorkerThreadPool.wait_for_task_completion(_loading[face])
		_loading.erase(face)
		if entry[1] == null or not _wanted.has(face) or _layer_of.has(face):
			continue
		var layer := _take_layer()
		if layer < 0:
			continue
		pool.update_layer(entry[1], layer)
		_layer_of[face] = layer
		_face_in[layer] = face
		var late := _needed.has(face)
		arrived_count += 1
		late_count += int(late)
		_set_lookup(face, Color(layer, clock, 1.0 if late else 0.0))
		uploads += 1
	if _lookup_dirty:
		lookup.update(_lookup_image)
		_lookup_dirty = false


## A free layer, or one whose card is no longer wanted; -1 if every layer
## holds a wanted card.
func _take_layer() -> int:
	if not _free.is_empty():
		return _free.pop_back()
	while not _spare.is_empty():
		var layer: int = _spare.pop_back()
		var face := _face_in[layer]
		if face >= 0 and not _wanted.has(face):
			_layer_of.erase(face)
			_set_lookup(face, Color(-1.0, 0.0, 0.0))
			_face_in[layer] = -1
			return layer
	return -1


func _set_lookup(face: int, value: Color) -> void:
	_lookup_image.set_pixel(face % LOOKUP_WIDTH, face / LOOKUP_WIDTH, value)
	_lookup_dirty = true


## On a worker thread: reads one near face and leaves it in the inbox (null
## if it's missing or not the pool's size and format).
static func _read(face: int, path: String, size: Vector2i, inbox: Inbox) -> void:
	var image := FaceAtlas.load_image(path)
	if image != null and (image.get_size() != size or image.get_format() != Image.FORMAT_DXT1 or not image.has_mipmaps()):
		image = null
	inbox.mutex.lock()
	inbox.faces.append([face, image])
	inbox.mutex.unlock()


## How many near faces the pool holds: enough for every card close enough
## to need one, crouched in a deep heap, at the screen's resolution. Low
## card detail keeps a quarter as many (and its far faces are softer).
static func pool_capacity(screen_height: int, low_detail: bool) -> int:
	if low_detail:
		return 256
	return 2048 if screen_height > 1200 else 1024
