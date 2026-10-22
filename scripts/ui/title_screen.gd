class_name TitleScreen
extends Control
## The title screen and main menu: one scene in two states. It opens on the
## title and a PRESS ANY KEY TO START line; any key or mouse button brings
## up the menu under the title, which glides up to make room. Nothing here
## says what the game is: the Fan Content disclaimer is shown in the New
## Game intro instead (SceneFlow), and Credits stays greyed out until a game
## has been started, so the menu can't give it away. Continue and Load Game
## stay greyed out until there are saves (M8).

enum State { TITLE, MENU }

const TITLE_FADE := 0.8
const MENU_FADE := 0.6
## One breath of the PRESS ANY KEY TO START line, dim to bright and back.
const PROMPT_PULSE := 2.4
const PROMPT_DIM := 0.35

var state := State.TITLE
## The menu's buttons by label, for the tests.
var buttons := {}

var _title: Label
var _menu_room: Control
var _menu: VBoxContainer
var _prompt: Label
var _prompt_tween: Tween


func _ready() -> void:
	# Coming back from the shop (Quit to Menu, or the credits after the
	# ending) lands on the menu.
	var straight_to_menu := SceneFlow.take_menu_request()
	var roll_credits := SceneFlow.take_credits_request()
	straight_to_menu = straight_to_menu or roll_credits
	if not straight_to_menu and SceneFlow.should_skip_title():
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
	_menu_room.custom_minimum_size = Vector2(MenuStyle.BUTTON_SIZE.x, 0)
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
	_add_button("Achievements").pressed.connect(_open.bind(AchievementsScreen.make))
	_add_button("Settings").pressed.connect(_open.bind(SettingsScreen.new))
	_add_button("Credits", SceneFlow.has_started()).pressed.connect(_open.bind(CreditsRoll.new))
	_add_button("Exit").pressed.connect(SceneFlow.quit)
	_menu.visible = false
	_add_prompt()
	if straight_to_menu:
		show_menu(true)
	if roll_credits:
		_open(CreditsRoll.new)
	else:
		_title.modulate.a = 0.0
		create_tween().tween_property(_title, "modulate:a", 1.0, TITLE_FADE)


func _add_button(text: String, enabled := true) -> Button:
	var button := MenuStyle.menu_button(text, enabled)
	_menu.add_child(button)
	buttons[text] = button
	return button


## PRESS ANY KEY TO START near the bottom.
func _add_prompt() -> void:
	_prompt = MenuStyle.heading("PRESS ANY KEY TO START", 22)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.offset_bottom = -64
	add_child(_prompt)
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(_prompt, "modulate:a", PROMPT_DIM, PROMPT_PULSE / 2).set_trans(Tween.TRANS_SINE)
	_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, PROMPT_PULSE / 2).set_trans(Tween.TRANS_SINE)


func _input(event: InputEvent) -> void:
	if state == State.TITLE and is_start_press(event):
		get_viewport().set_input_as_handled()
		show_menu()


## Any key or mouse button (or gamepad button) leaves the title; moving the
## mouse doesn't.
static func is_start_press(event: InputEvent) -> bool:
	if event is InputEventKey or event is InputEventJoypadButton:
		return event.pressed and not event.is_echo()
	if event is InputEventMouseButton:
		return event.pressed
	return false


## Fades the prompt out and the menu in, or with `instant` puts it straight
## there.
func show_menu(instant := false) -> void:
	if state == State.MENU:
		return
	state = State.MENU
	_prompt_tween.kill()
	_menu.visible = true
	if instant:
		_prompt.modulate.a = 0.0
		_menu_room.custom_minimum_size.y = _menu.get_combined_minimum_size().y + 4
		_menu.modulate.a = 1.0
		return
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_prompt, "modulate:a", 0.0, MENU_FADE)
	tween.tween_property(_menu_room, "custom_minimum_size:y", _menu.get_combined_minimum_size().y + 4, MENU_FADE)
	tween.tween_property(_menu, "modulate:a", 1.0, MENU_FADE)


## Opens one of the menu's pages over it.
func _open(make: Callable) -> void:
	add_child(make.call())
