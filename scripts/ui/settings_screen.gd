class_name SettingsScreen
extends MenuScreen
## The Settings page, opened from the main menu and the pause menu: four
## tabs (Audio, Controls, Gameplay, Graphics), each a column of rows with the
## label on the left and its slider, checkbox or dropdown lined up on the
## right. Changes take effect at once and are saved when the page closes.
## Reset puts the open tab back to its defaults, after asking.
##
## The Controls tab lists the keys for reference only; they can't be
## rebound. Sorceries show as "Sorcery 1" and so on until learned in the
## current game, so the page never names one before you've seen it.

const Main := preload("res://scripts/main.gd")

const TABS := ["Audio", "Controls", "Gameplay", "Graphics"]
const LABEL_WIDTH := 560
const CONTROL_WIDTH := 420
const VALUE_WIDTH := 100
const ROW_HEIGHT := 52
const FONT_SIZE := UiStyle.BODY
## Over the shop (from the pause menu), the Graphics tab lets the game show
## through, so field of view and brightness can be judged as they change.
const SEE_THROUGH := Color(UiStyle.BORDER, 0.55)
## The panel's window then: the room shows through it as well.
const SEE_THROUGH_WINDOW := Color(UiStyle.GROUND, 0.55)
## Checkboxes drawn at a size that reads at 1080p (the default is tiny).
const CHECK_SIZE := 30

## Each tab's rows, top to bottom:
##   ["heading", text]
##   ["slider", key, label, min, max, step, format ("percent", "times", "degrees")]
##   ["check", key, label]
##   ["dropdown", key, label, [choices]]  (a true/false setting takes two choices)
##   ["keys"]  (the Controls tab's key list)
const ROWS := {
	"Audio": [
		["heading", "VOLUME"],
		["slider", "master_volume", "Master", 0.0, 1.0, 0.05, "percent"],
		["slider", "effects_volume", "Effects", 0.0, 1.0, 0.05, "percent"],
		["slider", "ambience_volume", "Ambience", 0.0, 1.0, 0.05, "percent"],
		["slider", "music_volume", "Music", 0.0, 1.0, 0.05, "percent"],
		["heading", "BACKGROUND"],
		["check", "mute_in_background", "Mute when the game is in the background"],
	],
	"Controls": [
		["heading", "MOUSE"],
		["slider", "mouse_sensitivity", "Mouse sensitivity", 0.25, 3.0, 0.05, "times"],
		["check", "invert_y", "Invert Y"],
		["heading", "MOVING"],
		["dropdown", "crouch_toggle", "Crouch mode", ["Hold", "Toggle"]],
		["keys"],
	],
	"Gameplay": [
		["heading", "DAY AND NIGHT"],
		["dropdown", "day_length", "Day length", ["10 min", "15 min", "30 min", "60 min", "Stopped"]],
		["dropdown", "stopped_at", "Stopped at", ["Morning", "Noon", "Evening", "Night"]],
		["heading", "SAVING"],
		["dropdown", "autosave_every", "Autosave every", ["Off", "2 min", "5 min", "10 min"]],
		["heading", "SELLING"],
		["check", "confirm_new_sales", "Ask before selling a card you haven't collected"],
		["heading", "INTERFACE"],
		["slider", "interface_size", "Interface size", 0.75, 1.25, 0.05, "percent"],
	],
	"Graphics": [
		["heading", "DISPLAY"],
		["dropdown", "fullscreen", "Window mode", ["Windowed", "Fullscreen"]],
		["check", "vsync", "Vsync"],
		["dropdown", "frame_limit", "Frame rate limit", ["Unlimited", "30", "60", "120", "144"]],
		["slider", "field_of_view", "Field of view", 60.0, 100.0, 1.0, "degrees"],
		["slider", "brightness", "Brightness", 0.5, 1.5, 0.05, "percent"],
		["heading", "QUALITY"],
		["dropdown", "quality", "Quality", ["Low", "Medium", "High", "Custom"]],
		["dropdown", "render_scale", "Render scale", ["100%", "85%", "75%", "50%"]],
		["dropdown", "shadows", "Shadows", ["Low", "Medium", "High"]],
		["dropdown", "anti_aliasing", "Anti-aliasing", ["Off", "FXAA", "MSAA 2×", "MSAA 4×"]],
		["dropdown", "card_detail", "Card detail", ["High", "Low"]],
	],
}

