class_name CreditsRoll
extends Control
## The credits, film style: they scroll up from the bottom of the screen at a
## steady pace until the last line has gone off the top, hold on the empty
## screen a moment, and close. Holding any key or mouse button speeds the roll up; Esc leaves
## it. Played from the main menu's Credits button and after the game is
## finished, over the main menu either way, so closing it lands there.
##
## Artists are one alphabetical list in three columns, cut into blocks of
## NAME_ROWS rows. With every set imported that's thousands of names, and
## blocks keep each label small; Godot skips drawing the ones off screen.

signal closed

const SPEED := 60.0
const FAST := 5.0
## Seconds the empty screen holds after the last line leaves, before the
## roll closes.
const HOLD := 3.0
const NAME_COLUMNS := 3
const NAME_ROWS := 30
const COLUMN_WIDTH := 380
const TEXT_WIDTH := 900
const GAP := 48

var _strip: VBoxContainer
var _hold_left := HOLD


func _init() -> void:
	name = "CreditsRoll"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	add_child(MenuStyle.backdrop(MenuStyle.TITLE_BACKDROP))
	# Marbled paper, dimmed well down so the lines read over it, turned its
	# own way (bible §8: never the same way twice).
	add_child(UiStyle.marbled_backdrop(1, true, Vector2(420, 610), 1.0, Vector2.ZERO, 0.8))
	_strip = VBoxContainer.new()
	_strip.add_theme_constant_override("separation", 16)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	for block in Credits.roll():
		_add_block(block[0], block[1])


func _ready() -> void:
	_strip.size.x = size.x
	_strip.position = Vector2(0, size.y)
	resized.connect(func() -> void: _strip.size.x = size.x)


func _add_block(kind: String, content) -> void:
	match kind:
		"title":
			# The game's name is the title screen's carved wordmark.
			if content == "CRACK & STACK":
				var centred := CenterContainer.new()
				centred.add_child(Wordmark.new(UiStyle.DISPLAY))
				_strip.add_child(centred)
			else:
				_strip.add_child(MenuStyle.heading(content, UiStyle.DISPLAY))
		"heading":
			_strip.add_child(_spacer())
			var heading := MenuStyle.heading(content, UiStyle.LEAD)
			heading.add_theme_color_override("font_color", UiStyle.GILT)
			_strip.add_child(heading)
		"text":
			_strip.add_child(_text(content))
		"names":
			for first in range(0, content.size(), NAME_COLUMNS * NAME_ROWS):
				_strip.add_child(_names(content.slice(first, first + NAME_COLUMNS * NAME_ROWS)))
		"end":
			_strip.add_child(_spacer())
			_strip.add_child(_text(content))


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = GAP
	return spacer


func _text(content: String) -> Label:
	var label := UiStyle.label(content)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = TEXT_WIDTH
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return label


## Up to NAME_ROWS rows of names, read left to right then down.
func _names(names: PackedStringArray) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for column in NAME_COLUMNS:
		var lines := PackedStringArray()
		for i in range(column, names.size(), NAME_COLUMNS):
			lines.append(names[i])
		var label := UiStyle.label("\n".join(lines), UiStyle.text_font(), UiStyle.BODY, UiStyle.PAPER_MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size.x = COLUMN_WIDTH
		label.clip_text = true
		row.add_child(label)
	return row


func _process(delta: float) -> void:
	advance(delta, Input.is_anything_pressed())


## Moves the roll on by `seconds` (faster while `fast`) until every line has
## left the top of the screen, then holds on the empty screen and closes.
func advance(seconds: float, fast := false) -> void:
	if is_queued_for_deletion():
		return
	var step := seconds * (FAST if fast else 1.0)
	if not is_holding():
		_strip.position.y = maxf(_strip.position.y - SPEED * step, -_strip_height())
		return
	_hold_left -= step
	if _hold_left <= 0.0:
		close()


## Every line has scrolled off the top and the roll is holding on the empty
## screen.
func is_holding() -> bool:
	return _strip.position.y <= -_strip_height() + 0.5


func _strip_height() -> float:
	return maxf(_strip.size.y, _strip.get_combined_minimum_size().y)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Controls.PAUSE):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()
