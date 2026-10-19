extends Node3D
## Main scene: the graybox store, the whole collection and every binder
## dumped on its floor, and the player.

const PILE_SEED := 1993
## Sorceries in key order, each with the action that casts it. Only learned
## ones show, under the Mana total.
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

var _stats_timer := 0.0


func _ready() -> void:
	var started := Time.get_ticks_msec()
	_pile.build(_store.floor_bounds(), _store.obstacles, PILE_SEED)
	_pile.spawn_binders(PILE_SEED)
	print("Pile built: %d cards in %d ms" % [CardDatabase.card_count(), Time.get_ticks_msec() - started])
	_hands.pile = _pile
	_hands.shown_card_changed.connect(_on_shown_card_changed)
	_hands.hint_changed.connect(func(text: String) -> void: _hint.text = text)
	_on_shown_card_changed(null, false)
	Progression.mana_changed.connect(func(_mana: int) -> void: _update_stats())
	Progression.unlocked.connect(func(_colour: int, _step: int) -> void: _update_stats())
	Progression.sorceries_changed.connect(_update_stats)
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


## Cards locked into their own pockets, across every binder.
static func cards_organized(binders: Array[Binder]) -> int:
	var count := 0
	for binder in binders:
		count += binder.contents.locked_count
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


func _on_shown_card_changed(card: CardData, set_only: bool) -> void:
	if card == null:
		_held.text = ""
	else:
		_held.text = set_details(card) if set_only else card_details(card)


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
