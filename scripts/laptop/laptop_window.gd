class_name LaptopWindow
extends Panel
## One window on the laptop's desktop: a raised grey frame, a navy title bar
## with its name and a close box, and its content below. Drag it by the
## title bar; clicking anywhere on it brings it to the front.

signal closed
signal focused

const TITLE_HEIGHT := 34
const PADDING := 8

var app := ""
var content: MarginContainer
var _title_bar: ColorRect
var _title: Label
var _dragging := false


func _init(app_id: String, title: String, window_size: Vector2) -> void:
	app = app_id
	name = "Window_" + app_id
	size = window_size
	custom_minimum_size = window_size
	add_theme_stylebox_override("panel", Win95.bevel(Win95.Look.RAISED))
	mouse_filter = Control.MOUSE_FILTER_STOP

	_title_bar = ColorRect.new()
	_title_bar.color = Win95.TITLE
	_title_bar.position = Vector2(PADDING / 2.0 + 2, PADDING / 2.0 + 2)
	_title_bar.size = Vector2(window_size.x - PADDING - 4, TITLE_HEIGHT)
	_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar.gui_input.connect(_on_title_input)
	add_child(_title_bar)
	_title = Win95.label(title, Win95.TITLE_FONT_SIZE, Win95.WHITE)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.position = Vector2(10, 2)
	_title.size = Vector2(_title_bar.size.x - 60, TITLE_HEIGHT - 4)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_constant_override("outline_size", 1)
	_title.add_theme_color_override("font_outline_color", Win95.WHITE)
	_title_bar.add_child(_title)
	var close_box := Win95.button("×", close, 0)
	close_box.name = "Close"
	close_box.custom_minimum_size = Vector2(32, 26)
	close_box.size = Vector2(32, 26)
	close_box.position = Vector2(_title_bar.size.x - 36, 4)
	close_box.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		close_box.add_theme_stylebox_override(state, Win95.bevel(
			Win95.Look.PRESSED if state.ends_with("pressed") else Win95.Look.RAISED, Win95.FACE, 0))
	_title_bar.add_child(close_box)

	content = MarginContainer.new()
	content.position = Vector2(PADDING + 2, TITLE_HEIGHT + PADDING + 4)
	content.size = window_size - Vector2(PADDING * 2 + 4, TITLE_HEIGHT + PADDING * 2 + 6)
	add_child(content)


func set_active(active: bool) -> void:
	_title_bar.color = Win95.TITLE if active else Win95.TITLE_INACTIVE


func close() -> void:
	closed.emit()
	queue_free()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		focused.emit()


func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			focused.emit()
	elif event is InputEventMouseMotion and _dragging:
		position += event.relative
		# Keep the title bar on the screen, so it can always be dragged back.
		var parent := get_parent_control()
		if parent != null:
			position.x = clampf(position.x, -size.x + 120, parent.size.x - 120)
			position.y = clampf(position.y, 0, parent.size.y - TITLE_HEIGHT - 8)
