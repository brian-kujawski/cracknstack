extends Node3D
## Main scene: the graybox store, its empty floor, a bare shelf, and the
## player. Every binder waits out of sight in its shelf space until its set
## unlocks, which happens a chapter at a time (Chapters, open_chapter): a new
## game opens Chapter 1, and completing every binder of a chapter opens the
## next. Each set that unlocks gets its binder and plate on the shelf and a
## sealed booster box inside the door. Cards come only from product (the
## Card Shop; see PackContents). A
## loaded game builds it all from the save instead (ShopSave), and Saves
## asks it for capture_save().
##
## Selling: cards go into shipping boxes (ShippingBox) for money at once,
## and E on the door ends the day (end_day): sealed boxes on the OUTGOING
## mat by the door are collected overnight, and the Card Shop's orders
## turn up inside the door in the morning.

const PILE_SEED := 1993
## Continuing a finished game puts you back in the finished shop with this
## message. Yours to write; until then (empty) nothing pops up.
const ENDING_RETURN_MESSAGE := ""
## The saving icon in the bottom-right corner (a separate image, to redraw):
## its size, how long it shows at least, and one turn of it.
const SAVING_ICON := "res://assets/ui/saving_icon.png"
const SAVING_ICON_SIZE := Vector2(36, 50)
const SAVING_SHOWN := 1.0
const SAVING_TURN := 0.6
## Where Card Shop orders and new sets' booster boxes turn up: a grid of
## floor spots just inside the door, on its left, filled in turn, column by
## column away from the door (a whole chapter's boxes fit before it starts
## over): the rows' z, the first column's x and the step between spots.
const DELIVERY_ROWS := [7.15, 6.75, 6.35, 5.95]
const DELIVERY_X := 5.25
const DELIVERY_STEP := 0.4
const DELIVERY_COLUMNS := 12
## Ending the day: the fade to black, how long it stays black, the fade
## back in, and the hour the new day starts at.
const END_DAY_FADE_OUT := 0.8
const END_DAY_HOLD := 0.8
const END_DAY_FADE_IN := 1.2
const MORNING_HOUR := 8.0
## Sorceries in key order, each with the action that casts it. Only learned
## ones show, in the HUD's sorcery bar.
const SORCERIES := [
	["Tithe", Controls.CAST_TITHE],
	["Teleport", Controls.CAST_TELEPORT],
	["Demonic Tutor", Controls.CAST_DEMONIC_TUTOR],
	["Chain Lightning", Controls.CAST_CHAIN_LIGHTNING],
	["Abundance", Controls.CAST_ABUNDANCE],
]

@onready var _store: Node3D = $Store
@onready var _pile: PileWorld = $Pile
@onready var _hands: Hands = $Player/Hands
## The HUD (Hud): Money, chapter and level top left, the card in hand
## bottom left, the aim's prompt bottom right, notices top right.
var hud: Hud

var _stats_timer := 0.0
## The game's been finished and the ending has started (or a finished game
## was continued).
var _finished := false
var _day: DayCycle
## Cards a loaded save left in the air, still to land ([id, point, yaw,
## face up]); they land once physics is running.
var _falling := []
var _saving_icon: TextureRect
var _saving_tween: Tween
var _debug_rng := RandomNumberGenerator.new()
## The laptop in the room, and its screen (the Card Shop and the rest).
var laptop: Laptop
var laptop_screen: LaptopScreen
var _deliveries := 0
## While open_chapter unlocks a chapter's sets (one banner for them all).
var _opening_chapter := false
## Card Shop orders waiting for the morning: [kind, set code] each.
var orders: Array = []
## Which day it is: the first is day 1, and each End Day adds one.
var day_number := 1
var _ending_day := false
## Today so far, for tomorrow's morning report: money from sales, and Cards
## Organized when the day began.
var today_earned := 0
var today_start_organized := 0
## The day that just ended, for the morning report: money from sales and
## cards filed.
var last_day_earned := 0
var last_day_organized := 0
## Binders already complete (set codes), so finishing one is announced once.
var _complete_binders := {}


