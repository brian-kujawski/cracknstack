extends Node3D
## Main scene: the graybox store, the whole collection and every binder
## dumped on its floor, and the player. A loaded game builds it all from the
## save instead (ShopSave), and Saves asks it for capture_save().

const PILE_SEED := 1993
## How long "Achievement: Tithe" stays up in the top right, and its fade.
const ACHIEVEMENT_SHOWN := 4.0
const ACHIEVEMENT_FADE := 0.6
## Sorceries in key order, each with the action that casts it. Only learned
## ones show, under the Mana total.
## Continuing a finished game puts you back in the finished shop with this
## message. Yours to write; until then (empty) nothing pops up.
const ENDING_RETURN_MESSAGE := ""
## The saving icon in the bottom-right corner (a separate image, to redraw):
## its size, how long it shows at least, and one turn of it.
const SAVING_ICON := "res://assets/ui/saving_icon.png"
const SAVING_ICON_SIZE := Vector2(36, 50)
const SAVING_SHOWN := 1.0
const SAVING_TURN := 0.6
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
@onready var _status: Label = $HUD/Status
@onready var _held: Label = $HUD/Held
@onready var _hint: Label = $HUD/Hint
@onready var _achievement: Label = $HUD/Achievement

var _stats_timer := 0.0
var _achievement_tween: Tween
## The game's been finished and the ending has started (or a finished game
## was continued).
var _finished := false
var _day: DayCycle
## Cards a loaded save left in the air, still to land ([id, point, yaw,
## face up]); they land once physics is running.
var _falling := []
var _saving_icon: TextureRect
var _saving_tween: Tween


