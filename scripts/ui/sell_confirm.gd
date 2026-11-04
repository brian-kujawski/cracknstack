class_name SellConfirm
extends CanvasLayer
## Asks before a card your collection doesn't have yet is sold
## (Hands.sale_confirm_requested). It stops the game and frees the mouse.
## Sell sells it; Keep (or Esc) leaves it in your hand. The first time in a
## game it asks plainly; after that it also says where to turn it off
## (Settings "confirm_new_sales").

const QUESTION := "You haven't added this card to your collection yet. Are you sure you want to sell it?"
const TURN_OFF := " (This confirmation can be turned off in the Gameplay settings.)"
## Progression.has_note key: the plain wording has been shown.
const NOTE_KEY := "sell_confirm"
const WIDTH := 600

var text := ""
var sell_button: Button
var keep_button: Button
var _sell: Callable


## `sell` is called if the answer is Sell.
func _init(sell: Callable) -> void:
	_sell = sell
	text = QUESTION + (TURN_OFF if Progression.has_note(NOTE_KEY) else "")
	Progression.mark_note(NOTE_KEY)


func _ready() -> void:
	name = "SellConfirm"
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11
	var backdrop := MenuStyle.backdrop(Color(0, 0, 0, 0.45))
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = MenuStyle.TITLE_BACKDROP
	style.border_color = ShippingBox.BLUE.lightened(0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	backdrop.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)
	var label := Label.new()
	label.name = "Text"
	label.text = text
	label.custom_minimum_size.x = WIDTH
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", MenuStyle.BUTTON_FONT_SIZE)
	column.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	sell_button = MenuStyle.menu_button("Sell")
	sell_button.custom_minimum_size.x = 160
	sell_button.pressed.connect(answer.bind(true))
	row.add_child(sell_button)
	keep_button = MenuStyle.menu_button("Keep")
	keep_button.custom_minimum_size.x = 160
	keep_button.pressed.connect(answer.bind(false))
	row.add_child(keep_button)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Controls.PAUSE):
		get_viewport().set_input_as_handled()
		answer(false)


## Closes it, back into the game; with `sell`, the card is sold.
func answer(sell: bool) -> void:
	if is_queued_for_deletion():
		return
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
	if sell and _sell.is_valid():
		_sell.call()