func _ready() -> void:
	var started := Time.get_ticks_msec()
	var saved := Saves.take_pending()
	_pile.surfaces = _store.surfaces
	_pile.crouch_eye_height = $Player.crouch_eye_height
	_hands.pile = _pile
	_hands.cabinets = _store.cabinets
	if saved.is_empty():
		Collection.reset()
		_pile.setup(_store.floor_bounds(), _store.obstacles)
		_pile.make_binders()
		shelve_binders(_pile, _shelves())
	else:
		_falling = ShopSave.restore(saved, _pile, _hands, $Player, _shelves(), _store.floor_bounds(), _store.obstacles, PILE_SEED)
	for unit: ShelfUnit in _shelves():
		unit.refresh_locks()
	Progression.set_unlocked.connect(_on_set_unlocked)
	laptop = place_laptop(_pile, saved.get("laptop"))
	_hands.shipping_station = _store.shipping_station
	orders = saved.get("orders", []).duplicate(true)
	day_number = int(saved.get("day", 1))
	today_earned = int(saved.get("today_earned", 0))
	today_start_organized = int(saved.get("today_start_organized", cards_organized(_pile.binders)))
	for binder in _pile.binders:
		if binder.contents.is_complete():
			_complete_binders[binder.binder.set_code] = true
	print("Shop %s: %d cards in %d ms" % ["built" if saved.is_empty() else "loaded", Collection.count(),
		Time.get_ticks_msec() - started])
	_day = DayCycle.new()
	_day.name = "DayCycle"
	add_child(_day)
	_day.setup($WorldEnvironment.environment, _store.window_lights, _store.curtain_material, _store.sky_material)
	ShopSave.restore_day(saved, _day)
	$PauseMenu.day_cycle = _day
	_store.clock.day = _day
	_finished = Saves.finished
	Saves.shop = self
	_build_hud()
	_build_saving_icon()
	open_chapter(saved.is_empty())
	if not _falling.is_empty():
		_land_falling()
	_hang_wall_art(false)
	if _finished and not ENDING_RETURN_MESSAGE.is_empty():
		_show_return_message()
	_hands.shown_card_changed.connect(_on_shown_card_changed)
	_hands.held_pack_changed.connect(func(_code: String) -> void: _on_shown_card_changed(null, false))
	_hands.hint_changed.connect(_on_hint_changed)
	_hands.card_revealed.connect(func(id: int) -> void:
		hud.show_value_tag(Collection.card(id), Collection.copies_of(Collection.card_id(id)).size() == 1))
	_hands.card_sold.connect(func(_id: int, cents: int) -> void:
		today_earned += cents
		hud.show_money_delta(cents))
	_hands.rare_card_found.connect(func() -> void: add_child(RareCardNote.new()))
	_on_shown_card_changed(null, false)
	Progression.mana_changed.connect(func(_mana: int) -> void: _update_stats())
	Progression.money_changed.connect(_update_stats.unbind(1))
	_hands.sale_confirm_requested.connect(func(box: ShippingBox) -> void:
		add_child(SellConfirm.new(func() -> void: _hands.sell_held_card(box, true))))
	_hands.end_day_requested.connect(end_day)
	Progression.unlocked.connect(func(_colour: int, _step: int) -> void: _update_stats())
	Progression.sorceries_changed.connect(_update_stats)
	Progression.level_changed.connect(func(level: int) -> void: hud.show_banner("Level up", "Level %d" % level))
	_update_stats()
	Achievements.unlocked.connect(_on_achievement_unlocked)
	var radio_menu := RadioMenu.new()
	add_child(radio_menu)
	_hands.radio_used.connect(radio_menu.open)
	Radio.enter_shop(_organized_share())
	Radio.song_unlocked.connect(func(index: int) -> void:
		hud.show_toast("New on the radio", Radio.songs[index].title))
	Settings.changed.connect(_apply_brightness.unbind(1))
	_apply_brightness()
	laptop_screen = LaptopScreen.new()
	laptop_screen.name = "LaptopScreen"
	add_child(laptop_screen)
	laptop_screen.day = _day
	laptop_screen.stats = laptop_stats
	laptop_screen.ordered.connect(place_order)
	_hands.laptop_used.connect(laptop_screen.open.bind(false))
	if SceneFlow.take_opening_request():
		laptop_screen.open(true)


