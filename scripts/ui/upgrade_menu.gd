class_name UpgradeMenu
extends CanvasLayer
## The upgrade menu: Tab (Controls.UPGRADES) stops the game and shows every
## unlock, one column per colour in buying order. Only each colour's next
## unlock can be bought. Tab or Esc goes back in. A stand-in until the shop
## moves to the front counter; nothing bought does anything yet.

const BACKDROP := Color(0.07, 0.05, 0.04, 0.92)
const COLOUR_TINTS := [
	Color(0.95, 0.92, 0.8), Color(0.45, 0.65, 1.0), Color(0.7, 0.55, 0.8), Color(1.0, 0.45, 0.35), Color(0.45, 0.85, 0.45)]

var _mana_label: Label
## _buttons[colour][step]
var _buttons: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 9
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 24)
	backdrop.add_child(column)
	var title := Label.new()
	title.text = "UPGRADES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	column.add_child(title)
	_mana_label = Label.new()
	_mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mana_label.add_theme_font_size_override("font_size", 24)
	column.add_child(_mana_label)
	var colours := HBoxContainer.new()
	colours.add_theme_constant_override("separation", 16)
	column.add_child(colours)
	for colour in Progression.COLOURS.size():
		colours.add_child(_build_colour(colour))
	Progression.mana_changed.connect(func(_mana: int) -> void: refresh())
	Progression.unlocked.connect(func(_colour: int, _step: int) -> void: refresh())
	refresh()
	visible = false


func _build_colour(colour: int) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	var header := Label.new()
	header.text = Progression.COLOURS[colour].name
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", COLOUR_TINTS[colour])
	list.add_child(header)
	var buttons: Array[Button] = []
	for step in Progression.COLOURS[colour].steps.size():
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(220, 60)
		button.pressed.connect(func() -> void: Progression.buy(colour, step))
		list.add_child(button)
		buttons.append(button)
	_buttons.append(buttons)
	return list


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Controls.UPGRADES) or (visible and event.is_action_pressed(Controls.PAUSE)):
		if visible:
			close()
		elif not get_tree().paused:
			open()
		else:
			return
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


func open() -> void:
	refresh()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Redraws the Mana total and every button: bought, buyable or not yet.
func refresh() -> void:
	_mana_label.text = "Mana: %d" % Progression.mana
	for colour in _buttons.size():
		for step in _buttons[colour].size():
			var button: Button = _buttons[colour][step]
			var unlock := Progression.step_name(colour, step)
			if Progression.is_bought(colour, step):
				button.text = "%s\nOwned" % unlock
				button.disabled = true
				button.add_theme_color_override("font_disabled_color", COLOUR_TINTS[colour])
			else:
				button.remove_theme_color_override("font_disabled_color")
				button.text = "%s\n%d Mana" % [unlock, Progression.price(step)]
				button.disabled = not Progression.can_buy(colour, step)
