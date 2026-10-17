class_name Binder
extends RigidBody3D
## One binder volume (plan §3.2). It starts closed on top of the pile; the
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

enum State { CLOSED, OPEN, CARRIED, SHELVED }

const PHYSICS_LAYER := 2
## What a loose binder collides with: the store, other binders and stacks,
## and the pile's surface.
const PHYSICS_MASK := 1 | PHYSICS_LAYER | PileWorld.SURFACE_LAYER
## Set-down binders are lowered from this far above the point until they
## touch something, then left to settle.
const DROP_HEIGHT := 0.4
const THICKNESS := 0.05
const COVER := Vector2(0.26, 0.33) # x across the cover, y along the spine
const SIZE := Vector3(COVER.x, THICKNESS, COVER.y)
## Page and pocket grid, in metres (keep in step with binder_page.gdshader).
const PAGE := Vector2(0.24, 0.31)
const CELL := Vector2(0.074, 0.099)
## Half the floor footprint when open (two covers side by side). Binders are
## only put down where there's room for this, so they can always be opened.
const OPEN_HALF_FOOTPRINT := Vector2(COVER.x, COVER.y / 2)
## Height of the page surface when the binder lies open.
const OPEN_HEIGHT := 0.012
const CLOSE_AFTER_COMPLETE := 1.2

const LOCKED_GLOW := Color(1.0, 0.78, 0.3, 0.3)
const FLASH_GLOW := Color(1.0, 0.85, 0.4, 3.0)
const WRONG_GLOW := Color(1.0, 0.1, 0.06, 1.6)
const PAGE_DONE_GLOW := Color(1.0, 0.8, 0.35, 0.05)
const PAGE_FLASH_GLOW := Color(1.0, 0.8, 0.35, 0.6)

var binder: BinderRange
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
var _cover_material: StandardMaterial3D
var _labels: Array[Label3D] = []
var _open_view: Node3D
var _pages: Array[MeshInstance3D] = []
var _pocket_views: Array[MeshInstance3D] = []
var _hover: MeshInstance3D
## Running pocket and page flashes. They're tied to a pocket view, not a
## pocket, so they're stopped whenever the spread changes.
var _flashes: Array[Tween] = []


func setup(range_data: BinderRange, accent: Color, world: PileWorld) -> void:
	binder = range_data
	contents = BinderContents.new(binder)
	pile = world
	_accent = accent
	collision_layer = PHYSICS_LAYER
	collision_mask = PHYSICS_MASK
	mass = 1.2
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.9
	physics_material_override.bounce = 0.0
	freeze = true

	_shape = BoxShape3D.new()
	_collision = CollisionShape3D.new()
	_collision.shape = _shape
	add_child(_collision)
	_set_collision_box(SIZE)

	_closed_view = Node3D.new()
	add_child(_closed_view)
	_cover_material = StandardMaterial3D.new()
	_cover_material.albedo_color = accent.darkened(0.35)
	_cover_material.roughness = 0.5
	_cover_material.emission_enabled = true
	_cover_material.emission = Color.BLACK
	var mesh := BoxMesh.new()
	mesh.size = SIZE
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.material_override = _cover_material
	body.position.y = THICKNESS / 2
	_closed_view.add_child(body)

	var cover := _make_label("%s\n%d–%d" % [binder.set_code, binder.first, binder.last], 64, 0.0009)
	cover.rotation.x = -PI / 2
	cover.position.y = THICKNESS + 0.001
	_closed_view.add_child(cover)
	# Spine label on the -x face, reading top to bottom like a real spine.
	var spine := _make_label("%s  %d–%d" % [binder.set_code, binder.first, binder.last], 40, 0.0007)
	spine.rotation.y = -PI / 2
	spine.position = Vector3(-COVER.x / 2 - 0.001, THICKNESS / 2, 0)
	_closed_view.add_child(spine)


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


## Local position of a pocket's centre on the current spread (pages up).
func pocket_position(pocket: int) -> Vector3:
	var page := pocket / BinderLayout.POCKETS_PER_PAGE
	var side := 0 if BinderLayout.spread_pages(binder, spread).x == page else 1
	var cell := BinderLayout.pocket_cell(pocket % BinderLayout.POCKETS_PER_PAGE)
	return Vector3(_page_center_x(side) + (cell.x - 1) * CELL.x, OPEN_HEIGHT, (cell.y - 1) * CELL.y)


