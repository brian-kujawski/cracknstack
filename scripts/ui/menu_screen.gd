class_name MenuScreen
extends Control
## A full-screen page opened from a menu (Achievements, Settings, Credits):
## the backdrop, a heading, whatever the page holds, and a Back button. Back
## or Esc closes it and hands control back to the menu that opened it, so the
## same pages work from the title screen and, later, the pause menu.

signal closed

## The page's own controls go in here, between the heading and Back.
var content: VBoxContainer
var _back: Button


func _init(title: String) -> void:
	name = title.capitalize().replace(" ", "")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuStyle.backdrop(MenuStyle.TITLE_BACKDROP))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	margin.add_child(column)
	column.add_child(MenuStyle.heading(title.to_upper(), 48))
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	_back = MenuStyle.menu_button("Back")
	_back.pressed.connect(close)
	column.add_child(_back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Controls.PAUSE):
		get_viewport().set_input_as_handled()
		close()
	elif MenuStyle.wants_focus(self, event):
		get_viewport().set_input_as_handled()
		_back.grab_focus()


func close() -> void:
	closed.emit()
	queue_free()


## The credits as plain scrolling text, until the credits roll (M4b step 3)
## replaces it.
static func credits() -> MenuScreen:
	var screen := MenuScreen.new("Credits")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.content.add_child(scroll)
	var text := Label.new()
	text.text = Credits.text()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(text)
	return screen
