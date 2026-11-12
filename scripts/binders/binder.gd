class_name Binder
extends RigidBody3D
## One set's binder (plan §3.2). It starts closed on top of the pile; the
## player can carry it, set it down on the floor or a table, open it flat
## there to file cards into its pockets, and shelve it spine out.
##
## The origin is the middle of the binder's underside. Closed, it lies cover
## up with the spine along its -x edge. Open, the two pages lie side by side
## across the origin, reading from the +z side (where the player stands).
## Unlike cards, binders are physics bodies while they lie closed, so they
## rest on each other, slide off each other and settle on the pile (through
## PileWorld's surface collider) instead of passing through one another.
## Open, carried or shelved they're frozen in place. They sit on their own
## collision layer so the player walks through them but can still aim at
## them.
##
## A tossed binder flies a scripted arc like a tossed card (TossedCard), not
## a physics one: it tumbles, bounces softly off walls and furniture, and
## passes through other binders, so a toss never knocks any about. Where it
## comes down it settles on top of whatever is there, binders included,
## cover up or face down depending on how it turned, and is handed back to
## physics.

## Saved by number: new states go on the end.
enum State { CLOSED, OPEN, CARRIED, SHELVED, TOSSED }

const PHYSICS_LAYER := 2
## What a loose binder collides with: the store, other binders and stacks,
## and the pile's surface.
const PHYSICS_MASK := 1 | PHYSICS_LAYER | PileWorld.SURFACE_LAYER
## Set-down binders are lowered from this far above the point until they
## touch something, then left to settle.
const DROP_HEIGHT := 0.4
## Every binder has the same covers; only its thickness depends on its size
## (BinderLayout.SIZE_THICKNESSES).
const COVER := Vector2(0.26, 0.33) # x across the cover, y along the spine
## Page and pocket grid, in metres (keep in step with binder_page.gdshader).
const PAGE := Vector2(0.24, 0.31)
const CELL := Vector2(0.074, 0.099)
## Half the floor footprint when open (two covers side by side). Binders are
## only put down where there's room for this, so they can always be opened.
const OPEN_HALF_FOOTPRINT := Vector2(COVER.x, COVER.y / 2)
## Height of the page surface when the binder lies open.
const OPEN_HEIGHT := 0.012
## A card being filed first stops this far from its pocket (most of a card's
## length up the page, and a little above it), then slides down into it.
const POCKET_ENTRY := Vector3(0, 0.006, -0.06)
const CLOSE_AFTER_COMPLETE := 1.2
## Toss flight (see TossedCard, which this follows): gravity, horizontal air
## drag per second, the share of horizontal speed kept off a wall, and how
## far past its centre it looks for walls (about half the cover's
## diagonal, so its edge is what bounces). Landing, it tips flat onto the
## spot it settles on over SETTLE_SECONDS. Gravity is a quarter stronger
## than a card's so the binder comes down with some weight to it.
## Tithe's glow on the cover and spine (set_tithe): a soft white-gold.
const TITHE_GLOW := Color(1.0, 0.93, 0.75, 0.35)
const TOSS_GRAVITY := 9.8 * 1.25
const TOSS_AIR_DRAG := 1.2
const TOSS_BOUNCE := 0.35
const TOSS_EDGE_REACH := 0.18
const SETTLE_SECONDS := 0.18

const LOCKED_GLOW := Color(1.0, 0.78, 0.3, 0.3)
## A locked-in pocket card looks like its plain face: the lock-in flash
## fades to this.
const POCKET_GLOW := Color(1.0, 0.78, 0.3, 0.0)
const FLASH_GLOW := Color(1.0, 0.85, 0.4, 3.0)
const WRONG_GLOW := Color(1.0, 0.1, 0.06, 1.6)
const PAGE_DONE_GLOW := Color(1.0, 0.8, 0.35, 0.05)
const PAGE_FLASH_GLOW := Color(1.0, 0.8, 0.35, 0.6)

## The look of a closed binder: two stiff leather covers a little larger than
## the pages, a rounded spine with two raised bands, a stack of sleeve pages,
## and three metal rings by the spine.
const COVER_BOARD := 0.004
const PAGE_INSET := Vector2(0.007, 0.008) # page edge to cover edge (x, y)
## The marbled paper inside the covers (style bible §8).
const ENDPAPER := preload("res://assets/ui/frames/marbled.png")
const RING_X := -COVER.x / 2 + 0.021
const RING_ZS := [-0.1, 0.0, 0.1]
const RING_WIRE := 0.0018
## How far the rounded spine bulges out past the covers' edge.
const SPINE_DEPTH := 0.008
## Leather left between a closed binder's rings and the outside of its spine.
const RING_CLEARANCE := 0.0015
## How far away the pages, rings and stitching stop being drawn; 0 draws
## them at any distance. A cut-off (around 3 m) saves a draw call per binder
## out of range but pops visibly as you walk, so it's off by default. It
## belongs in a future low-quality graphics option for players short on
## frame rate.
const DETAIL_RANGE := 0.0
## The cover leather (assets/store/leather), dyed each set's colour, and how
## many metres one copy of it covers. Any leather set with the same three
## file names drops in: the shader takes its grain, creases and shine, and
## its light and dark relative to its own average, so the dye still decides
## the colour however light or dark the texture is.
const LEATHER := "res://assets/store/leather/"
const LEATHER_SIZE := 0.4
## How strongly the normal map's relief shows. Leather025's own relief is
## too faint at this size; a texture with deeper relief wants 1 to 1.5.
const LEATHER_RELIEF := 3.0
## Dyed leather: the dye soaks into a tan hide rather than sitting on top,
## so a binder's colour is the hide's times the dye's. Bright set colours
## come out as oxblood, navy, bottle green, plum or ochre, still told apart
## by hue. DYE_STRENGTH is how much of the set colour the hide takes, and
## DYE_DEPTH how dark the finished leather is.
const HIDE := Color(0.55, 0.47, 0.4)
const DYE_STRENGTH := 0.75
const DYE_DEPTH := 0.42