func _exit_tree() -> void:
	Radio.leave_shop()
	if Saves.shop == self:
		Saves.shop = null


## Everything in the shop worth saving (see ShopSave).
func capture_save() -> Dictionary:
	return ShopSave.finish(snapshot_save())


## The shop as it is now, quickly, for Saves to finish off the main thread.
## The day and the orders waiting for the morning go in with it.
func snapshot_save() -> Dictionary:
	var taken := ShopSave.snapshot(_pile, _hands, $Player, _day, _falling)
	taken["orders"] = orders.duplicate(true)
	taken["day"] = day_number
	taken["today_earned"] = today_earned
	taken["today_start_organized"] = today_start_organized
	return taken


func _shelves() -> Array:
	return _store.find_children("*", "ShelfUnit", false, false)


## A new game: every binder stands empty in its own shelf space (out of
## sight while its set is locked; ShelfUnit.refresh_locks). One with no space
## (none should be) is dropped on the floor.
static func shelve_binders(pile: PileWorld, shelves: Array) -> void:
	var unplaced := ShelfUnit.shelve_all(pile.binders, shelves)
	if not unplaced.is_empty():
		pile.scatter_binders(unplaced, PILE_SEED)


## The laptop where a save left it (a global pose), or else on its table.
## Returns it.
static func place_laptop(pile: PileWorld, saved_pose = null) -> Laptop:
	var new_laptop := Laptop.new()
	new_laptop.build()
	pile.add_child(new_laptop)
	if saved_pose is Transform3D:
		new_laptop.global_transform = saved_pose
	else:
		var spot: Array = Laptop.start_spot()
		var at: Vector2 = spot[0]
		new_laptop.global_transform = pile.global_transform * Transform3D(Basis(Vector3.UP, spot[1]),
			Vector3(at.x, preload("res://scripts/store/store_builder.gd").TABLE_SIZE.y, at.y))
	return new_laptop


## What the laptop's My Collection shows (LaptopScreen.stats).
func laptop_stats() -> Dictionary:
	var binders := []
	for binder in _pile.binders:
		var code := binder.binder.set_code
		if Progression.is_set_unlocked(code):
			binders.append([code, binder.contents.locked_count, binder.contents.capacity()])
	return {"organized": cards_organized(_pile.binders, _store.cabinets), "pockets": pockets(unlocked_binders(_pile.binders)),
		"mana": Progression.mana, "binders": binders}


## The binders of unlocked sets: the cards packs can bring so far. Nothing
## counts the whole collection until every set is open.
static func unlocked_binders(binders: Array[Binder]) -> Array[Binder]:
	var open: Array[Binder] = []
	for binder in binders:
		if Progression.is_set_unlocked(binder.binder.set_code):
			open.append(binder)
	return open


## The chapter the HUD counts: the latest one with a set unlocked, as
## {"name", "number", "organized", "pockets"} over its unlocked sets'
## binders. Empty before any set is unlocked. Unlocked sets in no chapter
## count as "Unlocked sets" when no chaptered set is open.
static func current_chapter(binders: Array[Binder]) -> Dictionary:
	var open := unlocked_binders(binders)
	if open.is_empty():
		return {}
	var codes := Chapters.shop_codes()
	var number := 0
	for binder in open:
		number = maxi(number, Chapters.number_in(binder.binder.set_code, codes))
	var counted: Array[Binder] = []
	for binder in open:
		if Chapters.number_in(binder.binder.set_code, codes) == number:
			counted.append(binder)
	return {"name": "Chapter %d" % number if number > 0 else "Unlocked sets", "number": number,
		"organized": cards_organized(counted), "pockets": pockets(counted)}


## A Card Shop order (LaptopScreen.ordered, already paid for): kind
## "pack", "booster_box" or "bulk_box", of set `code`. It turns up inside
## the door the next morning.
func place_order(kind: String, code: String) -> void:
	orders.append([kind, code])


