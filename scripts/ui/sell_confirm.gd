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
	var backdrop := MenuStyle.backdrop(Color(UiStyle.BORDER, 0.5))
	add_child(backdrop)
	var panel := MenuStyle.framed_column(24, "SellConfirm", Vector2(44, 32))
	backdrop.add_child(panel)
	var column: VBoxContainer = panel.get_node("Column")
	var label := UiStyle.label(text, UiStyle.text_font(), UiStyle.BODY)
	label.name = "Text"
	label.custom_minimum_size.x = WIDTH
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
