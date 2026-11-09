class_name PopupNote
extends CanvasLayer
## A short note in a panel over the game, with an OK button. It stops the
## game and frees the mouse; OK (or Esc) closes it and goes back in. Set
## `text` (and `accent`, the panel's border) before adding it to the tree.

const WIDTH := 560

var text := ""
var accent := MenuStyle.ACCENT
var ok_button: Button


func _ready() -> void:
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
	style.border_color = accent
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