## E on the door: the screen fades to black, the night passes
## (start_new_day) and it fades back in on the next morning.
func end_day() -> void:
	if _ending_day or SceneFlow.is_busy():
		return
	_ending_day = true
	var layer := CanvasLayer.new()
	layer.name = "EndDay"
	layer.layer = 9
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.modulate.a = 0.0
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(black)
	add_child(layer)
	get_tree().paused = true
	var tween := layer.create_tween()
	tween.tween_property(black, "modulate:a", 1.0, END_DAY_FADE_OUT)
	await tween.finished
	var shipped := start_new_day()
	var yesterday := [last_day_earned, last_day_organized]
	await get_tree().create_timer(END_DAY_HOLD, true).timeout
	get_tree().paused = false
	tween = layer.create_tween()
	tween.tween_property(black, "modulate:a", 0.0, END_DAY_FADE_IN)
	await tween.finished
	layer.queue_free()
	_ending_day = false
	if shipped > 0:
		hud.show_toast("Shipped", "%d %s" % [shipped, "box" if shipped == 1 else "boxes"])
	if day_number >= 2:
		hud.show_morning(day_number, yesterday[0], yesterday[1])


## The night: sealed shipping boxes on the OUTGOING mat are collected, the
## orders waiting arrive inside the door, and it's morning (if the clock
## is running). Returns how many boxes were collected.
func start_new_day() -> int:
	var shipped := 0
	for child in _pile.get_children():
		if child is ShippingBox and child.sealed and not child.is_queued_for_deletion() \
				and _store.shipping_station.on_mat(child.global_position):
			_pile.remove_child(child)
			child.queue_free()
			shipped += 1
	for order: Array in orders:
		if CardDatabase.get_set(order[1]) != null:
			deliver(order[0], order[1])
	orders.clear()
	day_number += 1
	var organized := cards_organized(_pile.binders)
	last_day_earned = today_earned
	last_day_organized = maxi(organized - today_start_organized, 0)
	today_earned = 0
	today_start_organized = organized
	if Settings.day_seconds() > 0.0:
		_day.set_hour(MORNING_HOUR)
	return shipped


## Product turns up inside the door: kind "pack", "booster_box" or
## "bulk_box", of set `code`. Returns what arrived.
func deliver(kind: String, code: String) -> Node3D:
	var spot := _next_delivery_spot()
	var yaw := _delivery_yaw()
	if kind == "pack":
		var pack := BoosterPack.new()
		pack.setup(code)
		pack.lie(_pile, Vector3(spot.x, _pile.height_at(spot), spot.y), yaw)
		return pack
	var box_kind := ProductBox.Kind.BOOSTER if kind == "booster_box" else ProductBox.Kind.BULK
	return place_box(_pile, box_kind, code, Vector3(spot.x, 0.0, spot.y), yaw)


## The next floor spot inside the door, in turn.
func _next_delivery_spot() -> Vector2:
	var n := _deliveries % (DELIVERY_ROWS.size() * DELIVERY_COLUMNS)
	_deliveries += 1
	return Vector2(DELIVERY_X - DELIVERY_STEP * (n / DELIVERY_ROWS.size()), DELIVERY_ROWS[n % DELIVERY_ROWS.size()])


## Turned toward where you stand as you come in, to the right.
func _delivery_yaw() -> float:
	return PI / 2 + _debug_rng.randf_range(-0.3, 0.3)


## Opens the chapter the player is on: the first one with a set still
## locked or a binder not yet complete. Every set of it unlocks (each brings
## its booster box, _on_set_unlocked), with one banner for the chapter, or
## with `quiet`, none (a new game, behind the laptop). Earlier chapters are
## all complete, so their sets are open already; a loaded game whose
## chapter didn't open (an older save) catches up here. Returns the
## chapter's number, 0 once every chapter is done (or when sets don't lock:
## old checks).
func open_chapter(quiet := false) -> int:
	if not Progression.locks_sets:
		return 0
	var list := Chapters.game()
	for i in list.size():
		if _chapter_complete(i + 1):
			continue
		var opened := 0
		_opening_chapter = true
		for code in list[i]:
			if Progression.unlock_set(code):
				opened += 1
		_opening_chapter = false
		if opened > 0 and not quiet and hud != null:
			var kicker := "Chapter complete" if i > 0 else "New chapter"
			var sub := CardDatabase.get_set(list[i][0]).name if list[i].size() == 1 else "%d new sets" % list[i].size()
			hud.show_banner(kicker, "Chapter %d" % (i + 1), sub)
		return i + 1
	return 0


