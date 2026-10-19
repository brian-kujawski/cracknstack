class_name PauseMenu
extends CanvasLayer
## The pause screen. Esc (Controls.PAUSE) stops the game and frees the mouse;
## Esc again, or the Continue button, goes back in. Losing the window's focus
## (alt-tab) pauses too, unless another menu (upgrades) already has the game
## stopped, so the mouse is never left loose in the game. This is where the
## in-game menu (M4b) will grow from.

const BACKDROP := Color(0.07, 0.05, 0.04, 0.92)

## Set by the main scene; the developer time-of-day buttons drive it.
var day_cycle: DayCycle


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	# The backdrop takes every click, so nothing reaches the game underneath.
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 36)
	backdrop.add_child(column)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	column.add_child(title)
	var resume_button := Button.new()
	resume_button.text = "Click to Continue"
	resume_button.focus_mode = Control.FOCUS_NONE
	resume_button.custom_minimum_size = Vector2(300, 56)
	resume_button.add_theme_font_size_override("font_size", 24)
	resume_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Fires when the click comes back up, so neither half of it reaches the game.
	resume_button.pressed.connect(resume)
	column.add_child(resume_button)
	if OS.is_debug_build():
		_add_time_buttons(column)
	visible = false


## Developer only: jump straight to noon or midnight to check the lighting.
func _add_time_buttons(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	for entry in [["Set Noon", 12.0], ["Set Midnight", 0.0]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(142, 40)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_set_hour.bind(entry[1]))
		row.add_child(button)


func _set_hour(hour: float) -> void:
	if day_cycle != null:
		day_cycle.set_hour(hour)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Controls.PAUSE):
		if visible:
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
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
