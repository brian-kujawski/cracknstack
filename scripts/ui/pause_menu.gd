class_name PauseMenu
extends CanvasLayer
## The pause menu. Esc (Controls.PAUSE) stops the game and frees the mouse;
## Esc again, or Resume, goes back in. Losing the window's focus (alt-tab)
## pauses too, unless another menu (upgrades) already has the game stopped,
## so the mouse is never left loose in the game.
##
## Resume, Save/Load (the list of saves, with Save on each slot),
## Achievements and Settings (the same pages as the main menu's), and Exit
## Game: Quit to Menu, Quit to Desktop or Back. Either quit then asks "Save
## before quitting?": Save And Quit writes the autosave first
## (SceneFlow.save_game()), Quit Without Saving never saves. Closing the
## window counts as Quit Without Saving. Esc steps back one question.

## The debug faces button's label for each NearFaces.DebugView.
const FACE_VIEWS := ["Near Faces", "Far Faces Only", "Show Late Faces"]

## Set by the main scene; the developer time-of-day buttons drive it.
var day_cycle: DayCycle
## Each step's buttons by label, for the tests.
var buttons := {}
var exit_buttons := {}
var save_buttons := {}

var _menu: VBoxContainer
var _exit_question: VBoxContainer
var _save_question: VBoxContainer
var _menu_panel: PanelContainer
var _exit_panel: PanelContainer
var _save_panel: PanelContainer
## The developer buttons (debug builds only), shown with the first step.
var _debug_row: HBoxContainer
## Where the chosen quit goes once the save question is answered:
## SceneFlow.to_main_menu or SceneFlow.quit.
var _quit_to: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	# The backdrop takes every click, so nothing reaches the game underneath.
	var backdrop := MenuStyle.backdrop()
	add_child(backdrop)
	_menu_panel = MenuStyle.framed_column(14, "Paused")
	backdrop.add_child(_menu_panel)
	_menu = _menu_panel.get_node("Column")
	var title := MenuStyle.heading("Paused")
	title.custom_minimum_size.y = 96
	_menu.add_child(title)
	# Fires when the click comes back up, so neither half of it reaches the game.
	_add_button(_menu, buttons, "Resume").pressed.connect(resume)
	_add_button(_menu, buttons, "Save/Load").pressed.connect(_open.bind(SaveSlotsScreen.new.bind(true)))
	_add_button(_menu, buttons, "Achievements").pressed.connect(_open.bind(AchievementsScreen.make))
	_add_button(_menu, buttons, "Settings").pressed.connect(_open.bind(SettingsScreen.new))
	_add_button(_menu, buttons, "Exit Game").pressed.connect(_ask_to_exit)
	if OS.is_debug_build():
		_add_time_buttons(backdrop)
	_exit_panel = MenuStyle.framed_column(14, "Exit Game")
	backdrop.add_child(_exit_panel)
	_exit_question = _exit_panel.get_node("Column")
	# No text on this step, only its three buttons (user, 2026-10-21).
	_add_button(_exit_question, exit_buttons, "Quit to Menu").pressed.connect(_ask_to_save.bind(SceneFlow.to_main_menu, "Quit to Menu"))
	_add_button(_exit_question, exit_buttons, "Quit to Desktop").pressed.connect(_ask_to_save.bind(SceneFlow.quit, "Quit to Desktop"))
	_add_button(_exit_question, exit_buttons, "Back").pressed.connect(_back_from_exit)
	_save_panel = MenuStyle.framed_column(14, "Save before quitting?")
	backdrop.add_child(_save_panel)
	_save_question = _save_panel.get_node("Column")
	var question := MenuStyle.question("Save before quitting?")
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
## play the ending without filing every card, get a booster box or a bulk
## box in front of you (until there's buying), or switch the floor between
## near faces as normal, far faces only and late near faces tinted red
## (NearFaces.DebugView), to compare them in play.
## They sit in a strip along the bottom of the screen, outside the menu's
## frame, so the frame is the same size as in a release build.
func _add_time_buttons(backdrop: Control) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_bottom = -40
	backdrop.add_child(row)
	_debug_row = row
	for entry in [["Set Noon", _set_hour.bind(12.0)], ["Set Midnight", _set_hour.bind(0.0)], ["Play Ending", SceneFlow.play_ending]]:
		_add_debug_button(row, entry[0]).pressed.connect(entry[1])
	# Product until buying exists (card-copies-plan.md): a booster box or a
	# bulk box on the floor in front of you.
	for entry in [["Booster Box", "debug_booster_box"], ["Bulk Box", "debug_bulk_box"]]:
		var method: String = entry[1]
		_add_debug_button(row, entry[0]).pressed.connect(func() -> void:
			if Saves.shop != null:
				Saves.shop.call(method)
				resume())
	_add_debug_button(row, "+$100").pressed.connect(func() -> void: Progression.earn_money(10000))
	_add_debug_button(row, "Level +1").pressed.connect(Progression.debug_level_up)
	var faces := _add_debug_button(row, FACE_VIEWS[NearFaces.debug_view])
	faces.pressed.connect(func() -> void:
		NearFaces.debug_view = (NearFaces.debug_view + 1) % FACE_VIEWS.size() as NearFaces.DebugView
		faces.text = FACE_VIEWS[NearFaces.debug_view])


func _add_debug_button(row: HBoxContainer, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(142, 40)
	button.size_flags_vertical = Control.SIZE_SHRINK_END
	button.add_theme_font_size_override("font_size", 18)
	row.add_child(button)
	return button


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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## True while the Exit Game question (Quit to Menu, Quit to Desktop, Back)
## is showing.
func is_asking_to_exit() -> bool:
	return _exit_question.visible


## True while "Save before quitting?" is showing.
func is_asking_to_save() -> bool:
	return _save_question.visible


func _ask_to_exit() -> void:
	_show(_exit_question)


func _back_from_exit() -> void:
	_show(_menu)


func _ask_to_save(quit_to: Callable, label: String) -> void:
	_quit_to = quit_to
	_show(_save_question)


func _back_from_save() -> void:
	_show(_exit_question)


## Save And Quit saves first; Quit Without Saving never does, even once
## saving exists.
func _quit(save: bool) -> void:
	if save:
		SceneFlow.save_game()
	_quit_to.call()


func _show_menu() -> void:
	_show(_menu)


## Shows one step of the menu.
func _show(column: VBoxContainer) -> void:
	for step in [_menu, _exit_question, _save_question]:
		step.visible = step == column
		# Each step sits in its own stone panel.
		step.get_parent().visible = step == column
	if _debug_row != null:
		_debug_row.visible = column == _menu


## Opens the Achievements or Settings page over the menu; Back or Esc
## returns to it, still paused.
func _open(make: Callable) -> void:
	add_child(make.call())
