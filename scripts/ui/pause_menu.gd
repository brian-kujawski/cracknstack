class_name PauseMenu
extends CanvasLayer
## The pause screen. Esc (Controls.PAUSE) stops the game and frees the mouse;
## Esc again, or the Continue button, goes back in. Losing the window's focus
## (alt-tab) pauses too, unless another menu (upgrades) already has the game
## stopped, so the mouse is never left loose in the game. This is where the
## in-game menu (M4b) will grow from.

const BACKDROP := Color(0.07, 0.05, 0.04, 0.92)


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
	visible = false


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
