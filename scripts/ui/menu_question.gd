class_name MenuQuestion
extends Control
## A yes-or-back question over a menu page: a heading, an optional line of
## explanation, the answer button and Back. Esc is Back. Used before a step
## that loses something: overwriting a save, loading over the game you're
## playing, replacing the autosave with a New Game.

var buttons := {}


func _init(question: String, explanation: String, answer: String, answered: Callable) -> void:
	name = "MenuQuestion"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := MenuStyle.backdrop(MenuStyle.TITLE_BACKDROP)
	add_child(backdrop)
	var panel := MenuStyle.framed_column(14, question)
	backdrop.add_child(panel)
	var column: VBoxContainer = panel.get_node("Column")
	var heading := MenuStyle.question(question)
	heading.custom_minimum_size.y = 60 if not explanation.is_empty() else 80
	column.add_child(heading)
	if not explanation.is_empty():
		var line := MenuStyle.line(explanation)
		line.custom_minimum_size = Vector2(560, 60)
		column.add_child(line)
	for entry in [[answer, func() -> void:
			queue_free()
			answered.call()], ["Back", queue_free]]:
		var button := MenuStyle.menu_button(entry[0])
		button.pressed.connect(entry[1])
		column.add_child(button)
		buttons[entry[0]] = button


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Controls.PAUSE):
		get_viewport().set_input_as_handled()
		queue_free()