## Shared by every binder of a size: the leather (one per-binder material)
## and the details (pages, rings, stitching; shared materials), keyed by
## thickness as [leather, details]. Built on first use, like the open view's
## details, which every size shares.
static var _closed_meshes := {}
static var _open_mesh: ArrayMesh
## Shared by every binder's leather: [albedo, roughness, normal, mottle,
## the albedo's average brightness]. Loaded on first use.
static var _leather: Array

var binder: BinderRange
## How thick it is closed, and its closed box (cover, thickness, cover).
var thickness: float
var size: Vector3
var contents: BinderContents
var state := State.CLOSED
## Which spread is showing when open (see BinderLayout.spread_pages).
var spread := 0
var pile: PileWorld
var shelf_unit: ShelfUnit
var shelf_space := -1

var _accent: Color
var _shape: BoxShape3D
var _collision: CollisionShape3D
var _closed_view: Node3D
var _cover_material: ShaderMaterial
var _open_view: Node3D
var _pages: Array[MeshInstance3D] = []
var _pocket_views: Array[MeshInstance3D] = []
var _hover: MeshInstance3D
## The pocket whose card is away being looked at up close (it shows empty
## meanwhile), or -1.
var _lifted_pocket := -1
## Running pocket and page flashes. They're tied to a pocket view, not a
## pocket, so they're stopped whenever the spread changes.
var _flashes: Array[Tween] = []
## Whether Tithe lights this binder now (set_tithe).
var tithe := false
## The status glow under Tithe's (complete, wrong space, flashes).
var _status_glow := Color.BLACK
## In flight (TOSSED): metres per second, and radians per second around the
## binder's own axes. `_toss_exclude` is what it doesn't bounce off (the
## player).
var _toss_velocity := Vector3.ZERO
var _toss_tumble := Vector3.ZERO
var _toss_exclude: Array[RID] = []
## Once it's come down: the pose it's settling into (null until then).
var _landing = null


func setup(range_data: BinderRange, accent: Color, world: PileWorld) -> void:
	binder = range_data
	thickness = BinderLayout.thickness(binder)
	size = Vector3(COVER.x, thickness, COVER.y)
	contents = BinderContents.new(binder)
	pile = world
	_accent = accent
	collision_layer = PHYSICS_LAYER
	collision_mask = PHYSICS_MASK
	mass = 1.2
	add_to_group(PutDown.GROUP)
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.9
	physics_material_override.bounce = 0.0
	freeze = true

	_shape = BoxShape3D.new()
	_collision = CollisionShape3D.new()
	_collision.shape = _shape
	add_child(_collision)
	_set_collision_box(size)

	_closed_view = Node3D.new()
	add_child(_closed_view)
	_cover_material = _leather_material(leather_colour(accent))
	_cover_material.set_shader_parameter("thickness", thickness)
	var set_data := CardDatabase.get_set(binder.set_code)
	var masks := BinderLettering.masks(set_data, thickness)
	var cover_mask := BinderLettering.COVER_MASK
	_cover_material.set_shader_parameter("cover_mask", masks[0])
	_cover_material.set_shader_parameter("cover_rect", Vector4(cover_mask.position.x, cover_mask.position.y, cover_mask.size.x, cover_mask.size.y))
	_cover_material.set_shader_parameter("spine_mask", masks[1])
	_cover_material.set_shader_parameter("spine_span", Vector2(BinderLettering.SPINE_MASK.x, BinderLettering.SPINE_MASK.y - BinderLettering.SPINE_MASK.x))
	var meshes := _closed_meshes_for(thickness)
	var body := MeshInstance3D.new()
	body.mesh = meshes[0]
	body.material_override = _cover_material
	_closed_view.add_child(body)
	var details := MeshInstance3D.new()
	details.mesh = meshes[1]
	details.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	details.visibility_range_end = DETAIL_RANGE
	_closed_view.add_child(details)


## The leather a binder in this set colour is covered in (see HIDE).
static func leather_colour(accent: Color) -> Color:
	var dye := Color.from_hsv(accent.h, minf(accent.s * 1.25, 1.0), 1.0).srgb_to_linear()
	var leather := HIDE.srgb_to_linear() * Color.WHITE.lerp(dye, DYE_STRENGTH) * DYE_DEPTH
	leather.a = 1.0
	return leather.linear_to_srgb()