## The key list: [heading, [[label, actions], ...]]. A label of "" takes the
## action's own name from Controls.ACTIONS.
const KEY_ROWS := [
	["KEYS", [
		["Walk", [Controls.MOVE_FORWARD, Controls.MOVE_LEFT, Controls.MOVE_BACK, Controls.MOVE_RIGHT]],
		["", [Controls.CROUCH]],
		["", [Controls.USE_HAND]],
		["", [Controls.TOSS]],
		["", [Controls.INSPECT]],
		["", [Controls.INTERACT]],
		["Turn pages", [Controls.FLIP_NEXT, Controls.FLIP_PREVIOUS]],
		["", [Controls.RADIO]],
		["", [Controls.PAUSE]],
	]],
]

## The tab the page opens on: the last one used, for as long as the game runs.
static var _last_tab := "Audio"

## For the tests: tab buttons and pages by tab name, each setting's control
## by key, and the key list's text labels by row label.
var tab_buttons := {}
var pages := {}
var controls := {}
var key_labels := {}
var reset_button: Button
var open_tab := ""

## Redraws a row from its setting: [Callable], run after every change.
var _refreshers: Array[Callable] = []
var _backdrop: ColorRect


func _init() -> void:
	super("Settings")
	_backdrop = get_child(0)
	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", 16)
	content.add_child(tab_row)
	var group := ButtonGroup.new()
	for tab in TABS:
		var button := MenuStyle.menu_button(tab)
		button.custom_minimum_size.x = 220
		button.toggle_mode = true
		# The open tab stays pressed in, its name in gilt.
		for state in ["font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(state, UiStyle.GILT)
		button.button_group = group
		button.pressed.connect(show_tab.bind(tab))
		tab_row.add_child(button)
		tab_buttons[tab] = button
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	for tab in TABS:
		var page := VBoxContainer.new()
		page.name = tab
		page.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		page.custom_minimum_size.x = LABEL_WIDTH + CONTROL_WIDTH + VALUE_WIDTH
		holder.add_child(page)
		pages[tab] = page
		for row in ROWS[tab]:
			_add_row(page, row)
	reset_button = MenuStyle.menu_button("Reset")
	reset_button.pressed.connect(_ask_to_reset)
	content.add_child(reset_button)
	Settings.changed.connect(_refresh.unbind(1))
	closed.connect(Settings.save)
	closed.connect(_show_opener.bind(true))
	_refresh()


func _ready() -> void:
	show_tab(_last_tab)


func show_tab(tab: String) -> void:
	open_tab = tab
	_last_tab = tab
	for name in pages:
		pages[name].visible = name == tab
	for name in tab_buttons:
		tab_buttons[name].set_pressed_no_signal(name == tab)
	reset_button.text = "Reset %s" % tab
	var see_through := is_inside_tree() and get_tree().paused and tab == "Graphics"
	_backdrop.color = SEE_THROUGH if see_through else MenuStyle.TITLE_BACKDROP
	panel_frame.window = SEE_THROUGH_WINDOW if see_through else UiStyle.GROUND
	panel.queue_redraw()
	# The menu that opened the page (and its own dimming) steps aside too.
	_show_opener(not see_through)


func _show_opener(shown: bool) -> void:
	if get_parent() == null:
		return
	for sibling in get_parent().get_children():
		if sibling != self and sibling is CanvasItem:
			sibling.visible = shown


## Whether a row can be changed right now: Stopped at only when the clock is
## stopped, the frame limit only with vsync off.
static func is_enabled(key: String) -> bool:
	match key:
		"stopped_at":
			return Settings.day_seconds() <= 0.0
		"frame_limit":
			return not Settings.value("vsync")
	return true


## What a slider shows beside it: "80%", "1.00×", "75°".
static func format_value(value: float, format: String) -> String:
	match format:
		"times":
			return "%.2f×" % value
		"degrees":
			return "%d°" % roundi(value)
	return "%d%%" % roundi(value * 100.0)


## A key list entry's keys: one letter per action run together ("WASD"),
## the wheel as "Scroll", otherwise each action's key ("Ctrl", "Click").
static func keys_text(actions: Array) -> String:
	var text := ""
	if actions.size() == 2:
		text = Controls.pair_label(actions[0], actions[1])
	else:
		var labels := actions.map(func(action: StringName) -> String: return Controls.label(action))
		var single := labels.all(func(label: String) -> bool: return label.length() == 1)
		text = "".join(labels) if single else "/".join(labels)
	return text.left(1).to_upper() + text.substr(1)


## A sorcery's name once it's learned in this game, "Sorcery 3" until then.
static func sorcery_name(index: int) -> String:
	var name: String = Main.SORCERIES[index][0]
	return name if Progression.rank(name) > 0 else "Sorcery %d" % (index + 1)


static func action_name(action: StringName) -> String:
	for entry in Controls.ACTIONS:
		if entry[0] == action:
			return entry[1]
	return String(action)


func _add_row(page: VBoxContainer, row: Array) -> void:
	match row[0]:
		"heading":
			page.add_child(_heading(row[1]))
		"slider":
			_add_slider(page, row)
		"check":
			_add_check(page, row)
		"dropdown":
			_add_dropdown(page, row)
		"keys":
			_add_keys(page)


## A section heading: a gilt caption in small capitals.
func _heading(text: String) -> Label:
	var label := UiStyle.label(text.capitalize(), UiStyle.caption_font(), UiStyle.BODY, UiStyle.GILT)
	label.custom_minimum_size.y = 60
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return label


## A row: its label, then `control`, then (for sliders) the value.
func _row(page: VBoxContainer, key: String, text: String, control: Control, value_label: Label = null) -> Label:
	var row := HBoxContainer.new()
	row.name = key if key != "" else text
	row.custom_minimum_size.y = ROW_HEIGHT
	page.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = LABEL_WIDTH
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	row.add_child(label)
	control.custom_minimum_size.x = CONTROL_WIDTH
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.focus_mode = Control.FOCUS_NONE
	row.add_child(control)
	if value_label != null:
		value_label.custom_minimum_size.x = VALUE_WIDTH
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", FONT_SIZE)
		row.add_child(value_label)
	if key != "":
		controls[key] = control
		_refreshers.append(func() -> void:
			var enabled := is_enabled(key)
			label.modulate.a = 1.0 if enabled else 0.4
			if control is BaseButton:
				control.disabled = not enabled)
	return label


func _add_slider(page: VBoxContainer, row: Array) -> void:
	var key: String = row[1]
	var slider := HSlider.new()
	slider.min_value = row[3]
	slider.max_value = row[4]
	slider.step = row[5]
	# The wheel scrolls the page, never a slider under the pointer.
	slider.scrollable = false
	var shown := Label.new()
	_row(page, key, row[2], slider, shown)
	var format: String = row[6]
	slider.value_changed.connect(func(value: float) -> void:
		shown.text = format_value(value, format)
		# The whole interface rescales with its size, so that one waits for the
		# drag to end rather than moving the slider out from under the mouse.
		if key != "interface_size":
			Settings.change(key, value))
	if key == "interface_size":
		slider.drag_ended.connect(func(_changed: bool) -> void: Settings.change(key, slider.value))
	_refreshers.append(func() -> void:
		slider.set_value_no_signal(Settings.value(key))
		shown.text = format_value(Settings.value(key), format))


func _add_check(page: VBoxContainer, row: Array) -> void:
	var key: String = row[1]
	var box := CheckBox.new()
	var label := _row(page, key, row[2], box)
	box.toggled.connect(func(on: bool) -> void: Settings.change(key, on))
	# Clicking the label works as well as the box.
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not box.disabled:
			box.button_pressed = not box.button_pressed)
	_refreshers.append(func() -> void: box.set_pressed_no_signal(Settings.value(key)))


