class_name PauseMenu
extends CanvasLayer
## The pause menu. Esc (Controls.PAUSE) stops the game and frees the mouse;
## Esc again, or Resume, goes back in. Losing the window's focus (alt-tab)
## pauses too, unless another menu (upgrades) already has the game stopped,
## so the mouse is never left loose in the game.
##
## Resume, Save/Load (greyed out until saves exist, M8), Achievements and
## Settings (the same pages as the main menu's), and Exit Game: Quit to
## Menu, Quit to Desktop or Back. Either quit then asks "Save before
## quitting?": Save And Quit saves first (SceneFlow.save_game(), a hook
## until M8), Quit Without Saving never does. Esc steps back one question.

## Set by the main scene; the developer time-of-day buttons drive it.
var day_cycle: DayCycle
## Each step's buttons by label, for the tests and for focus.
var buttons := {}
var exit_buttons := {}
var save_buttons := {}

var _menu: VBoxContainer
var _exit_question: VBoxContainer
var _save_question: VBoxContainer
## Where the chosen quit goes once the save question is answered:
## SceneFlow.to_main_menu or SceneFlow.quit.
var _quit_to: Callable


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
	_add_button(_menu, buttons, "Achievements").pressed.connect(_open.bind("Achievements", AchievementsScreen.make))
	_add_button(_menu, buttons, "Settings").pressed.connect(_open.bind("Settings", func() -> MenuScreen: return MenuScreen.new("Settings")))
	_add_button(_menu, buttons, "Exit Game").pressed.connect(_ask_to_exit)
	if OS.is_debug_build():
		_add_time_buttons(_menu)
	_exit_question = MenuStyle.centred_column(12)
	backdrop.add_child(_exit_question)
	_add_button(_exit_question, exit_buttons, "Quit to Menu").pressed.connect(_ask_to_save.bind(SceneFlow.to_main_menu, "Quit to Menu"))
	_add_button(_exit_question, exit_buttons, "Quit to Desktop").pressed.connect(_ask_to_save.bind(SceneFlow.quit, "Quit to Desktop"))
	_add_button(_exit_question, exit_buttons, "Back").pressed.connect(_back_from_exit)
	_save_question = MenuStyle.centred_column(12)
	backdrop.add_child(_save_question)
	var question := MenuStyle.heading("Save before quitting?", 36)
	question.custom_minimum_size.y = 80
	_save_question.add_child(question)
	_add_button(_save_question, save_buttons, "Save And Quit").pressed.connect(_quit.bind(true))
	_add_button(_save_question, save_buttons, "Quit Without Saving").pressed.connect(_quit.bind(false))
	_show_menu()
	visible = false


func _add_button(column: VBoxContainer, found: Dictionary, text: String, enabled := true) -> Button:
	var button := MenuStyle.menu_button(text, enabled)
	column.add_child(button)
	found[text] = button
	return button


## Developer only: jump straight to noon or midnight to check the lighting,
## or play the ending without filing every card.
func _add_time_buttons(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size.y = 80
	column.add_child(row)
	for entry in [["Set Noon", _set_hour.bind(12.0)], ["Set Midnight", _set_hour.bind(0.0)], ["Play Ending", SceneFlow.play_ending]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(142, 40)
		button.size_flags_vertical = Control.SIZE_SHRINK_END
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(entry[1])
		row.add_child(button)


func _set_hour(hour: float) -> void:
	if day_cycle != null:
		day_cycle.set_hour(hour)


func _unhandled_input(event: InputEvent) -> void:
	if SceneFlow.is_busy():
		return
	if event.is_action_pressed(Controls.PAUSE):
		if _save_question.visible:
			_back_from_save()
		elif _exit_question.visible:
			_back_from_exit()
		elif visible:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()
	elif visible and MenuStyle.wants_focus(_menu, event):
		get_viewport().set_input_as_handled()
		_first_button().grab_focus()


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


## True while the Exit Game question (Quit to Menu, Quit to Desktop, Back)
## is showing.
func is_asking_to_exit() -> bool:
	return _exit_question.visible


## True while "Save before quitting?" is showing.
func is_asking_to_save() -> bool:
	return _save_question.visible


func _ask_to_exit() -> void:
	_show(_exit_question, buttons["Exit Game"], exit_buttons["Quit to Menu"])


func _back_from_exit() -> void:
	_show(_menu, exit_buttons["Back"], buttons["Exit Game"])


func _ask_to_save(quit_to: Callable, label: String) -> void:
	_quit_to = quit_to
	_show(_save_question, exit_buttons[label], save_buttons["Save And Quit"])


func _back_from_save() -> void:
	var label := "Quit to Menu" if _quit_to == SceneFlow.to_main_menu else "Quit to Desktop"
	_show(_exit_question, null, exit_buttons[label], true)


## Save And Quit saves first; Quit Without Saving never does, even once
## saving exists.
func _quit(save: bool) -> void:
	if save:
		SceneFlow.save_game()
	_quit_to.call()


func _show_menu() -> void:
	_show(_menu, null, null)


## Shows one step of the menu. Focus follows the keyboard: if `from` had it
## (or `keep_focus`), `to` takes it; otherwise nothing is highlighted. A
## click focuses a button with its outline hidden, which doesn't count.
func _show(column: VBoxContainer, from: Button, to: Button, keep_focus := false) -> void:
	var had_focus := keep_focus or (from != null and from.has_focus(true))
	for step in [_menu, _exit_question, _save_question]:
		step.visible = step == column
	get_viewport().gui_release_focus()
	if had_focus and to != null:
		to.grab_focus()


func _first_button() -> Button:
	if _save_question.visible:
		return save_buttons["Save And Quit"]
	if _exit_question.visible:
		return exit_buttons["Quit to Menu"]
	return buttons["Resume"]


## Opens the Achievements or Settings page over the menu; Back or Esc
## returns to it, still paused.
func _open(title: String, make: Callable) -> void:
	var button: Button = buttons[title]
	var had_focus := button.has_focus(true)
	get_viewport().gui_release_focus()
	var page: MenuScreen = make.call()
	page.closed.connect(func() -> void:
		if had_focus:
			button.grab_focus())
	add_child(page)