## A new cover material in this leather colour, sharing the textures.
static func _leather_material(colour: Color) -> ShaderMaterial:
	if _leather.is_empty():
		var albedo: Texture2D = load(LEATHER + "albedo.jpg")
		var mottle := NoiseTexture2D.new()
		mottle.seamless = true
		mottle.width = 256
		mottle.height = 256
		mottle.noise = FastNoiseLite.new()
		mottle.noise.frequency = 0.012
		mottle.noise.fractal_octaves = 3
		_leather = [albedo, load(LEATHER + "roughness.jpg"), load(LEATHER + "normal.jpg"), mottle, _mean_brightness(albedo)]
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/binder_leather.gdshader")
	material.set_shader_parameter("dye", colour)
	material.set_shader_parameter("leather_albedo", _leather[0])
	material.set_shader_parameter("leather_roughness", _leather[1])
	material.set_shader_parameter("leather_normal", _leather[2])
	material.set_shader_parameter("mottle", _leather[3])
	material.set_shader_parameter("leather_mean", _leather[4])
	material.set_shader_parameter("leather_size", LEATHER_SIZE)
	material.set_shader_parameter("normal_strength", LEATHER_RELIEF)
	material.set_shader_parameter("cover_half", COVER / 2)
	return material


## A texture's average brightness, in linear light (as the shader sees it).
static func _mean_brightness(texture: Texture2D) -> float:
	var image := texture.get_image()
	if image == null:
		return 0.9  # No renderer (headless tests); the stock map's average.
	if image.is_compressed():
		image.decompress()
	const SAMPLES := 64
	var total := 0.0
	for y in SAMPLES:
		for x in SAMPLES:
			total += image.get_pixel(x * image.get_width() / SAMPLES, y * image.get_height() / SAMPLES).srgb_to_linear().get_luminance()
	return total / (SAMPLES * SAMPLES)


func is_open() -> bool:
	return state == State.OPEN


func spread_count() -> int:
	return BinderLayout.spread_count(binder)


## The pocket under a world-space point on the open pages, or -1.
func pocket_at(global_point: Vector3) -> int:
	if state != State.OPEN:
		return -1
	var local := to_local(global_point)
	var side := 0 if local.x < 0.0 else 1
	var m := Vector2(local.x - _page_center_x(side), local.z)
	var cell := Vector2i(floori(m.x / CELL.x + 1.5), floori(m.y / CELL.y + 1.5))
	if cell.x < 0 or cell.x > 2 or cell.y < 0 or cell.y > 2:
		return -1
	var page := BinderLayout.spread_pages(binder, spread)[side]
	if page < 0:
		return -1
	var pocket := page * BinderLayout.POCKETS_PER_PAGE + cell.y * BinderLayout.COLUMNS + cell.x
	return pocket if pocket < contents.capacity() else -1


## Where a card in this pocket lies, as a global pose for a card quad (see
## Glide).
func pocket_pose(pocket: int) -> Transform3D:
	return Glide.flat_card(to_global(pocket_position(pocket)), global_basis)


## Where a card waits before sliding into this pocket: just above the page
## and up past the pocket's open top edge (toward -z), as a global pose.
func pocket_entry_pose(pocket: int) -> Transform3D:
	return Glide.flat_card(to_global(pocket_position(pocket) + POCKET_ENTRY), global_basis)


## Local position of a pocket's centre on the current spread (pages up).
func pocket_position(pocket: int) -> Vector3:
	var page := pocket / BinderLayout.POCKETS_PER_PAGE
	var side := 0 if BinderLayout.spread_pages(binder, spread).x == page else 1
	var cell := BinderLayout.pocket_cell(pocket % BinderLayout.POCKETS_PER_PAGE)
	return Vector3(_page_center_x(side) + (cell.x - 1) * CELL.x, OPEN_HEIGHT, (cell.y - 1) * CELL.y)


## Opens the binder flat where it lies, lowered onto whatever is under it
## (or, without `lower`, just where it is: a binder put back from a save).
func open(lower := true) -> void:
	if state != State.CLOSED:
		return
	state = State.OPEN
	_build_open_view()
	_closed_view.visible = false
	_open_view.visible = true
	# Lies flat and still while open, so pockets stay where you aim.
	freeze = true
	rotation = Vector3(0, rotation.y, 0)
	_set_collision_box(Vector3(COVER.x * 2, OPEN_HEIGHT, COVER.y))
	if lower:
		_lower_onto_what_is_below(position.y + DROP_HEIGHT)
	_refresh_spread()


func close() -> void:
	if state != State.OPEN:
		return
	state = State.CLOSED
	set_hover(-1)
	_stop_flashes()
	_open_view.visible = false
	_closed_view.visible = true
	_set_collision_box(size)
	_lower_onto_what_is_below(position.y + DROP_HEIGHT)
	let_go()


## Turns pages: +1 forward, -1 back. Returns false at either end.
func flip(direction: int) -> bool:
	var next := clampi(spread + direction, 0, spread_count() - 1)
	if next == spread or state != State.OPEN:
		return false
	spread = next
	set_hover(-1)
	_stop_flashes()
	_refresh_spread()
	return true


## Opens straight to the spread holding this pocket (used by tests and,
## later, by tools).
func show_pocket(pocket: int) -> void:
	spread = BinderLayout.spread_of_page(pocket / BinderLayout.POCKETS_PER_PAGE)
	_stop_flashes()
	if state == State.OPEN:
		_refresh_spread()