## A checkbox's box: a sunken well, a gilt tablet in it when it's on
## (UiStyle; the theme gives every CheckBox these).
static func check_icon(on: bool, disabled: bool) -> ImageTexture:
	return UiStyle.check_icon(on, disabled, CHECK_SIZE)


func _add_dropdown(page: VBoxContainer, row: Array) -> void:
	var key: String = row[1]
	var dropdown := OptionButton.new()
	dropdown.add_theme_font_size_override("font_size", FONT_SIZE)
	dropdown.get_popup().add_theme_font_size_override("font_size", FONT_SIZE)
	for choice in row[3]:
		dropdown.add_item(choice)
	# Custom is what the quality rows add up to, never something to pick.
	if key == "quality":
		dropdown.set_item_disabled(Settings.CUSTOM_QUALITY, true)
	_row(page, key, row[2], dropdown)
	var is_switch: bool = Settings.DEFAULTS[key] is bool
	dropdown.item_selected.connect(func(index: int) -> void:
		Settings.change(key, index == 1 if is_switch else index))
	_refreshers.append(func() -> void: dropdown.select(int(Settings.value(key))))


func _add_keys(page: VBoxContainer) -> void:
	for group in KEY_ROWS:
		page.add_child(_heading(group[0]))
		for entry in group[1]:
			var text: String = entry[0] if entry[0] != "" else action_name(entry[1][0])
			_add_key_row(page, text, keys_text.bind(entry[1]))
	page.add_child(_heading("SORCERIES"))
	for index in Main.SORCERIES.size():
		var action: StringName = Main.SORCERIES[index][1]
		_add_key_row(page, sorcery_name(index), keys_text.bind([action]))