## A set unlocked: its binder, which waited out of sight in its shelf space,
## shows there and its plate arrives in a glow, and a sealed booster box of
## it turns up inside the door. Returns what was delivered.
func _on_set_unlocked(code: String) -> Array[Node3D]:
	if hud != null and not _opening_chapter:
		hud.show_banner("New set", CardDatabase.get_set(code).name)
	for unit: ShelfUnit in _shelves():
		unit.reveal_set(code)
	var delivered: Array[Node3D] = [deliver("booster_box", code)]
	return delivered


## Developer only (pause menu), until buying exists: a booster box of a
## random set on the floor in front of you.
func debug_booster_box() -> void:
	_debug_box(ProductBox.Kind.BOOSTER)


## Developer only (pause menu): a bulk box of a random set in front of you.
func debug_bulk_box() -> void:
	_debug_box(ProductBox.Kind.BULK)


func _debug_box(kind: ProductBox.Kind) -> void:
	var code := PackContents.pick_set(_debug_rng)
	if code.is_empty():
		return
	var player: Node3D = $Player
	var ahead := player.global_position - player.global_basis.z * 0.8
	place_box(_pile, kind, code, Vector3(ahead.x, 0.0, ahead.z), player.global_rotation.y)


## A new box of product standing on the pile at floor point `at` (global),
## turned to `yaw`. Returns it.
static func place_box(pile: PileWorld, kind: ProductBox.Kind, code: String, at: Vector3, yaw: float) -> ProductBox:
	var box := ProductBox.new()
	box.setup(kind, code)
	var local := pile.to_local(at)
	var p := pile.clear_point(Vector2(local.x, local.z), box.half_footprint(), yaw)
	var y := pile.height_under(p, box.half_footprint(), yaw) if local.y < 0.05 else local.y
	pile.add_child(box)
	box.global_transform = pile.global_transform * Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y, p.y))
	return box


## Cards a save left in the air land once the shop's physics is running,
## which is after the fade-in lets the game go.
func _land_falling() -> void:
	await get_tree().physics_frame
	while get_tree().paused:
		await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	ShopSave.land_falling(_falling, _pile)
	_falling = []


## Placeholder for the message shown when a finished game is continued
## (ENDING_RETURN_MESSAGE): how it pops up is to be designed with it.
func _show_return_message() -> void:
	hud.show_prompt(ENDING_RETURN_MESSAGE)


## The HUD, on the HUD layer in place of the old corner text.
func _build_hud() -> void:
	hud = Hud.new()
	hud.hands = _hands
	hud.sorceries = SORCERIES
	$HUD.add_child(hud)


## The small icon in the bottom-right corner that turns while a save is
## written, for at least SAVING_SHOWN seconds. No text.
func _build_saving_icon() -> void:
	_saving_icon = TextureRect.new()
	_saving_icon.name = "Saving"
	if ResourceLoader.exists(SAVING_ICON):
		_saving_icon.texture = load(SAVING_ICON)
	_saving_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_saving_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_saving_icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_saving_icon.offset_left = -16 - SAVING_ICON_SIZE.x
	_saving_icon.offset_top = -12 - SAVING_ICON_SIZE.y
	_saving_icon.offset_right = -16
	_saving_icon.offset_bottom = -12
	_saving_icon.pivot_offset = SAVING_ICON_SIZE / 2
	_saving_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_saving_icon.process_mode = Node.PROCESS_MODE_ALWAYS
	_saving_icon.visible = false
	$HUD.add_child(_saving_icon)
	_saving_icon.size = SAVING_ICON_SIZE
	hud.saving_icon = _saving_icon
	Saves.saving_started.connect(_show_saving)