func insert(pocket: int, card_id: int) -> BinderContents.Result:
	var result := contents.insert(pocket, card_id)
	if result != BinderContents.Result.LOCKED:
		return result
	_refresh_spread()
	Progression.earn(Progression.CARD_LOCKED)
	_flash(_pocket_view(pocket), FLASH_GLOW, POCKET_GLOW, 0.9)
	var page := pocket / BinderLayout.POCKETS_PER_PAGE
	if contents.is_page_complete(page):
		_flash(_page_view(page), PAGE_FLASH_GLOW, PAGE_DONE_GLOW, 1.4)
	if contents.is_complete():
		Progression.earn_once("complete:" + key(), Progression.binder_complete_bonus(contents.capacity()))
		_on_complete()
	return result


## Names this binder for bonuses paid once: its set and first number.
func key() -> String:
	return "%s#%d" % [binder.set_code, binder.first]


## Shows a pocket empty while its card is away being looked at up close
## (-1 when none is): the card itself never leaves the pocket.
func set_lifted(pocket: int) -> void:
	_lifted_pocket = pocket
	_refresh_spread()


## Highlights the pocket under the crosshair (-1 for none).
func set_hover(pocket: int) -> void:
	if _hover == null:
		return
	_hover.visible = pocket >= 0 and state == State.OPEN
	if _hover.visible:
		_hover.position = pocket_position(pocket) + Vector3(0, 0.002, 0)


## Lifts the binder into the player's hands (closing it first).
func carry(holder: Node, local_position: Vector3, local_rotation: Vector3) -> void:
	close()
	state = State.CARRIED
	freeze = true
	collision_layer = 0
	collision_mask = 0
	shelf_unit = null
	shelf_space = -1
	_set_status_glow(Color.BLACK)
	_move_to(holder)
	position = local_position
	rotation = local_rotation
	_refresh_complete_look()


## Lays the binder down closed at a point, turned to face `yaw`, on top of
## whatever is there (cards, a table, another binder, a box), lowered from
## `from_height` (DROP_HEIGHT over the point if not given), then lets
## physics settle it.
func put_down(parent: Node, point: Vector3, yaw: float, from_height := NAN) -> void:
	_move_to(parent)
	state = State.CLOSED
	collision_layer = PHYSICS_LAYER
	collision_mask = PHYSICS_MASK
	rotation = Vector3(0, yaw, 0)
	position = point
	_lower_onto_what_is_below(point.y + DROP_HEIGHT if is_nan(from_height) else from_height)
	let_go()


## Something under it went or changed (PutDown.disturb): lying closed, it
## wakes so physics settles it; open (held flat, out of physics), it's
## lowered onto whatever is under it now.
func settle() -> void:
	if state == State.CLOSED and not freeze:
		sleeping = false
	elif state == State.OPEN and is_inside_tree():
		global_position.y = rest_height(Vector2(global_position.x, global_position.z), global_rotation.y,
			global_position.y + 0.005)


## Throws the binder from the global pose `start` (the player's hands) under
## `parent`, at `launch_velocity`, tumbling at `spin` (radians per second
## around its own axes). It flies until it comes down (see _physics_process).
func toss(parent: Node, start: Transform3D, launch_velocity: Vector3, spin: Vector3, exclude: Array[RID] = []) -> void:
	_move_to(parent)
	state = State.TOSSED
	freeze = true
	# Nothing collides with it in the air, and nothing can aim at it.
	collision_layer = 0
	collision_mask = 0
	global_transform = start
	_toss_velocity = launch_velocity
	_toss_tumble = spin
	_toss_exclude = exclude
	_landing = null


func _physics_process(delta: float) -> void:
	if state == State.TOSSED and _landing == null:
		_fly(delta)


func _fly(delta: float) -> void:
	var from := global_position
	_toss_velocity.y -= TOSS_GRAVITY * delta
	var horizontal := Vector2(_toss_velocity.x, _toss_velocity.z) * maxf(0.0, 1.0 - TOSS_AIR_DRAG * delta)
	_toss_velocity.x = horizontal.x
	_toss_velocity.z = horizontal.y
	var to := from + _toss_velocity * delta

	# Walls, shelves and table legs bounce it back softly, as with a card.
	# Only the store counts (layer 1): other binders it flies through.
	var space := get_world_3d().direct_space_state
	var heading := Vector3(_toss_velocity.x, 0, _toss_velocity.z).normalized() * TOSS_EDGE_REACH
	var query := PhysicsRayQueryParameters3D.create(from, to + heading, 1, _toss_exclude)
	var hit := space.intersect_ray(query)
	if not hit.is_empty() and hit.normal.y < -0.7:
		# The underside of a table: it drops back down.
		_toss_velocity.y = -absf(_toss_velocity.y) * TOSS_BOUNCE
		to = Vector3(to.x, from.y, to.z)
	elif not hit.is_empty() and hit.normal.y < 0.7:
		var wall := Vector2(hit.normal.x, hit.normal.z).normalized()
		var across := Vector2(_toss_velocity.x, _toss_velocity.z)
		if across.dot(wall) < 0.0:
			across = across.bounce(wall) * TOSS_BOUNCE
		_toss_velocity.x = across.x
		_toss_velocity.z = across.y
		to = Vector3(from.x, to.y, from.z)

	global_position = to
	if not _toss_tumble.is_zero_approx():
		rotate_object_local(_toss_tumble.normalized(), _toss_tumble.length() * delta)
	if _toss_velocity.y >= 0.0:
		return
	# Down once its lowest corner touches where it would lie; easing flat
	# from there, it tips over onto its cover or its back.
	var rest := toss_rest_pose(from.y)
	var b := global_basis
	var lowest := (global_transform * Vector3(0, thickness / 2, 0)).y \
		- (absf(b.x.y) * size.x + absf(b.y.y) * size.y + absf(b.z.y) * size.z) / 2
	var rest_bottom := rest.origin.y - (thickness if rest.basis.y.y < 0.0 else 0.0)
	if lowest <= rest_bottom:
		_land(rest)