## A key list row: what it does, then its keys as plain text.
func _add_key_row(page: VBoxContainer, text: String, keys: Callable) -> Label:
	var shown := Label.new()
	shown.text = keys.call()
	var label := _row(page, "", text, shown)
	shown.add_theme_font_size_override("font_size", FONT_SIZE)
	shown.add_theme_color_override("font_color", UiStyle.PAPER_MUTED)
	key_labels[text] = shown
	return label


func _refresh() -> void:
	for refresh in _refreshers:
		refresh.call()


func _ask_to_reset() -> void:
	add_child(ResetQuestion.new(open_tab))


## "Reset Audio to defaults?" over the page: Reset or Cancel. Esc cancels.
class ResetQuestion extends Control:
	var tab: String
	var buttons := {}

	func _init(for_tab: String) -> void:
		tab = for_tab
		name = "ResetQuestion"
		set_anchors_preset(Control.PRESET_FULL_RECT)
		var backdrop := MenuStyle.backdrop()
		add_child(backdrop)
		var panel := MenuStyle.framed_column(14, "Reset " + tab)
		backdrop.add_child(panel)
		var column: VBoxContainer = panel.get_node("Column")
		var question := MenuStyle.question("Reset %s to defaults?" % tab)
		question.custom_minimum_size = Vector2(560, 80)
		column.add_child(question)
		for entry in [["Reset", _reset], ["Cancel", queue_free]]:
			var button := MenuStyle.menu_button(entry[0])
			button.pressed.connect(entry[1])
			column.add_child(button)
			buttons[entry[0]] = button

	func _reset() -> void:
		Settings.reset_tab(tab)
		queue_free()

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(Controls.PAUSE):
			get_viewport().set_input_as_handled()
			queue_free()
