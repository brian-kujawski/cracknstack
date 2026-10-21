extends Control
## The title screen and main menu: one scene in two states. It opens on the
## title, a PRESS ANY KEY TO START line and the Fan Content disclaimer; any
## key or mouse button brings up the menu under the title, which glides up
## to make room. The disclaimer stays put the whole time. Continue and Load Game stay greyed out until
## there are saves (M8).

enum State { TITLE, MENU }

const TITLE_FADE := 0.8
const MENU_FADE := 0.6
## One breath of the PRESS ANY KEY TO START line, dim to bright and back.
const PROMPT_PULSE := 2.4
const PROMPT_DIM := 0.35

var state := State.TITLE
## The menu's buttons by label, for the tests and for focus.
var buttons := {}

var _title: Label
var _menu_room: Control
var _menu: VBoxContainer
var _prompt: Label
var _prompt_tween: Tween


func _ready() -> void:
	if SceneFlow.should_skip_title():
		get_tree().change_scene_to_file.call_deferred(SceneFlow.SHOP_SCENE)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuStyle.backdrop(MenuStyle.TITLE_BACKDROP))
	var column := MenuStyle.centred_column(48)
	add_child(column)
	_title = MenuStyle.heading("PICKUP", 96)
	column.add_child(_title)
	# The menu opens out under the title: its room grows from nothing, so
	# the title glides up as the buttons fade in rather than jumping.
	_menu_room = Control.new()
	_menu_room.clip_contents = true
	# A little wider than the buttons, so the keyboard focus outline isn't cut off.
	_menu_room.custom_minimum_size = Vector2(MenuStyle.BUTTON_SIZE.x + 8, 0)
	_menu_room.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_menu_room)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_menu.offset_top = 2
	_menu.modulate.a = 0.0
	_menu_room.add_child(_menu)
	_add_button("Continue", false)
	_add_button("New Game").pressed.connect(SceneFlow.new_game)
	_add_button("Load Game", false)
	_add_button("Achievements").pressed.connect(_open.bind(func() -> MenuScreen: return MenuScreen.new("Achievements"), "Achievements"))
	_add_button("Settings").pressed.connect(_open.bind(func() -> MenuScreen: return MenuScreen.new("Settings"), "Settings"))
	_add_button("Credits").pressed.connect(_open.bind(MenuScreen.credits, "Credits"))
	_add_button("Exit").pressed.connect(SceneFlow.quit)
	_menu.visible = false
	_add_footer()
	_title.modulate.a = 0.0
	create_tween().tween_property(_title, "modulate:a", 1.0, TITLE_FADE)


func _add_button(text: String, enabled := true) -> Button:
	var button := MenuStyle.menu_button(text, enabled)
	_menu.add_child(button)
	buttons[text] = button
	return button


## PRESS ANY KEY TO START near the bottom, and the disclaimer under it.
func _add_footer() -> void:
	var footer := VBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer.offset_bottom = -24
	footer.add_theme_constant_override("separation", 32)
	add_child(footer)
	_prompt = MenuStyle.heading("PRESS ANY KEY TO START", 22)
	footer.add_child(_prompt)
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(_prompt, "modulate:a", PROMPT_DIM, PROMPT_PULSE / 2).set_trans(Tween.TRANS_SINE)
	_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, PROMPT_PULSE / 2).set_trans(Tween.TRANS_SINE)
	var disclaimer := Label.new()
	disclaimer.text = Credits.DISCLAIMER
	disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	disclaimer.custom_minimum_size.x = 900
	disclaimer.modulate = Color(1, 1, 1, 0.6)
	disclaimer.add_theme_font_size_override("font_size", MenuStyle.SMALL_FONT_SIZE)
	footer.add_child(disclaimer)


func _input(event: InputEvent) -> void:
	if state == State.TITLE and is_start_press(event):
		get_viewport().set_input_as_handled()
		show_menu(event is InputEventKey)


func _unhandled_input(event: InputEvent) -> void:
	if state == State.MENU and MenuStyle.wants_focus(self, event):
		get_viewport().set_input_as_handled()
		buttons["New Game"].grab_focus()


## Any key or mouse button (or gamepad button) leaves the title; moving the
## mouse doesn't.
static func is_start_press(event: InputEvent) -> bool:
	if event is InputEventKey or event is InputEventJoypadButton:
		return event.pressed and not event.is_echo()
	if event is InputEventMouseButton:
		return event.pressed
	return false


## Fades the prompt out and the menu in. Coming from the keyboard, New Game
## is focused so Enter starts at once.
func show_menu(from_keyboard := false) -> void:
	if state == State.MENU:
		return
	state = State.MENU
	_prompt_tween.kill()
	_menu.visible = true
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_prompt, "modulate:a", 0.0, MENU_FADE)
	tween.tween_property(_menu_room, "custom_minimum_size:y", _menu.get_combined_minimum_size().y + 4, MENU_FADE)
	tween.tween_property(_menu, "modulate:a", 1.0, MENU_FADE)
	if from_keyboard:
		buttons["New Game"].grab_focus()


## Opens one of the menu's pages over it, and hands focus back to its
## button when it closes.
func _open(make: Callable, label: String) -> void:
	var page: MenuScreen = make.call()
	var button: Button = buttons[label]
	var had_focus := button.has_focus()
	get_viewport().gui_release_focus()
	page.closed.connect(func() -> void:
		if had_focus:
			button.grab_focus())
	add_child(page)