## Where the binder would settle if it came down now: flat, turned the way
## it's facing, cover up or face down (whichever it's nearer), on whatever
## is under it, binders included. On the floor it's kept clear of walls and
## furniture with room to open, as when set down; on a table, all of it on
## the table. `above` is a height it has just come down from, so a table
## top it has crossed still counts as under it. A save (ShopSave) keeps a
## binder in flight here.
func toss_rest_pose(above := INF) -> Transform3D:
	if _landing != null:
		return _landing
	var b := global_basis.orthonormalized()
	var cover_up := b.y.y >= 0.0
	var across := Vector2(b.x.x, b.x.z)
	var yaw := atan2(-b.x.z, b.x.x)
	if across.length() < 0.3:
		# On its edge, spine down or up: the spine's direction decides.
		var along := b.z if cover_up else -b.z
		yaw = atan2(along.x, along.z)
	var at := global_position
	var space := get_world_3d().direct_space_state
	var start := Vector3(at.x, minf(maxf(at.y, 0.0), above) + 0.03, at.z)
	var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(start, Vector3(at.x, -1.0, at.z), 1, _toss_exclude))
	var ground_y: float = ground.position.y if not ground.is_empty() else 0.0
	var p := Vector2(at.x, at.z)
	if ground_y < 0.05:
		if pile != null:
			p = pile.clear_point(p, OPEN_HALF_FOOTPRINT, yaw)
	elif pile != null:
		p = pile.onto_surface(p, yaw, COVER / 2)
	var y := rest_height(p, yaw, ground_y + DROP_HEIGHT)
	var basis := Basis(Vector3.UP, yaw)
	if not cover_up:
		# Face down, end over end: its underside (the origin) is on top.
		basis = basis * Basis(Vector3.RIGHT, PI)
		y += thickness
	return Transform3D(basis, Vector3(p.x, y, p.y))


## Eases flat into `rest`, then lies there like any binder put down. Until
## it's down it still can't be aimed at, so nothing picks it up mid-settle.
func _land(rest: Transform3D) -> void:
	_landing = rest
	var from := global_transform
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: global_transform = from.interpolate_with(rest, t),
		0.0, 1.0, SETTLE_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_settled)


func _settled() -> void:
	_landing = null
	state = State.CLOSED
	collision_layer = PHYSICS_LAYER
	collision_mask = PHYSICS_MASK
	let_go()


## Puts the binder back as a save left it (ShopSave): lying at the global
## pose `at`, closed, or open at `open_spread`. No flashes, and no physics
## query, so it works while the shop is still being built.
func place(parent: Node, at: Transform3D, open_spread := -1) -> void:
	_move_to(parent)
	state = State.CLOSED
	collision_layer = PHYSICS_LAYER
	collision_mask = PHYSICS_MASK
	global_transform = at
	if open_spread >= 0:
		spread = clampi(open_spread, 0, spread_count() - 1)
		open(false)
	else:
		let_go()
	_refresh_complete_look()


## Stands the binder in a shelf space. ShelfUnit decides where and whether
## it's the right space. Only a complete binder in its own space glows gold
## (the same test that turns its nameplate gold); an unfinished one there
## stays dark. A `quiet` one (put back from a save) doesn't flash.
func stand_on_shelf(unit: ShelfUnit, space: int, local_transform: Transform3D, correct: bool, quiet := false) -> void:
	_move_to(unit)
	freeze = true
	transform = local_transform
	state = State.SHELVED
	collision_layer = PHYSICS_LAYER
	collision_mask = 0
	shelf_unit = unit
	shelf_space = space
	if correct and not contents.is_complete():
		_set_status_glow(Color.BLACK)
	elif correct and quiet:
		_set_status_glow(Color(1.0, 0.8, 0.35, 0.12))
	elif correct:
		_flash_status(FLASH_GLOW)
	else:
		_set_status_glow(WRONG_GLOW)


func _on_complete() -> void:
	_refresh_complete_look()
	get_tree().create_timer(CLOSE_AFTER_COMPLETE).timeout.connect(close)


func _refresh_complete_look() -> void:
	if contents.is_complete():
		_set_status_glow(Color(1.0, 0.8, 0.35, 0.5))
		_cover_material.set_shader_parameter("gilt", 1.0)


func _set_status_glow(glow: Color) -> void:
	if glow.a <= 0.0 and contents.is_complete():
		glow = Color(1.0, 0.8, 0.35, 0.5)
	_status_glow = glow
	var shown := Color(glow.r, glow.g, glow.b) * glow.a
	if tithe:
		var lit := Color(TITHE_GLOW.r, TITHE_GLOW.g, TITHE_GLOW.b) * TITHE_GLOW.a
		shown = Color(maxf(shown.r, lit.r), maxf(shown.g, lit.g), maxf(shown.b, lit.b))
	_cover_material.set_shader_parameter("glow", shown)