## Turns like a card flipped over and over, then fades out.
func _show_saving() -> void:
	if _saving_tween != null:
		_saving_tween.kill()
	_saving_icon.visible = true
	_saving_icon.modulate.a = 1.0
	_saving_tween = _saving_icon.create_tween()
	var turns := ceili(SAVING_SHOWN / SAVING_TURN)
	for i in turns:
		_saving_tween.tween_property(_saving_icon, "scale:x", -1.0, SAVING_TURN / 2).from(1.0).set_trans(Tween.TRANS_SINE)
		_saving_tween.tween_property(_saving_icon, "scale:x", 1.0, SAVING_TURN / 2).set_trans(Tween.TRANS_SINE)
	_saving_tween.tween_property(_saving_icon, "modulate:a", 0.0, 0.3)
	_saving_tween.tween_callback(_saving_icon.hide)


## The Brightness setting is the camera's exposure: everything brighter or
## darker together, without changing a single light.
func _apply_brightness() -> void:
	$WorldEnvironment.environment.tonemap_exposure = Settings.value("brightness")


func _process(delta: float) -> void:
	_stats_timer += delta
	if _stats_timer >= 0.5:
		_stats_timer = 0.0
		_update_stats()
		_announce_complete_binders()
		_hang_wall_art(true)
		if not _finished and is_finished(_pile.binders, _shelves()):
			_finished = true
			Saves.finished = true
			Saves.save(Saves.AUTOSAVE)
			SceneFlow.play_ending()


## Fills each wall art frame whose card is now locked into its pocket, and
## unlocks its achievement; with `fade`, the art fades in (a loaded game
## shows what was already up at once).
func _hang_wall_art(fade: bool) -> void:
	var frames: Array[WallFrame] = _store.wall_frames
	for index in frames.size():
		if not frames[index].filled and WallArt.is_filed(index, _pile.binders):
			var art := WallArt.art(index)
			frames[index].fill(art[0], art[1], fade)
			Achievements.wall_art_hung(index)


## Frame rate, draw calls and the placeholder-data note are for us while
## testing: they show when running from the editor or a debug export, and are
## left out of release exports.
func _update_stats() -> void:
	hud.set_status(Progression.money, current_chapter(_pile.binders), Progression.level(),
		Progression.level_progress(), Progression.LEVEL_MANA)
	hud.debug_label.visible = OS.is_debug_build()
	if OS.is_debug_build():
		var debug := "%d fps · %d draw calls" % [
			Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]
		if not CardDatabase.is_real_data():
			debug += " · Placeholder cards: run tools/import_scryfall.py for Khans of Tarkir"
		hud.debug_label.text = debug
	Radio.set_progress(_organized_share())


## A binder just filled its last pocket: a banner, or, when that completes
## its chapter, the next chapter opens (open_chapter, with its own banner;
## after the last one, a "Chapter complete" banner).
func _announce_complete_binders() -> void:
	for binder in _pile.binders:
		var code := binder.binder.set_code
		if _complete_binders.has(code) or not binder.contents.is_complete():
			continue
		_complete_binders[code] = true
		var chapter := Chapters.game_number(code)
		if chapter > 0 and _chapter_complete(chapter):
			if open_chapter() == 0:
				hud.show_banner("Chapter complete", "Chapter %d" % chapter)
		else:
			hud.show_banner("Binder complete", CardDatabase.get_set(code).name)


## Every set of chapter `number` is unlocked and its binder complete.
func _chapter_complete(number: int) -> bool:
	var sets: PackedStringArray = Chapters.game()[number - 1]
	for binder in _pile.binders:
		if binder.binder.set_code in sets and not binder.contents.is_complete():
			return false
	for code in sets:
		if not Progression.is_set_unlocked(code):
			return false
	return true


## Cards Organized as a share of every card, for the radio's unlocks.
func _organized_share() -> float:
	return float(cards_organized(_pile.binders, _store.cabinets)) / maxf(1.0, pockets(_pile.binders))


## The game is finished when every binder pocket holds its own card, locked
## in, and every binder stands in its own shelf space. The display cabinets
## don't count: nothing brings rare cards for them yet (card-copies-plan.md).
static func is_finished(binders: Array[Binder], shelves: Array) -> bool:
	for binder in binders:
		if not binder.contents.is_complete():
			return false
	for shelf: ShelfUnit in shelves:
		for space in shelf.spaces.size():
			if shelf.spaces[space] != null and (shelf.shelved[space] == null or shelf.shelved[space].binder != shelf.spaces[space]):
				return false
	return not binders.is_empty()


