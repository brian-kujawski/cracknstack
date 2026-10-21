class_name PauseMenu
extends CanvasLayer
## The pause menu. Esc (Controls.PAUSE) stops the game and frees the mouse;
## Esc again, or Resume, goes back in. Losing the window's focus (alt-tab)
## pauses too, unless another menu (upgrades) already has the game stopped,
## so the mouse is never left loose in the game.
##
## Resume, Save/Load (greyed out until saves exist, M8), Achievements and
## Settings (the same pages as the main menu's), and Exit Game, which asks
## first because nothing is saved yet: Main Menu, Quit to Desktop or Back.

## Set by the main scene; the developer time-of-day buttons drive it.
var day_cycle: DayCycle
## The menu's buttons by label, and the exit question's, for the tests and
## for focus.
var buttons := {}
var exit_buttons := {}

var _menu: VBoxContainer
var _exit_question: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	# The backdrop takes every click, so nothing reaches the game underneath.
	var backdrop := MenuStyle.backdrop()
	add_child(backdrop)
	_menu = MenuStyle.centred_column(12)
	backdrop.add_child(_menu)
	var title := MenuStyle.heading("PAUSED")
	title.custom_minimum_size.y = 120
	_menu.add_child(title)
	# Fires when the click comes back up, so neither half of it reaches the game.
	_add_button(_menu, buttons, "Resume").pressed.connect(resume)
	_add_button(_menu, buttons, "Save/Load", false)
	_add_button(_menu, buttons, "Achievements").pressed.connect(_open.bind("Achievements"))
	_add_button(_menu, buttons, "Settings").pressed.connect(_open.bind("Settings"))
	_add_button(_menu, buttons, "Exit Game").pressed.connect(_ask_to_exit)
	if OS.is_debug_build():
		_add_time_buttons(_menu)
	_exit_question = MenuStyle.centred_column(12)
	_exit_question.visible = false
	backdrop.add_child(_exit_question)
	var question := MenuStyle.heading("EXIT GAME", 48)
	_exit_question.add_child(question)
	var warning := MenuStyle.heading("Progress isn't saved.", MenuStyle.BUTTON_FONT_SIZE)
	warning.custom_minimum_size.y = 72
	_exit_question.add_child(warning)
	_add_button(_exit_question, exit_buttons, "Main Menu").pressed.connect(SceneFlow.to_main_menu)
	_add_button(_exit_question, exit_buttons, "Quit to Desktop").pressed.connect(SceneFlow.quit)
	_add_button(_exit_question, exit_buttons, "Back").pressed.connect(_back_from_exit)
	visible = false


func _add_button(column: VBoxContainer, found: Dictionary, text: String, enabled := true) -> Button:
	var button := MenuStyle.menu_button(text, enabled)
	column.add_child(button)
	found[text] = button
	return button


## Developer only: jump straight to noon or midnight to check the lighting.
func _add_time_buttons(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size.y = 80
	column.add_child(row)
	for entry in [["Set Noon", 12.0], ["Set Midnight", 0.0]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(142, 40)
		button.size_flags_vertical = Control.SIZE_SHRINK_END
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_set_hour.bind(entry[1]))
		row.add_child(button)


func _set_hour(hour: float) -> void:
	if day_cycle != null:
		day_cycle.set_hour(hour)


func _unhandled_input(event: InputEvent) -> void:
	if SceneFlow.is_busy():
		return
	if event.is_action_pressed(Controls.PAUSE):
		if _exit_question.visible:
			_back_from_exit()
		elif visible:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()
	elif visible and MenuStyle.wants_focus(_menu, event):
		get_viewport().set_input_as_handled()
		(exit_buttons["Back"] if _exit_question.visible else buttons["Resume"]).grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not get_tree().paused and not "--benchmark" in OS.get_cmdline_user_args():
		pause()


func is_paused() -> bool:
	return visible


func pause() -> void:
	_show_menu()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	visible = false
	get_tree().paused = false
	get_viewport().gui_release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## True while the Exit Game question is showing.
func is_asking_to_exit() -> bool:
	return _exit_question.visible


func _ask_to_exit() -> void:
	var had_focus: bool = buttons["Exit Game"].has_focus()
	_menu.visible = false
	_exit_question.visible = true
	if had_focus:
		exit_buttons["Back"].grab_focus()
	else:
		get_viewport().gui_release_focus()


func _back_from_exit() -> void:
	var had_focus: bool = exit_buttons["Back"].has_focus()
	_show_menu()
	if had_focus:
		buttons["Exit Game"].grab_focus()


func _show_menu() -> void:
	_exit_question.visible = false
	_menu.visible = true
	get_viewport().gui_release_focus()


## Opens the Achievements or Settings page over the menu; Back or Esc
## returns to it, still paused.
func _open(title: String) -> void:
	var button: Button = buttons[title]
	var had_focus := button.has_focus()
	get_viewport().gui_release_focus()
	var page := MenuScreen.new(title)
	page.closed.connect(func() -> void:
		if had_focus:
			button.grab_focus())
	add_child(page)
