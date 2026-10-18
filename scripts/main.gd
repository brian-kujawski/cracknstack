extends Node3D
## Main scene: the graybox store, the whole collection and every binder
## dumped on its floor, and the player.

const PILE_SEED := 1993

@onready var _store: Node3D = $Store
@onready var _pile: PileWorld = $Pile
@onready var _hands: Hands = $Player/Hands
@onready var _status: Label = $HUD/Status
@onready var _held: Label = $HUD/Held
@onready var _hint: Label = $HUD/Hint

var _stats_timer := 0.0
var _credits: PanelContainer


func _ready() -> void:
	var started := Time.get_ticks_msec()
	_pile.build(_store.floor_bounds(), _store.obstacles, PILE_SEED)
	_pile.spawn_binders(PILE_SEED)
	print("Pile built: %d cards in %d ms" % [CardDatabase.card_count(), Time.get_ticks_msec() - started])
	_hands.pile = _pile
	_hands.held_changed.connect(_on_held_changed)
	_hands.hint_changed.connect(func(text: String) -> void: _hint.text = text)
	_on_held_changed(null, null)
	_build_credits()
	_update_stats()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Controls.CREDITS):
		_credits.visible = not _credits.visible


func _process(delta: float) -> void:
	_stats_timer += delta
	if _stats_timer >= 0.5:
		_stats_timer = 0.0
		_update_stats()


## Frame rate and draw calls are for us while testing: they show when running
## from the editor or a debug export, and are left out of release exports.
func _update_stats() -> void:
	var text := "%d cards on the floor · %s: credits" % [_pile.card_count_on_floor(), Controls.label(Controls.CREDITS)]
	if not CardDatabase.is_real_data():
		text += "\nPlaceholder cards: run tools/import_scryfall.py for Khans of Tarkir"
	if OS.is_debug_build():
		text = "%d fps · %d draw calls · %s" % [
			Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			text]
	_status.text = text


func _on_held_changed(card: CardData, binder: BinderRange) -> void:
	if binder != null:
		_held.text = "Carrying binder\n%s" % binder.label
		return
	if card == null:
		_held.text = ""
		return
	var set_data := CardDatabase.get_set(card.set_code)
	_held.text = "%s\n%s · %s #%d · %s\n%s" % [
		card.name, set_data.name, set_data.code, card.collector_number,
		CardData.Rarity.keys()[card.rarity].capitalize(), card.type_line]


## The credits (Controls.CREDITS): Fan Content disclaimer, data and art sources.
func _build_credits() -> void:
	_credits = PanelContainer.new()
	_credits.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_credits.custom_minimum_size = Vector2(760, 0)
	_credits.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_credits.grow_vertical = Control.GROW_DIRECTION_BOTH
	_credits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.05, 0.88)
	style.set_content_margin_all(24)
	style.set_corner_radius_all(6)
	_credits.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = Credits.text()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(712, 0)
	_credits.add_child(label)
	_credits.visible = false
	_hint.get_parent().add_child(_credits)