## Every pocket of every binder: the most Cards Organized can reach.
static func pockets(binders: Array[Binder]) -> int:
	var count := 0
	for binder in binders:
		count += binder.contents.capacity()
	return count


## Cards locked into their own pockets, across every binder, and rare cards
## on display.
static func cards_organized(binders: Array[Binder], cabinets: Array = []) -> int:
	var count := 0
	for binder in binders:
		count += binder.contents.locked_count
	for cabinet: DisplayCabinet in cabinets:
		count += cabinet.displayed_count()
	return count


## One line per learned sorcery: its key and name, and while it recharges,
## the seconds left, or "armed" while it waits to go off.
## "3: Demonic Tutor (42 s)"
static func sorcery_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for entry in SORCERIES:
		if Progression.rank(entry[0]) == 0:
			continue
		var line := "%s: %s" % [Controls.label(entry[1]), entry[0]]
		var left := Progression.recharge_left(entry[0])
		if Progression.is_armed(entry[0]):
			line += " (armed)"
		elif left > 0.0:
			line += " (%d s)" % ceili(left)
		lines.append(line)
	return lines


## An achievement's notice in the top right for a few seconds, with its
## icon. A newer notice takes its place.
func _on_achievement_unlocked(index: int) -> void:
	hud.show_toast("Achievement", Achievements.card_name(index), Achievements.icon(index))


## The card plate: the box or pack in hand, or the card shown (with its
## Needed / Duplicate chip). A shipping box shows nothing here; its fill
## floats over it (Hud).
func _on_shown_card_changed(card: CardData, set_only: bool) -> void:
	hud.card_changed(card)
	if _hands.held_box is ShippingBox:
		hud.clear_card()
	elif _hands.held_box != null:
		hud.show_product(_hands.held_box.details())
	elif _hands.held_pack != null:
		hud.show_product(pack_details(_hands.held_pack.set_code))
	elif card == null:
		hud.clear_card()
	elif set_only:
		hud.show_set_only(card)
	else:
		hud.show_card(card, _hands.copy_status(_hands.shown_card_id()))


## The prompt plate. At the door, what ending the day will do sits above
## "E: End Day".
func _on_hint_changed(text: String) -> void:
	if _hands.aiming_at_door():
		var lines := end_day_preview()
		if not lines.is_empty():
			text = "\n".join(lines) + "\n" + text
	hud.show_prompt(text)


## What ending the day would do, one line each: sealed boxes on the mat
## ship, orders arrive. Nothing to say, no lines.
func end_day_preview() -> PackedStringArray:
	var lines := PackedStringArray()
	var boxes := 0
	for child in _pile.get_children():
		if child is ShippingBox and child.sealed and not child.is_queued_for_deletion() \
				and _store.shipping_station.on_mat(child.global_position):
			boxes += 1
	if boxes > 0:
		lines.append("Ships %d %s tonight" % [boxes, "box" if boxes == 1 else "boxes"])
	if not orders.is_empty():
		lines.append("%d %s arrive%s" % [orders.size(), "order" if orders.size() == 1 else "orders",
			"s" if orders.size() == 1 else ""])
	return lines


## A booster pack in hand: its set's name, then what it is.
static func pack_details(code: String) -> String:
	return "%s\nBooster Pack" % CardDatabase.get_set(code).name


## All you know of a card from its set (Enlightened Tutor): the set's name,
## then its code with the number still unknown, "KTK #???".
static func set_details(card: CardData) -> String:
	var set_data := CardDatabase.get_set(card.set_code)
	return "%s\n%s #???" % [set_data.name, set_data.code]


## A card's details as shown in the corner: name, set, number, and rarity
## with what it sells for.
static func card_details(card: CardData) -> String:
	var set_data := CardDatabase.get_set(card.set_code)
	return "%s\n%s\n%s #%s/%s\n%s · %s" % [
		card.name, set_data.name, set_data.code, set_data.number_text(card.collector_number),
		set_data.number_text(set_data.card_count), CardData.Rarity.keys()[card.rarity].capitalize(),
		Progression.money_text(Prices.sale_cents(card))]
