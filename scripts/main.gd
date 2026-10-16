extends Node3D
## Main scene: the graybox store, the whole collection dumped on its floor
## (M2), and the player.

const PILE_SEED := 1993

@onready var _store: Node3D = $Store
@onready var _pile: PileWorld = $Pile
@onready var _picker: PilePicker = $Player/PilePicker
@onready var _status: Label = $HUD/Status
@onready var _held: Label = $HUD/Held

var _stats_timer := 0.0


func _ready() -> void:
	var started := Time.get_ticks_msec()
	_pile.build(_store.floor_bounds(), _store.obstacles, PILE_SEED)
	_pile.spawn_binders(_store.obstacles, PILE_SEED)
	print("Pile built: %d cards in %d ms" % [CardDatabase.card_count(), Time.get_ticks_msec() - started])
	_picker.pile = _pile
	_picker.held_card_changed.connect(_on_held_card_changed)
	_on_held_card_changed(null)
	_update_stats()


func _process(delta: float) -> void:
	_stats_timer += delta
	if _stats_timer >= 0.5:
		_stats_timer = 0.0
		_update_stats()


func _update_stats() -> void:
	_status.text = "%d fps · %d draw calls · %d cards on the floor\nWASD move · mouse look · Ctrl/C crouch · left-click pick up · right-click put down · Esc frees mouse" % [
		Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		_pile.card_count_on_floor()]


func _on_held_card_changed(card: CardData) -> void:
	if card == null:
		_held.text = ""
		return
	var set_data := CardDatabase.get_set(card.set_code)
	_held.text = "%s\n%s · %s #%d · %s\n%s" % [
		card.name, set_data.name, set_data.code, card.collector_number,
		CardData.Rarity.keys()[card.rarity].capitalize(), card.type_line]
