class_name MenuScreen
extends Control
## A full-screen page opened from a menu (Achievements, Settings):
## the backdrop, then a stone-framed panel with a heading, whatever the
## page holds, and a Back button. Back
## or Esc closes it and hands control back to the menu that opened it, so the
## same pages work from the title screen and, later, the pause menu.

signal closed

## The page's own controls go in here, between the heading and Back.
var content: VBoxContainer
## The stone-framed panel the page sits in, and its frame (Settings lets the
## game show through its window).
var panel: PanelContainer
var panel_frame: UiStyle.Frame


func _init(title: String) -> void:
	name = title.capitalize().replace(" ", "")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuStyle.backdrop(MenuStyle.TITLE_BACKDROP))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 96)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	# The page is one stone-framed panel, as wide as what it holds.
	panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel_frame = UiStyle.frame(14.0, Vector2(48, 24), title)
	panel.add_theme_stylebox_override("panel", panel_frame)
	margin.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	panel.add_child(column)
	column.add_child(MenuStyle.heading(title))
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	column.add_child(content)
	var back := MenuStyle.menu_button("Back")
	back.pressed.connect(close)
	column.add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Controls.PAUSE):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()