## Tithe: the binder a Needed card in hand belongs to glows, wherever it is
## (Hands). The glow sits over whatever status glow it has.
func set_tithe(on: bool) -> void:
	if on == tithe:
		return
	tithe = on
	_set_status_glow(_status_glow)


func _flash_status(peak: Color) -> void:
	var settle := Color(1.0, 0.8, 0.35, 0.5) if contents.is_complete() else Color(1.0, 0.8, 0.35, 0.12)
	var tween := create_tween()
	tween.tween_method(_set_status_glow, peak, settle, 1.0)


## Sweeps the collision box straight down from `from_height` (flat, at the
## binder's x, z and yaw) and leaves the binder where it first touches
## something. Outside the tree (tests) it rests on the pile's height map.
func _lower_onto_what_is_below(from_height: float) -> void:
	if not is_inside_tree():
		if pile != null:
			var half := Vector2(_shape.size.x, _shape.size.z) / 2
			position.y = pile.height_under(Vector2(position.x, position.z), half, rotation.y)
		return
	global_position.y = rest_height(Vector2(global_position.x, global_position.z), global_rotation.y, from_height)


## How high the binder would come to rest if lowered flat (closed or open, as
## it is now) from `from_height` at a global x, z, turned to `yaw`.
func rest_height(at: Vector2, yaw: float, from_height: float) -> float:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _shape
	params.collision_mask = PHYSICS_MASK
	params.exclude = [get_rid()]
	params.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, from_height + _shape.size.y / 2, at.y))
	params.motion = Vector3(0, -(from_height + 0.5), 0)
	var safe: float = get_world_3d().direct_space_state.cast_motion(params)[0]
	return from_height + params.motion.y * safe + 0.002


## Hands the binder back to physics, at rest (if it's lying closed).
func let_go() -> void:
	if state != State.CLOSED:
		return
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false


func _move_to(parent: Node) -> void:
	if get_parent() == null:
		parent.add_child(self)
	elif get_parent() != parent:
		reparent(parent, false)


func _set_collision_box(size: Vector3) -> void:
	_shape.size = size
	_collision.position = Vector3(0, size.y / 2, 0)


func _page_center_x(side: int) -> float:
	return (side * 2 - 1) * COVER.x / 2


func _page_view(page: int) -> MeshInstance3D:
	var pages := BinderLayout.spread_pages(binder, spread)
	if page == pages.x:
		return _pages[0]
	return _pages[1] if page == pages.y else null


func _pocket_view(pocket: int) -> MeshInstance3D:
	var page_view := _page_view(pocket / BinderLayout.POCKETS_PER_PAGE)
	if page_view == null:
		return null
	return _pocket_views[_pages.find(page_view) * BinderLayout.POCKETS_PER_PAGE + pocket % BinderLayout.POCKETS_PER_PAGE]


func _flash(view: MeshInstance3D, peak: Color, settle: Color, seconds: float) -> void:
	if view == null:
		return
	var material: ShaderMaterial = view.material_override
	var tween := create_tween()
	tween.tween_method(func(c: Color) -> void: material.set_shader_parameter("glow", c), peak, settle, seconds)
	_flashes.append(tween)


## Stops pocket and page flashes; the next _refresh_spread() sets the glows.
func _stop_flashes() -> void:
	for tween in _flashes:
		if tween.is_valid():
			tween.kill()
	_flashes.clear()


## How a set's endpaper lies (binder_page.gdshader's endpaper_pose):
## quarter turns, mirrored, and an offset, all picked from the set code, so
## each binder's paper differs but is always the same for that binder.
static func endpaper_pose(set_code: String) -> Vector4:
	var h := set_code.hash()
	return Vector4(h & 3, (h >> 2) & 1, float((h >> 3) & 255) / 256.0, float((h >> 11) & 255) / 256.0)


## Builds the pages and pocket cards the first time the binder is opened;
## closed binders on the floor stay cheap.
func _build_open_view() -> void:
	if _open_view != null:
		return
	_open_view = Node3D.new()
	add_child(_open_view)
	var cover_mesh := BoxMesh.new()
	cover_mesh.size = Vector3(COVER.x, COVER_BOARD + 0.001, COVER.y)
	var open_details := MeshInstance3D.new()
	open_details.mesh = _open_view_mesh()
	open_details.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_open_view.add_child(open_details)
	var page_mesh := QuadMesh.new()
	page_mesh.size = PAGE
	var card_mesh := QuadMesh.new()
	card_mesh.size = PileWorld.CARD_SIZE
	var page_shader := preload("res://shaders/binder_page.gdshader")
	var card_shader := preload("res://shaders/binder_card.gdshader")
	for side in 2:
		var cover := MeshInstance3D.new()
		cover.mesh = cover_mesh
		cover.material_override = _cover_material
		cover.position = Vector3(_page_center_x(side), (COVER_BOARD + 0.001) / 2, 0)
		_open_view.add_child(cover)
		var page := MeshInstance3D.new()
		page.mesh = page_mesh
		page.material_override = ShaderMaterial.new()
		page.material_override.shader = page_shader
		page.material_override.set_shader_parameter("endpaper", ENDPAPER)
		page.material_override.set_shader_parameter("endpaper_pose", endpaper_pose(binder.set_code))
		page.rotation.x = -PI / 2
		page.position = Vector3(_page_center_x(side), OPEN_HEIGHT, 0)
		_open_view.add_child(page)
		_pages.append(page)
	for side in 2:
		for i in BinderLayout.POCKETS_PER_PAGE:
			var cell := BinderLayout.pocket_cell(i)
			var card := MeshInstance3D.new()
			card.mesh = card_mesh
			card.material_override = ShaderMaterial.new()
			card.material_override.shader = card_shader
			card.rotation.x = -PI / 2
			card.position = Vector3(_page_center_x(side) + (cell.x - 1) * CELL.x, OPEN_HEIGHT + 0.001, (cell.y - 1) * CELL.y)
			card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_open_view.add_child(card)
			_pocket_views.append(card)
	_hover = MeshInstance3D.new()
	var hover_mesh := QuadMesh.new()
	hover_mesh.size = CELL * 0.98
	_hover.mesh = hover_mesh
	var hover_material := StandardMaterial3D.new()
	hover_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hover_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hover_material.albedo_color = Color(1.0, 0.95, 0.6, 0.22)
	_hover.material_override = hover_material
	_hover.rotation.x = -PI / 2
	_hover.visible = false
	_open_view.add_child(_hover)


