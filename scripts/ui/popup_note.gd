class_name PopupNote
extends CanvasLayer
## A short note in a panel over the game, with an OK button. It stops the
## game and frees the mouse; OK (or Esc) closes it and goes back in. Set
## `text` before adding it to the tree.

const WIDTH := 560

var text := ""
var ok_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11
	var backdrop := MenuStyle.backdrop(Color(UiStyle.BORDER, 0.5))
	add_child(backdrop)
	# A reading plaque in a stone frame (bible §6.1), dark ink on cream.
	var panel := MenuStyle.framed_column(24, "note", Vector2(44, 32), true)
	backdrop.add_child(panel)
	var column: VBoxContainer = panel.get_node("Column")
	var label := UiStyle.label(text, UiStyle.text_font(), UiStyle.BODY, UiStyle.INK)
	label.name = "Text"
	label.custom_minimum_size.x = WIDTH
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	ok_button = MenuStyle.menu_button("OK")
	ok_button.custom_minimum_size.x = 160
	ok_button.pressed.connect(close)
	column.add_child(ok_button)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Controls.PAUSE):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if is_queued_for_deletion():
		return
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