func open() -> void:
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
	_set_collision_box(SIZE)
	_lower_onto_what_is_below(position.y + DROP_HEIGHT)
	_let_go()


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
	if result != BinderContents.Result.LOCKED and result != BinderContents.Result.MISPLACED:
		return result
	_refresh_spread()
	if result == BinderContents.Result.LOCKED:
		_flash(_pocket_view(pocket), FLASH_GLOW, LOCKED_GLOW, 0.9)
		var page := pocket / BinderLayout.POCKETS_PER_PAGE
		if contents.is_page_complete(page):
			_flash(_page_view(page), PAGE_FLASH_GLOW, PAGE_DONE_GLOW, 1.4)
		if contents.is_complete():
			_on_complete()
	return result


## Takes an unlocked card out of a pocket; -1 if there isn't one.
func take(pocket: int) -> int:
	var id := contents.take(pocket)
	if id >= 0:
		_refresh_spread()
	return id


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
## whatever is there (cards, a table, another binder), then lets physics
## settle it.
func put_down(parent: Node, point: Vector3, yaw: float) -> void:
	_move_to(parent)
	state = State.CLOSED
	collision_layer = PHYSICS_LAYER
	collision_mask = PHYSICS_MASK
	rotation = Vector3(0, yaw, 0)
	position = point
	_lower_onto_what_is_below(point.y + DROP_HEIGHT)
	_let_go()


## Stands the binder in a shelf space. ShelfUnit decides where and whether
## it's the right space.
func stand_on_shelf(unit: ShelfUnit, space: int, local_transform: Transform3D, correct: bool) -> void:
	_move_to(unit)
	freeze = true
	transform = local_transform
	state = State.SHELVED
	collision_layer = PHYSICS_LAYER
	collision_mask = 0
	shelf_unit = unit
	shelf_space = space
	if correct:
		_flash_status(FLASH_GLOW)
	else:
		_set_status_glow(WRONG_GLOW)


func _on_complete() -> void:
	_refresh_complete_look()
	get_tree().create_timer(CLOSE_AFTER_COMPLETE).timeout.connect(close)


func _refresh_complete_look() -> void:
	if contents.is_complete():
		_set_status_glow(Color(1.0, 0.8, 0.35, 0.5))
		for label in _labels:
			label.modulate = Color(1.0, 0.85, 0.45)


func _set_status_glow(glow: Color) -> void:
	if glow.a <= 0.0 and contents.is_complete():
		glow = Color(1.0, 0.8, 0.35, 0.5)
	_cover_material.emission = Color(glow.r, glow.g, glow.b) * glow.a


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
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _shape
	params.collision_mask = PHYSICS_MASK
	params.exclude = [get_rid()]
	var start := Transform3D(Basis(Vector3.UP, global_rotation.y),
		Vector3(global_position.x, from_height + _shape.size.y / 2, global_position.z))
	params.transform = start
	params.motion = Vector3(0, -(from_height + 0.5), 0)
	var safe: float = get_world_3d().direct_space_state.cast_motion(params)[0]
	global_position.y = from_height + params.motion.y * safe + 0.002


## Hands the binder back to physics, at rest.
func _let_go() -> void:
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


## Builds the pages and pocket cards the first time the binder is opened;
## closed binders on the floor stay cheap.
func _build_open_view() -> void:
	if _open_view != null:
		return
	_open_view = Node3D.new()
	add_child(_open_view)
	var cover_mesh := BoxMesh.new()
	cover_mesh.size = Vector3(COVER.x, OPEN_HEIGHT - 0.002, COVER.y)
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
		cover.position = Vector3(_page_center_x(side), (OPEN_HEIGHT - 0.002) / 2, 0)
		_open_view.add_child(cover)
		var page := MeshInstance3D.new()
		page.mesh = page_mesh
		page.material_override = ShaderMaterial.new()
		page.material_override.shader = page_shader
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
		page_material.set_shader_parameter("glow", PAGE_DONE_GLOW if page >= 0 and contents.is_page_complete(page) else Color(0, 0, 0, 0))
		for i in BinderLayout.POCKETS_PER_PAGE:
			var view := _pocket_views[side * BinderLayout.POCKETS_PER_PAGE + i]
			var id := contents.card_at(first_pocket + i) if i < used else -1
			view.visible = id >= 0
			if id >= 0:
				var material: ShaderMaterial = view.material_override
				CardView.apply(material, id)
				material.set_shader_parameter("glow", LOCKED_GLOW if contents.is_locked(first_pocket + i) else WRONG_GLOW)


func _make_label(text: String, font_size: int, pixel_size: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = Color(0.95, 0.93, 0.88)
	# Labels cost a draw call each; only draw the ones close enough to read.
	label.visibility_range_end = 6.0
	_labels.append(label)
	return label
