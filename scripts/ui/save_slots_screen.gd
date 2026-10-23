class_name SaveSlotsScreen
extends MenuScreen
## The list of saves: the autosave and three slots, one row each with its
## name, when it was saved, play time and how far along it is. From the main
## menu it's Load Game (Load buttons only); from the pause menu it's
## Save/Load, with a Save button on each slot (not the autosave, which the
## game writes). Saving over a slot, or loading over the game you're
## playing, asks first. Saves from an older version are listed but can't be
## loaded.

const NAME_WIDTH := 200
const DETAILS_WIDTH := 640
const ROW_BUTTON := Vector2(150, 52)

## From the pause menu: saving is offered, and loading asks first.
var in_game := false
## For the tests: each slot's row, as {"details": Label, "save": Button
## (slots only, in game), "load": Button}.
var rows := {}


func _init(from_game := false) -> void:
	super("Save/Load" if from_game else "Load Game")
	in_game = from_game
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(list)
	for slot in Saves.SLOTS:
		list.add_child(_make_row(slot))
	_refresh()


func _make_row(slot: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var title := Label.new()
	title.text = Saves.SLOT_NAMES[slot]
	title.custom_minimum_size.x = NAME_WIDTH
	title.add_theme_font_size_override("font_size", MenuStyle.BUTTON_FONT_SIZE)
	row.add_child(title)
	var details := Label.new()
	details.custom_minimum_size.x = DETAILS_WIDTH
	details.add_theme_font_size_override("font_size", MenuStyle.BUTTON_FONT_SIZE)
	row.add_child(details)
	var found := {"details": details}
	if in_game:
		var save := _row_button("Save")
		save.visible = slot != Saves.AUTOSAVE
		save.pressed.connect(_ask_to_save.bind(slot))
		row.add_child(save)
		found["save"] = save
	var load := _row_button("Load")
	load.pressed.connect(_ask_to_load.bind(slot))
	row.add_child(load)
	found["load"] = load
	rows[slot] = found
	return row


func _row_button(text: String) -> Button:
	var button := MenuStyle.menu_button(text)
	button.custom_minimum_size = ROW_BUTTON
	return button


func _refresh() -> void:
	for slot in rows:
		rows[slot].details.text = Saves.describe(slot)
		rows[slot].load.disabled = Saves.status(slot) != SaveGame.Status.OK


func _ask_to_save(slot: String) -> void:
	if Saves.status(slot) == SaveGame.Status.EMPTY:
		save_to(slot)
	else:
		add_child(MenuQuestion.new("Save over %s?" % Saves.SLOT_NAMES[slot], "", "Save", save_to.bind(slot)))


func _ask_to_load(slot: String) -> void:
	if in_game:
		add_child(MenuQuestion.new("Load this save?", "Anything since your last save is lost.", "Load",
			SceneFlow.load_game.bind(slot)))
	else:
		SceneFlow.load_game(slot)


## Writes the game to a slot, now, and shows it in the list.
func save_to(slot: String) -> void:
	Saves.save(slot, true)
	_refresh()
