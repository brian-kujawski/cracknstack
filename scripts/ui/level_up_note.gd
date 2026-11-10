class_name LevelUpNote
extends CanvasLayer
## What a new level opened, in a panel over the game: "LEVEL UP", the level,
## then each ability's name and what it does, then the tools now on the
## laptop (Main.level_up_text has the same words as plain text). It stops
## the game and frees the mouse, and only its OK button closes it: Esc does
## nothing while it's up, so it can't be dismissed by accident.
##
## It waits, hidden, while anything else has the mouse (the pause menu, the
## laptop, another note, a fade), so several levels at once show one after
## another, each with its own OK. A note that comes up over it (the end of a
## build, a rare card) doesn't let the game go while this one is still up.

## Emitted once OK has been clicked and the game is running again.
signal closed

const WIDTH := 640
const ACCENT := HudStyle.GOLD_BRIGHT

var level := 1
var ok_button: Button
var panel: PanelContainer
## True once it has shown itself (and paused the game).
var showing := false


func _init(reached := 1) -> void:
	level = reached


func _ready() -> void:
	name = "LevelUpNote"
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11
	var backdrop := MenuStyle.backdrop(Color(0, 0, 0, 0.45))
	backdrop.name = "Backdrop"
	add_child(backdrop)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = MenuStyle.TITLE_BACKDROP
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(36)
	style.shadow_color = Color(0.925, 0.788, 0.416, 0.25)
	style.shadow_size = 24
	panel.add_theme_stylebox_override("panel", style)
	backdrop.add_child(panel)
	var column := VBoxContainer.new()
	column.name = "Lines"
	column.custom_minimum_size.x = WIDTH
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	_build_lines(column)
	visible = false
	_try_show()


## The kicker, the level, a rule, what it opened, and OK.
func _build_lines(column: VBoxContainer) -> void:
	var kicker := HudStyle.caption("LEVEL UP", 26)
	kicker.name = "Kicker"
	kicker.add_theme_color_override("font_color", HudStyle.GOLD_BRIGHT)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(kicker)
	var title := HudStyle.name_label("Level %d" % level, 84, Color(0.969, 0.89, 0.639))
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var abilities := Progression.abilities_at(level)
	var tools := tool_names(level)
	if not abilities.is_empty() or not tools.is_empty():
		column.add_child(_gap(12))
		column.add_child(HudStyle.rule())
	for row in abilities:
		column.add_child(_gap(18))
		var ability := HudStyle.name_label(row[3], 32, HudStyle.GOLD_TEXT)
		ability.name = "Ability"
		ability.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(ability)
		column.add_child(_wrapped(row[4], "Effect"))
	if not tools.is_empty():
		column.add_child(_gap(22))
		var caption := HudStyle.caption("NEW ON THE LAPTOP", 22)
		caption.name = "ToolsCaption"
		caption.add_theme_color_override("font_color", HudStyle.GOLD_BRIGHT)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(caption)
		column.add_child(_wrapped(", ".join(tools), "Tools"))
	column.add_child(_gap(30))
	ok_button = MenuStyle.menu_button("OK")
	ok_button.name = "OK"
	ok_button.custom_minimum_size.x = 160
	ok_button.pressed.connect(close)
	column.add_child(ok_button)


## The names of the tools `at` puts on the laptop.
static func tool_names(at: int) -> PackedStringArray:
	var names := PackedStringArray()
	for entry in Tools.opened_at(at):
		names.append(entry[1])
	return names


func _wrapped(text: String, label_name: String) -> Label:
	var label := HudStyle.label(text, 24, HudStyle.TEXT)
	label.name = label_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = WIDTH
	return label


func _gap(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _process(_delta: float) -> void:
	if not showing:
		_try_show()
	elif not is_queued_for_deletion() and not get_tree().paused:
		# Another note that came up over this one has closed and let the game
		# go: this one is still waiting for its OK.
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Shows it once nothing else holds the game: not paused, the mouse in the
## room (no laptop or menu open), no fade running.
func _try_show() -> void:
	if showing or not is_inside_tree():
		return
	if get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or SceneFlow.is_busy():
		return
	showing = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	# Only OK closes it; Esc mustn't reach the pause menu underneath either.
	if showing and event.is_action_pressed(Controls.PAUSE):
		get_viewport().set_input_as_handled()


## Freed while up (the shop closing under it): the game mustn't stay paused.
func _exit_tree() -> void:
	if showing and not is_queued_for_deletion():
		get_tree().paused = false


func close() -> void:
	if is_queued_for_deletion() or not showing:
		return
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
	closed.emit()