func _refresh_spread() -> void:
	if _open_view == null:
		return
	var pages := BinderLayout.spread_pages(binder, spread)
	for side in 2:
		var page: int = pages[side]
		var page_material: ShaderMaterial = _pages[side].material_override
		var first_pocket := page * BinderLayout.POCKETS_PER_PAGE
		var used := clampi(contents.capacity() - first_pocket, 0, BinderLayout.POCKETS_PER_PAGE) if page >= 0 else 0
		page_material.set_shader_parameter("first_number", binder.first + first_pocket)
		page_material.set_shader_parameter("used_pockets", used)
		page_material.set_shader_parameter("endpaper_on", page < 0)
		page_material.set_shader_parameter("glow", PAGE_DONE_GLOW if page >= 0 and contents.is_page_complete(page) else Color(0, 0, 0, 0))
		for i in BinderLayout.POCKETS_PER_PAGE:
			var view := _pocket_views[side * BinderLayout.POCKETS_PER_PAGE + i]
			var id := contents.card_at(first_pocket + i) if i < used else -1
			view.visible = id >= 0 and first_pocket + i != _lifted_pocket
			if id >= 0:
				var material: ShaderMaterial = view.material_override
				CardView.apply(material, id)
				material.set_shader_parameter("glow", POCKET_GLOW)


## The closed meshes for a binder this thick, [leather, details], built the
## first time a binder of that size is set up.
static func _closed_meshes_for(thickness: float) -> Array:
	if _closed_meshes.has(thickness):
		return _closed_meshes[thickness]
	var half := COVER / 2
	var leather := SurfaceTool.new()
	leather.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Covers, flush with the binder's footprint.
	for y in [COVER_BOARD / 2, thickness - COVER_BOARD / 2]:
		_append_box(leather, Vector3(COVER.x, COVER_BOARD, COVER.y), Vector3(0, y, 0))
	# A rounded spine along -x, with a raised band near each end.
	_append_spine(leather, SPINE_DEPTH, thickness / 2, COVER.y, thickness / 2, 0.0)
	for z in [-half.y + 0.035, half.y - 0.035]:
		_append_spine(leather, SPINE_DEPTH + 0.0015, thickness / 2 + 0.0008, 0.008, thickness / 2, z)
	var leather_mesh := leather.commit()

	var pages := SurfaceTool.new()
	pages.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Sheets, each a thin slab with a hairline gap so the edge reads as a stack.
	var page_left := -half.x + 0.022
	var page_right := half.x - PAGE_INSET.x
	var inside := thickness - 2 * COVER_BOARD
	# About 3 mm a sheet, so bigger binders show more of them.
	var sheets := roundi(inside / 0.003)
	for i in sheets:
		var pitch := inside / sheets
		_append_box(pages, Vector3(page_right - page_left, pitch * 0.75, COVER.y - 2 * PAGE_INSET.y),
			Vector3((page_left + page_right) / 2, COVER_BOARD + pitch * (i + 0.5), 0))
	var metal := SurfaceTool.new()
	metal.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The ring mechanism on the back cover, and three rings through the pages.
	_append_box(metal, Vector3(0.014, 0.003, COVER.y - 0.05), Vector3(RING_X, COVER_BOARD + 0.0015, 0))
	for z in RING_ZS:
		_append_ring(metal, inside / 2 - 0.001, RING_WIRE, Vector3(RING_X, thickness / 2, z), ring_reach())
	var thread := SurfaceTool.new()
	thread.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Stitching just inside the edge of both covers.
	for y in [-0.0002, thickness + 0.0002]:
		_append_stitching(thread, Rect2(-half.x + 0.018, -half.y + 0.01, COVER.x - 0.028, COVER.y - 0.02), y)
	var detail_mesh := ArrayMesh.new()
	_commit_surface(detail_mesh, pages, _pages_material())
	_commit_surface(detail_mesh, metal, _metal_material())
	_commit_surface(detail_mesh, thread, _thread_material())
	_closed_meshes[thickness] = [leather_mesh, detail_mesh]
	return _closed_meshes[thickness]


