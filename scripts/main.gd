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


func _ready() -> void:
	var started := Time.get_ticks_msec()
	_pile.build(_store.floor_bounds(), _store.obstacles, PILE_SEED)
	_pile.spawn_binders(PILE_SEED)
	print("Pile built: %d cards in %d ms" % [CardDatabase.card_count(), Time.get_ticks_msec() - started])
	_hands.pile = _pile
	var day := DayCycle.new()
	day.name = "DayCycle"
	add_child(day)
	day.setup($WorldEnvironment.environment, _store.window_lights, _store.curtain_material, _store.sky_material)
	_hands.shown_card_changed.connect(_on_shown_card_changed)
	_hands.hint_changed.connect(func(text: String) -> void: _hint.text = text)
	_on_shown_card_changed(null)
	Progression.mana_changed.connect(func(_mana: int) -> void: _update_stats())
	_update_stats()


func _process(delta: float) -> void:
	_stats_timer += delta
	if _stats_timer >= 0.5:
		_stats_timer = 0.0
		_update_stats()


## Frame rate, draw calls and the placeholder-data note are for us while
## testing: they show when running from the editor or a debug export, and are
## left out of release exports.
func _update_stats() -> void:
	var text := "Cards Organized: %d/%d\nMana: %d" % [
		cards_organized(_pile.binders), CardDatabase.card_count(), Progression.mana]
	if OS.is_debug_build():
		var debug := "%d fps · %d draw calls" % [
			Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]
		if not CardDatabase.is_real_data():
			debug += "\nPlaceholder cards: run tools/import_scryfall.py for Khans of Tarkir"
		text = debug + "\n" + text
	_status.text = text


## Cards locked into their own pockets, across every binder.
static func cards_organized(binders: Array[Binder]) -> int:
	var count := 0
	for binder in binders:
		count += binder.contents.locked_count
	return count


func _on_shown_card_changed(card: CardData) -> void:
	_held.text = "" if card == null else card_details(card)


## A card's details as shown in the corner: name, set, number and rarity.
static func card_details(card: CardData) -> String:
	var set_data := CardDatabase.get_set(card.set_code)
	return "%s\n%s\n%s #%s/%s\n%s" % [
		card.name, set_data.name, set_data.code, set_data.number_text(card.collector_number),
		set_data.number_text(set_data.card_count), CardData.Rarity.keys()[card.rarity].capitalize()]