func _ready() -> void:
	var started := Time.get_ticks_msec()
	var saved := Saves.take_pending()
	_pile.surfaces = _store.surfaces
	_pile.crouch_eye_height = $Player.crouch_eye_height
	_hands.pile = _pile
	_hands.cabinets = _store.cabinets
	if saved.is_empty():
		_pile.build(_store.floor_bounds(), _store.obstacles, PILE_SEED)
		_pile.spawn_binders(PILE_SEED)
	else:
		_falling = ShopSave.restore(saved, _pile, _hands, $Player, _shelves(), _store.floor_bounds(), _store.obstacles, PILE_SEED)
	_hands.pack_stand = _store.pack_stand
	_store.pack_stand.stock_from(_pile)
	print("Pile %s: %d cards in %d ms" % ["built" if saved.is_empty() else "loaded", CardDatabase.card_count(),
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
	_build_saving_icon()
	if not _falling.is_empty():
		_land_falling()
	_hang_wall_art(false)
	if _finished and not ENDING_RETURN_MESSAGE.is_empty():
		_show_return_message()
	_hands.shown_card_changed.connect(_on_shown_card_changed)
	_hands.held_pack_changed.connect(func(_code: String) -> void: _on_shown_card_changed(null, false))
	_hands.hint_changed.connect(func(text: String) -> void: _hint.text = text)
	_hands.rare_card_found.connect(func() -> void: add_child(RareCardNote.new()))
	_on_shown_card_changed(null, false)
	Progression.mana_changed.connect(func(_mana: int) -> void: _update_stats())
	Progression.unlocked.connect(func(_colour: int, _step: int) -> void: _update_stats())
	Progression.sorceries_changed.connect(_update_stats)
	_update_stats()
	_achievement.text = ""
	Achievements.unlocked.connect(_on_achievement_unlocked)
	var radio_menu := RadioMenu.new()
	add_child(radio_menu)
	_hands.radio_used.connect(radio_menu.open)
	Radio.enter_shop(_organized_share())
	Radio.song_unlocked.connect(func(index: int) -> void:
		_show_notice("New on the radio: %s" % Radio.songs[index].title))
	Settings.changed.connect(_apply_brightness.unbind(1))
	_apply_brightness()


func _exit_tree() -> void:
	Radio.leave_shop()
	if Saves.shop == self:
		Saves.shop = null


## Everything in the shop worth saving (see ShopSave).
func capture_save() -> Dictionary:
	return ShopSave.capture(_pile, _hands, $Player, _day, _falling)


## The shop as it is now, quickly, for Saves to finish off the main thread.
func snapshot_save() -> Dictionary:
	return ShopSave.snapshot(_pile, _hands, $Player, _day, _falling)


func _shelves() -> Array:
	return _store.find_children("*", "ShelfUnit", false, false)


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
	_hint.text = ENDING_RETURN_MESSAGE


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
		_hang_wall_art(true)
		if not _finished and is_finished(_pile.binders, _shelves(), _store.cabinets):
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
	var text := "Cards Organized: %d/%d\nMana: %d" % [
		cards_organized(_pile.binders, _store.cabinets), CardDatabase.card_count(), Progression.mana]
	for line in sorcery_lines():
		text += "\n" + line
	if OS.is_debug_build():
		var debug := "%d fps · %d draw calls" % [
			Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]
		if not CardDatabase.is_real_data():
			debug += "\nPlaceholder cards: run tools/import_scryfall.py for Khans of Tarkir"
		text = debug + "\n" + text
	_status.text = text
	Radio.set_progress(_organized_share())


## Cards Organized as a share of every card, for the radio's unlocks.
func _organized_share() -> float:
	return float(cards_organized(_pile.binders, _store.cabinets)) / maxf(1.0, CardDatabase.card_count())


## The game is finished when every card is locked into its own pocket,
## every binder stands in its own shelf space and every rare card is on
## display.
static func is_finished(binders: Array[Binder], shelves: Array, cabinets: Array = []) -> bool:
	for cabinet: DisplayCabinet in cabinets:
		if not cabinet.is_complete():
			return false
	for binder in binders:
		if not binder.contents.is_complete():
			return false
	for shelf: ShelfUnit in shelves:
		for space in shelf.spaces.size():
			if shelf.spaces[space] != null and (shelf.shelved[space] == null or shelf.shelved[space].binder != shelf.spaces[space]):
				return false
	return not binders.is_empty()


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


## "Achievement: Tithe" in the top right for a few seconds. A newer one
## takes its place.
func _on_achievement_unlocked(index: int) -> void:
	_show_notice("Achievement: %s" % Achievements.card_name(index))


## A line in the top right for a few seconds (an achievement, a new song on
## the radio). A newer one takes its place.
func _show_notice(text: String) -> void:
	_achievement.text = text
	_achievement.modulate.a = 1.0
	if _achievement_tween != null:
		_achievement_tween.kill()
	_achievement_tween = create_tween()
	_achievement_tween.tween_interval(ACHIEVEMENT_SHOWN)
	_achievement_tween.tween_property(_achievement, "modulate:a", 0.0, ACHIEVEMENT_FADE)


func _on_shown_card_changed(card: CardData, set_only: bool) -> void:
	if _hands.held_pack != null:
		_held.text = pack_details(_hands.held_pack.set_code)
	elif card == null:
		_held.text = ""
	else:
		_held.text = set_details(card) if set_only else card_details(card)


## A booster pack in hand: its set's name, then what it is.
static func pack_details(code: String) -> String:
	return "%s\nBooster Pack" % CardDatabase.get_set(code).name


## All you know of a card from its set (Enlightened Tutor): the set's name,
## then its code with the number still unknown, "KTK #???".
static func set_details(card: CardData) -> String:
	var set_data := CardDatabase.get_set(card.set_code)
	return "%s\n%s #???" % [set_data.name, set_data.code]


## A card's details as shown in the corner: name, set, number and rarity.
static func card_details(card: CardData) -> String:
	var set_data := CardDatabase.get_set(card.set_code)
	return "%s\n%s\n%s #%s/%s\n%s" % [
		card.name, set_data.name, set_data.code, set_data.number_text(card.collector_number),
		set_data.number_text(set_data.card_count), CardData.Rarity.keys()[card.rarity].capitalize()]