## The open view's details, the same for every size.
static func _open_view_mesh() -> ArrayMesh:
	if _open_mesh != null:
		return _open_mesh
	var half := COVER / 2
	# Open: a page stack under each page, the mechanism and rings down the
	# middle, and stitching round each cover.
	var open_pages := SurfaceTool.new()
	open_pages.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1, 1]:
		_append_box(open_pages, Vector3(PAGE.x, OPEN_HEIGHT - COVER_BOARD - 0.0015, PAGE.y),
			Vector3(side * COVER.x / 2, (OPEN_HEIGHT + COVER_BOARD - 0.0005) / 2, 0))
	var open_metal := SurfaceTool.new()
	open_metal.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(open_metal, Vector3(0.012, 0.0025, COVER.y - 0.05), Vector3(0, COVER_BOARD + 0.0012, 0))
	for z in RING_ZS:
		_append_ring(open_metal, 0.0135, 0.0018, Vector3(0, OPEN_HEIGHT, z))
	var open_thread := SurfaceTool.new()
	open_thread.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1, 1]:
		var x0: float = 0.0 if side > 0 else -COVER.x
		_append_stitching(open_thread, Rect2(x0 + 0.005, -half.y + 0.005, COVER.x - 0.01, COVER.y - 0.01), COVER_BOARD + 0.0012)
	_open_mesh = ArrayMesh.new()
	_commit_surface(_open_mesh, open_pages, _pages_material())
	_commit_surface(_open_mesh, open_metal, _metal_material())
	_commit_surface(_open_mesh, open_thread, _thread_material())
	return _open_mesh


static func _append_box(tool: SurfaceTool, size: Vector3, center: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	tool.append_from(box, 0, Transform3D(Basis.IDENTITY, center))


## A half-round bulge along the -x edge: a flattened cylinder lying along z.
static func _append_spine(tool: SurfaceTool, depth: float, radius: float, length: float, y: float, z: float) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = 24
	cylinder.rings = 1
	var basis := Basis(Vector3(1, 0, 0), PI / 2).scaled(Vector3(depth / radius, 1, 1))
	# Squashing the round flat bends its normals the other way: they need the
	# inverse transpose, which append_from doesn't use. Left as they were, the
	# shading and the leather's triplanar mapping (which goes by the normal)
	# treat the spine's sloping sides as if they faced the covers, and the
	# grain stretches there, more the thicker the binder.
	var arrays := cylinder.get_mesh_arrays()
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	# append_from turns them by `basis`, so they go in pre-turned back.
	var fix := basis.inverse() * basis.inverse().transposed()
	for i in normals.size():
		normals[i] = (fix * normals[i]).normalized()
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var squashed := ArrayMesh.new()
	squashed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	tool.append_from(squashed, 0, Transform3D(basis, Vector3(-COVER.x / 2 + depth, y, z)))


## How far a closed binder's rings may reach toward the spine (-x) from
## their centre, wire included, and stay inside its leather. A ring as tall
## as a thick binder is wider than that, so it's squashed into a D. (The
## spine's outside is furthest out, at the covers' edge, level with the
## rings' centre; rings no taller than the spine fit everywhere else then.)
static func ring_reach() -> float:
	return RING_X + COVER.x / 2 - RING_CLEARANCE


## A metal ring standing across the spine (its loop in the x-y plane). With
## `reach`, a ring wider than that (wire included) is flattened toward -x to
## fit, like a binder's D-ring.
static func _append_ring(tool: SurfaceTool, radius: float, wire: float, center: Vector3, reach := INF) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = radius - wire
	torus.outer_radius = radius + wire
	torus.rings = 24
	torus.ring_segments = 8
	var squash := minf(1.0, (reach - wire) / radius)
	var basis := Basis(Vector3(1, 0, 0), PI / 2)
	if squash < 1.0:
		# Flatten only the spine side (-x): the far side, among the pages,
		# keeps its round.
		var arrays := torus.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			var v := basis * verts[i]
			if v.x < 0.0:
				v.x *= squash
			verts[i] = basis.inverse() * v
		arrays[Mesh.ARRAY_VERTEX] = verts
		var squashed := ArrayMesh.new()
		squashed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		tool.append_from(squashed, 0, Transform3D(basis, center))
		return
	tool.append_from(torus, 0, Transform3D(basis, center))


## Four thin strips of thread round a rectangle (x, z) at height y.
static func _append_stitching(tool: SurfaceTool, rect: Rect2, y: float) -> void:
	const WIDTH := 0.0015
	const HEIGHT := 0.0004
	var c := rect.get_center()
	_append_box(tool, Vector3(rect.size.x, HEIGHT, WIDTH), Vector3(c.x, y, rect.position.y))
	_append_box(tool, Vector3(rect.size.x, HEIGHT, WIDTH), Vector3(c.x, y, rect.end.y))
	_append_box(tool, Vector3(WIDTH, HEIGHT, rect.size.y), Vector3(rect.position.x, y, c.y))
	_append_box(tool, Vector3(WIDTH, HEIGHT, rect.size.y), Vector3(rect.end.x, y, c.y))


static func _commit_surface(mesh: ArrayMesh, tool: SurfaceTool, material: Material) -> void:
	tool.set_material(material)
	tool.commit(mesh)


static func _pages_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.9, 0.88)
	material.roughness = 0.35
	return material


static func _metal_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.78, 0.8)
	material.metallic = 1.0
	material.roughness = 0.3
	return material


static func _thread_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.75, 0.64)
	material.roughness = 0.9
	return material

