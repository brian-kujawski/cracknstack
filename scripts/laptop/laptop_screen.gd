class_name LaptopScreen
extends CanvasLayer
## The laptop, up close: a mid-90s desktop (Win95 for the look) filling a
## dark laptop bezel. A New Game opens on it with a message box (LaptopText
## .WELCOME); clicking OK leaves you on the desktop with the Instructions icon
## picked out and blinking until it's opened (point_to_readme), and closing
## the laptop starts the game. In the room, using the laptop (Laptop) opens
## it again.
##
## Its programs, as desktop icons and in the Start menu:
## - Card Shop: buy booster packs, booster boxes and bulk boxes of any
##   unlocked set, with money from selling cards (Prices, Progression
##   .money). An order is paid for at once and turns up inside the door the
##   next morning (`ordered`, handled by the shop). A locked set has an Unlock button instead (a
##   stand-in until levels unlock sets): its binder and starter packs turn
##   up inside the door (Progression.set_unlocked, handled by the shop).
## - My Collection: Mana, Cards Organized and each unlocked set's binder.
##   Levels go here when they exist.
## - To Do: the story so far (LaptopText.STORY), more as you sort.
## - Instructions: what to do (LaptopText.README).
##
## The game stops while it's open. Esc, or Start > Close Laptop, closes it.
## Mouse only, like every menu.

## An order from the Card Shop, paid for: kind is "pack", "booster_box" or
## "bulk_box" (as ShopSave names them), for set `code`.
signal ordered(kind: String, code: String)
## The laptop closed (and the game is running again).
signal closed

const BEZEL := Color(0.09, 0.09, 0.1)
const BEZEL_EDGE := Color(0.2, 0.2, 0.22)
## The bezel round the screen: left/right, top, bottom (pixels at 1080p).
const BEZEL_SIDE := 64
const BEZEL_TOP := 48
const BEZEL_BOTTOM := 76
const TASKBAR_HEIGHT := 48
## Taskbar showing above and below the Start button, the program buttons
## and the clock (one more at the ends).
const TASKBAR_GAP := 5
## Height of everything in the taskbar.
const TASK_ROW := TASKBAR_HEIGHT - TASKBAR_GAP * 2
const ICON_SIZE := Vector2(130, 110)
## A tool's picture in the Tools app, square.
const TOOL_ICON := 64
## Each program: its id, its name (desktop and Start menu), its window's
## title and size.
const APPS := [
	["shop", "Card Shop", "Card Shop", Vector2(1180, 720)],
	["collection", "My Collection", "My Collection", Vector2(860, 680)],
	["tools", "Tools", "Tools", Vector2(900, 700)],
	["story", "To Do", LaptopText.STORY_TITLE, Vector2(820, 640)],
	["readme", "Instructions", LaptopText.README_TITLE, Vector2(860, 700)],
]
## What the Card Shop sells: [kind, name, what's in it]. A pack's "%d" is
## how many cards a pack of the set holds (PackContents.pack_size).
const PRODUCTS := [
	["pack", "Booster Pack", "%d cards"],
	["booster_box", "Booster Box", "%d packs" % PackContents.BOX_PACKS],
	["bulk_box", "Bulk Box", "1,000 cards" if PackContents.BULK_SIZE == 1000 else "%d cards" % PackContents.BULK_SIZE],
]

## The in-game clock for the taskbar (the shop sets it), or null.
var day: DayCycle
## Returns what My Collection shows (the shop sets it): {"organized",
## "pockets", "mana", "binders": [[code, filled, capacity], ...]}.
var stats := Callable()
## Returns the orders waiting to arrive (the shop sets it): [kind, code, ...]
## each, as Main.orders.
var pending := Callable()
## Open windows by program id. For the tests.
var windows := {}
## The Card Shop's chosen set, and its last order's line.
var shop_set := ""
var shop_status: Label
## The message box, while one is up.
var message_box: Control

var _root: Control
var _screen: Control
var _desktop: Control
var _windows_layer: Control
var _taskbar_buttons: HBoxContainer
var _clock: Label
var _start_button: Button
var _start_menu: Control
var _modal: Control
var _welcome := false
## The Instructions icon is picked out and blinking, to be opened first.
var readme_nudge := false
var _nudge_tween: Tween
var _cascade := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 8
	_root = Control.new()
	_root.name = "Laptop"
	_root.theme = Win95.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_build_bezel()
	_build_desktop()
	_build_taskbar()
	_build_start_menu()
	_modal = Control.new()
	_modal.name = "Modal"
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.visible = false
	_screen.add_child(_modal)
	_screen.add_child(Win95.crt_glass())
	visible = false


func _process(_delta: float) -> void:
	if visible:
		_clock.text = clock_text(day.hour if day != null else DayCycle.START_HOUR)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or SceneFlow.is_busy():
		return
	if event.is_action_pressed(Controls.PAUSE):
		if message_box != null:
			press_ok()
		elif _start_menu.visible:
			_start_menu.visible = false
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey or event is InputEventMouseButton:
		# Nothing reaches the room while the laptop's open.
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


## Opens the laptop and stops the game. `welcome` (a New Game) shows the
## welcome message box, whose OK leaves you on the desktop, pointed at the
## Instructions.
func open(welcome := false) -> void:
	visible = true
	_welcome = welcome
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for app in windows:
		_refresh(app)
	if welcome:
		show_message(LaptopText.WELCOME_TITLE, LaptopText.WELCOME, point_to_readme)


## Closes the laptop: back into the room.
func close() -> void:
	if not visible:
		return
	_close_message()
	_start_menu.visible = false
	_welcome = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


## "9:05 PM" for an hour of the day (0..24).
static func clock_text(hour: float) -> String:
	var minutes := int(floorf(fposmod(hour, 24.0) * 60.0))
	var h := minutes / 60
	var shown := h % 12
	return "%d:%02d %s" % [12 if shown == 0 else shown, minutes % 60, "AM" if h < 12 else "PM"]


func _build_bezel() -> void:
	var bezel := ColorRect.new()
	bezel.color = BEZEL
	bezel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bezel)
	# A thin lighter lip round the glass, and the power light under it.
	var lip := ColorRect.new()
	lip.color = BEZEL_EDGE
	lip.set_anchors_preset(Control.PRESET_FULL_RECT)
	lip.offset_left = BEZEL_SIDE - 4
	lip.offset_right = -BEZEL_SIDE + 4
	lip.offset_top = BEZEL_TOP - 4
	lip.offset_bottom = -BEZEL_BOTTOM + 4
	lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lip)
	var light := ColorRect.new()
	light.color = Color(0.35, 0.9, 0.45)
	light.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	light.offset_left = -5
	light.offset_right = 5
	light.offset_top = -BEZEL_BOTTOM / 2.0 - 3
	light.offset_bottom = -BEZEL_BOTTOM / 2.0 + 3
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(light)
	_screen = Control.new()
	_screen.name = "Screen"
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.offset_left = BEZEL_SIDE
	_screen.offset_right = -BEZEL_SIDE
	_screen.offset_top = BEZEL_TOP
	_screen.offset_bottom = -BEZEL_BOTTOM
	_screen.clip_contents = true
	_root.add_child(_screen)


func _build_desktop() -> void:
	# The marbled wallpaper, tiled at 2x with hard pixels (style bible §8).
	var paper := TextureRect.new()
	paper.texture = Win95.WALLPAPER
	paper.stretch_mode = TextureRect.STRETCH_TILE
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	paper.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	paper.scale = Vector2.ONE * Win95.LINE
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop = Control.new()
	_desktop.name = "Desktop"
	_desktop.clip_contents = true
	_desktop.add_child(paper)
	_desktop.resized.connect(func() -> void: paper.size = _desktop.size / Win95.LINE)
	_desktop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desktop.offset_bottom = -TASKBAR_HEIGHT
	_desktop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_start_menu.visible = false)
	_screen.add_child(_desktop)
	var icons := VBoxContainer.new()
	icons.position = Vector2(20, 20)
	icons.add_theme_constant_override("separation", 18)
	_desktop.add_child(icons)
	for app in APPS:
		icons.add_child(_desktop_icon(app[0], app[1]))
	_windows_layer = Control.new()
	_windows_layer.name = "Windows"
	_windows_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_windows_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop.add_child(_windows_layer)


## A desktop icon: a little picture and its name under it. One click opens
## its program.
func _desktop_icon(app: String, title: String) -> Control:
	var icon := Button.new()
	icon.name = "Icon_" + app
	icon.focus_mode = Control.FOCUS_NONE
	icon.custom_minimum_size = ICON_SIZE
	icon.flat = true
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		icon.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var picture := LaptopIcon.new()
	picture.kind = app
	picture.position = Vector2((ICON_SIZE.x - LaptopIcon.SIZE) / 2, 4)
	picture.size = Vector2.ONE * LaptopIcon.SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(picture)
	var caption := Win95.label(title, 18, Win95.WHITE)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(0, LaptopIcon.SIZE + 10)
	caption.size = Vector2(ICON_SIZE.x, 30)
	caption.add_theme_constant_override("shadow_offset_x", 1)
	caption.add_theme_constant_override("shadow_offset_y", 1)
	caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	# A dark rim so the name reads on any part of the marbled paper.
	caption.add_theme_constant_override("outline_size", 5)
	caption.add_theme_color_override("font_outline_color", Color(Win95.TITLE, 0.85))
	caption.name = "Caption"
	icon.add_child(caption)
	icon.pressed.connect(open_app.bind(app))
	return icon


func _build_taskbar() -> void:
	var bar := Panel.new()
	bar.name = "Taskbar"
	bar.add_theme_stylebox_override("panel", Win95.bevel(Win95.Look.RAISED))
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -TASKBAR_HEIGHT
	_screen.add_child(bar)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = TASKBAR_GAP + 1
	row.offset_right = -TASKBAR_GAP - 1
	row.offset_top = TASKBAR_GAP
	row.offset_bottom = -TASKBAR_GAP
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	_start_button = Win95.button("  Start", _toggle_start_menu, 110)
	_start_button.name = "Start"
	Win95.snug(_start_button, TASK_ROW)
	_start_button.add_theme_constant_override("outline_size", 1)
	_start_button.add_theme_color_override("font_outline_color", Win95.TEXT)
	var mark := LaptopIcon.new()
	mark.kind = "start"
	mark.position = Vector2(10, (TASK_ROW - 20) / 2.0)
	mark.size = Vector2(20, 20)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_button.add_child(mark)
	row.add_child(_start_button)
	_taskbar_buttons = HBoxContainer.new()
	_taskbar_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_taskbar_buttons.add_theme_constant_override("separation", 6)
	row.add_child(_taskbar_buttons)
	var clock_well := PanelContainer.new()
	var well_box := Win95.bevel(Win95.Look.SUNKEN, Win95.FACE, 14)
	well_box.content_margin_top = 0
	well_box.content_margin_bottom = 0
	clock_well.add_theme_stylebox_override("panel", well_box)
	clock_well.custom_minimum_size.y = TASK_ROW
	_clock = Win95.label("", 18)
	_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock_well.add_child(_clock)
	row.add_child(clock_well)


func _build_start_menu() -> void:
	_start_menu = PanelContainer.new()
	_start_menu.name = "StartMenu"
	_start_menu.add_theme_stylebox_override("panel", Win95.bevel(Win95.Look.RAISED, Win95.FACE, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_start_menu.add_child(row)
	var band := ColorRect.new()
	band.color = Win95.SHADOW
	band.custom_minimum_size = Vector2(30, 0)
	row.add_child(band)
	var items := VBoxContainer.new()
	items.add_theme_constant_override("separation", 0)
	row.add_child(items)
	for app in APPS:
		items.add_child(_start_item(app[1], func() -> void:
			_start_menu.visible = false
			open_app(app[0])))
	var line := HSeparator.new()
	line.add_theme_stylebox_override("separator", Win95.bevel(Win95.Look.SUNKEN, Win95.FACE, 0))
	line.add_theme_constant_override("separation", 10)
	items.add_child(line)
	items.add_child(_start_item("Close Laptop", close))
	_start_menu.visible = false
	_screen.add_child(_start_menu)
	_start_menu.reset_size()


func _start_item(text: String, pressed: Callable) -> Button:
	var item := Win95.button(text, pressed, 300)
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size.y = 46
	item.add_theme_stylebox_override("normal", Win95.bevel(Win95.Look.FLAT, Win95.FACE, 16))
	for state in ["hover", "pressed", "hover_pressed"]:
		item.add_theme_stylebox_override(state, Win95.bevel(Win95.Look.FLAT, Win95.SELECTED, 16))
		item.add_theme_color_override("font_%s_color" % state, Win95.WHITE)
	return item


func _toggle_start_menu() -> void:
	_start_menu.visible = not _start_menu.visible
	if _start_menu.visible:
		_start_menu.reset_size()
		_start_menu.position = Vector2(4, _screen.size.y - TASKBAR_HEIGHT - _start_menu.size.y)
		_screen.move_child(_start_menu, -1)
		_screen.move_child(_modal, -1)


## Opens program `app` (an APPS id), or brings its window to the front if
## it's open already. Returns its window.
func open_app(app: String) -> LaptopWindow:
	if app == "readme":
		_stop_nudge()
	if windows.has(app):
		_focus(windows[app])
		return windows[app]
	var entry: Array = APPS.filter(func(a: Array) -> bool: return a[0] == app).front()
	var window := LaptopWindow.new(app, entry[2], entry[3])
	var room := _windows_layer.size if _windows_layer.size.x > 0 else Vector2(1792, 908)
	window.position = ((room - window.size) / 2 + Vector2(40, 30) * (_cascade % 4 - 1)).max(Vector2(170, 10))
	_cascade += 1
	_windows_layer.add_child(window)
	windows[app] = window
	var task := Win95.button(entry[1], func() -> void: _focus(window), 200)
	task.name = "Task_" + app
	Win95.snug(task, TASK_ROW)
	task.toggle_mode = true
	task.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_taskbar_buttons.add_child(task)
	window.focused.connect(func() -> void: _focus(window))
	window.closed.connect(func() -> void:
		windows.erase(app)
		task.queue_free()
		_cascade = maxi(0, _cascade - 1)
		_highlight_front())
	match app:
		"shop":
			_build_shop(window.content)
		"collection":
			_build_collection(window.content)
		"tools":
			_build_tools(window.content)
		"story":
			_build_text(window.content, "story")
		"readme":
			_build_text(window.content, "readme")
	_refresh(app)
	_focus(window)
	return window


func _focus(window: LaptopWindow) -> void:
	_windows_layer.move_child(window, -1)
	_highlight_front()


## The front window's title bar is navy and its taskbar button pressed in;
## the others are grey.
func _highlight_front() -> void:
	var front: Node = null
	for child in _windows_layer.get_children():
		if not child.is_queued_for_deletion():
			front = child
	for app in windows:
		var window: LaptopWindow = windows[app]
		window.set_active(window == front)
		var task := _taskbar_buttons.get_node_or_null("Task_" + app) as Button
		if task != null:
			task.set_pressed_no_signal(window == front)


## A message box over everything on the screen, with one OK button that
## closes it and calls `ok`.
func show_message(title: String, text: String, ok := Callable()) -> void:
	_close_message()
	_modal.visible = true
	_screen.move_child(_modal, -1)
	var box := LaptopWindow.new("message", title, Vector2(620, 260))
	box.position = (_screen.size - box.size) / 2 if _screen.size.x > 0 else Vector2(586, 324)
	_modal.add_child(box)
	message_box = box
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	box.content.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var info := LaptopIcon.new()
	info.kind = "info"
	info.custom_minimum_size = Vector2.ONE * LaptopIcon.SIZE
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)
	var words := Win95.label(text, 22)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var ok_button := Win95.button("OK", func() -> void:
		_close_message()
		if ok.is_valid():
			ok.call(), 130)
	ok_button.name = "OK"
	ok_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(ok_button)
	# Its own close box does what OK does.
	box.closed.connect(func() -> void:
		message_box = null
		_modal.visible = false
		if ok.is_valid():
			ok.call())


## Picks out the Instructions icon, the way a selected icon looks (its name on
## navy), and blinks it until Instructions is opened.
func point_to_readme() -> void:
	readme_nudge = true
	var icon: Control = _desktop.find_child("Icon_readme", true, false)
	var caption := icon.get_node("Caption") as Label
	caption.add_theme_stylebox_override("normal", Win95.bevel(Win95.Look.FLAT, Win95.SELECTED, 4))
	caption.size.x = ICON_SIZE.x
	if _nudge_tween != null:
		_nudge_tween.kill()
	_nudge_tween = icon.create_tween().set_loops()
	_nudge_tween.tween_property(icon, "modulate", Color(1, 1, 1, 0.35), 0.45).set_trans(Tween.TRANS_SINE)
	_nudge_tween.tween_property(icon, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)


func _stop_nudge() -> void:
	if not readme_nudge:
		return
	readme_nudge = false
	if _nudge_tween != null:
		_nudge_tween.kill()
		_nudge_tween = null
	var icon: Control = _desktop.find_child("Icon_readme", true, false)
	icon.modulate = Color.WHITE
	(icon.get_node("Caption") as Label).remove_theme_stylebox_override("normal")


## Clicks the message box's OK. For the tests (and Esc on the welcome box).
func press_ok() -> void:
	if message_box != null:
		(message_box.find_child("OK", true, false) as Button).pressed.emit()


func _close_message() -> void:
	if message_box != null:
		message_box.queue_free()
		message_box = null
	_modal.visible = false


## Redraws what a program shows that changes as you play.
func _refresh(app: String) -> void:
	if not windows.has(app):
		return
	var window: LaptopWindow = windows[app]
	match app:
		"collection":
			for child in window.content.get_children():
				child.queue_free()
				window.content.remove_child(child)
			_build_collection(window.content)
		"tools":
			for child in window.content.get_children():
				child.queue_free()
				window.content.remove_child(child)
			_build_tools(window.content)
		"story":
			var text := window.find_child("Text", true, false) as Label
			text.text = story_text(_stats().get("organized", 0))
		"shop":
			# Money (sales, morning deliveries) and unlocks change while the
			# laptop's shut: Order buttons, "- locked" rows and the money
			# line follow what you have now.
			for set_data in shop_sets():
				var row := window.find_child("Set_" + set_data.code, true, false) as Button
				if row != null:
					row.text = _row_text(set_data)
			if shop_status != null:
				shop_status.text = money_line()
			_redraw_shop(shop_set)


func _stats() -> Dictionary:
	return stats.call() if stats.is_valid() else {}


# --- Card Shop -------------------------------------------------------------

## The sets the Card Shop sells, newest first: every set with at least a
## pack's worth of cards.
static func shop_sets() -> Array[SetData]:
	var sets: Array[SetData] = []
	for set_data in CardDatabase.sets_in_shelf_order():
		if set_data.code != RareCards.SET_CODE and PackContents.sells_packs(set_data.code):
			sets.append(set_data)
	sets.reverse()
	return sets


func _build_shop(into: Control) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	into.add_child(column)
	# Shareware title art: the shop's name in the game's name voice, gilt on
	# dark stone (style bible §10).
	var banner := ColorRect.new()
	banner.color = Win95.TITLE
	banner.custom_minimum_size = Vector2(0, 60)
	column.add_child(banner)
	banner.add_child(Win95.title_shade())
	var shop_name := UiStyle.label("Card Shop", UiStyle.name_font(), UiStyle.LEAD, UiStyle.GILT)
	shop_name.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_name.offset_left = 16
	shop_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_child(shop_name)
	var strap := Win95.label("sealed product by mail", Win95.FONT_SIZE, Win95.LIGHT)
	strap.autowrap_mode = TextServer.AUTOWRAP_OFF
	strap.set_anchors_preset(Control.PRESET_FULL_RECT)
	strap.offset_right = -16
	strap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	strap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_child(strap)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	column.add_child(body)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(500, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var list_well := Win95.well(scroll)
	list_well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(list_well)

	var detail := VBoxContainer.new()
	detail.name = "Detail"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 12)
	body.add_child(detail)

	shop_status = Win95.label(money_line(), 18)
	shop_status.name = "Status"
	column.add_child(Win95.well(shop_status, Win95.FACE))

	var group := ButtonGroup.new()
	var sets := shop_sets()
	for set_data in sets:
		var row := Button.new()
		row.name = "Set_" + set_data.code
		row.toggle_mode = true
		row.button_group = group
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = _row_text(set_data)
		row.clip_text = true
		row.add_theme_font_size_override("font_size", 18)
		row.add_theme_stylebox_override("normal", Win95.bevel(Win95.Look.FLAT, Win95.WHITE, 8))
		row.add_theme_stylebox_override("hover", Win95.bevel(Win95.Look.FLAT, Win95.WHITE, 8))
		for state in ["pressed", "hover_pressed"]:
			row.add_theme_stylebox_override(state, Win95.bevel(Win95.Look.FLAT, Win95.SELECTED, 8))
			row.add_theme_color_override("font_%s_color" % state, Win95.WHITE)
		row.pressed.connect(func() -> void: _show_set(detail, set_data.code))
		list.add_child(row)
	if not sets.is_empty():
		(list.get_child(0) as Button).set_pressed_no_signal(true)
		_show_set(detail, sets[0].code)


## A set's line in the Card Shop's list.
static func _row_text(set_data: SetData) -> String:
	var text := "%s  (%s, %s)" % [set_data.name, set_data.code, set_data.release_date.left(4)]
	return text if Progression.is_set_unlocked(set_data.code) else text + "  - locked"


## The Card Shop's right-hand side: the chosen set and what it sells, or,
## while it's locked, which chapter opens it.
func _show_set(detail: Control, code: String) -> void:
	shop_set = code
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	var set_data := CardDatabase.get_set(code)
	detail.add_child(Win95.label(set_data.name, 28))
	detail.add_child(Win95.label("%s  ·  released %s  ·  %d cards" % [code, set_data.release_date, set_data.card_count], 18, Win95.SHADOW.darkened(0.3)))
	var swatch := ColorRect.new()
	swatch.color = set_data.accent_color
	swatch.custom_minimum_size = Vector2(0, 8)
	detail.add_child(swatch)
	if not Progression.is_set_unlocked(code):
		var words := VBoxContainer.new()
		words.name = "Locked"
		words.add_theme_constant_override("separation", 0)
		words.add_child(Win95.label("Locked", 22))
		var note := Win95.label("Opens with Chapter %d." % Chapters.game_number(code), 18, Win95.SHADOW.darkened(0.3))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(note)
		var panel := Win95.well(words, Win95.FACE)
		panel.add_theme_stylebox_override("panel", Win95.bevel(Win95.Look.RAISED, Win95.FACE, 14))
		detail.add_child(panel)
		return
	for product in PRODUCTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", 0)
		words.add_child(Win95.label(product[1], 22))
		var cents := Prices.product_cents(product[0], code)
		var contents: String = product[2] % PackContents.pack_size(code) if product[0] == "pack" else product[2]
		words.add_child(Win95.label("%s  ·  %s" % [contents, Progression.money_text(cents)], 18, Win95.SHADOW.darkened(0.3)))
		row.add_child(words)
		var order := Win95.button("Order", order_product.bind(product[0], code), 130)
		order.name = "Order_" + product[0]
		order.disabled = cents > Progression.money
		order.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(order)
		var panel := Win95.well(row, Win95.FACE)
		panel.add_theme_stylebox_override("panel", Win95.bevel(Win95.Look.RAISED, Win95.FACE, 14))
		detail.add_child(panel)
	_show_singles(detail, code)


## Card Shop singles of set `code`: once you own Prices.singles_from() of
## it, every card you're missing, one Order button each.
func _show_singles(detail: Control, code: String) -> void:
	var share := PackContents.owned_share(code)
	if share < Prices.singles_from():
		return
	detail.add_child(Win95.label("Singles", 22))
	var list := VBoxContainer.new()
	list.name = "Singles"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	var waiting := _pending_singles()
	for card in CardDatabase.cards_in_set(code):
		if Collection.owns(card.id):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var cents := Prices.single_cents(card)
		var words := Win95.label("#%03d  %s  ·  %s" % [card.collector_number, card.name, Progression.money_text(cents)], 18)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.clip_text = true
		row.add_child(words)
		var key := single_key(card)
		var order := Win95.button("Ordered" if waiting.has(key) else "Order", order_single.bind(card), 130)
		order.name = "Single_%d" % card.collector_number
		order.disabled = waiting.has(key) or cents > Progression.money
		row.add_child(order)
		list.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var well := Win95.well(scroll)
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(well)


## How a single is named in an order: "SET:number".
static func single_key(card: CardData) -> String:
	return "%s:%d" % [card.set_code, card.collector_number]


## The singles on their way: "SET:number" -> true.
func _pending_singles() -> Dictionary:
	var waiting := {}
	var orders: Array = pending.call() if pending.is_valid() else []
	for order in orders:
		if order[0] == "single":
			waiting[order[1]] = true
	return waiting


## Orders a single of `card`, paying for it now: only while its set's
## singles are on sale, you don't own it, it isn't on its way already and
## you can afford it. Returns whether it was ordered.
func order_single(card: CardData) -> bool:
	if not Progression.is_set_unlocked(card.set_code) or Collection.owns(card.id):
		return false
	if PackContents.owned_share(card.set_code) < Prices.singles_from():
		return false
	if _pending_singles().has(single_key(card)):
		return false
	if not Progression.spend_money(Prices.single_cents(card)):
		if shop_status != null:
			shop_status.text = "Not enough money for %s. %s" % [card.name, money_line()]
		return false
	ordered.emit("single", single_key(card))
	if shop_status != null:
		shop_status.text = "Ordered: %s. It arrives tomorrow morning. You have %s left." % [
			card.name, Progression.money_text(Progression.money)]
	_redraw_shop(card.set_code)
	return true


func _redraw_shop(code: String) -> void:
	var window: Control = windows.get("shop")
	var detail: Control = window.find_child("Detail", true, false) if window != null else null
	if detail != null and shop_set == code:
		_show_set(detail, code)


# --- Tools -----------------------------------------------------------------

## The Tools catalogue: every tool in level order (_tool_row).
func _build_tools(into: Control) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	into.add_child(column)
	column.add_child(Win95.label("Tools", 28))
	var list := VBoxContainer.new()
	list.name = "ToolList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	for row in Tools.LIST:
		list.add_child(_tool_row(row))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	column.add_child(scroll)
	var status := Win95.label(money_line(), 18)
	status.name = "ToolStatus"
	column.add_child(Win95.well(status, Win95.FACE))


## One tool's panel: its picture, name, what it does and price, and an
## Order button or where it stands. Until its level is reached the picture
## is the grey outline and what it does is "???"; more than HIDDEN_BEYOND
## levels away its name is "???" too.
func _tool_row(tool: Array) -> Control:
	var id: String = tool[0]
	var opened := Progression.level() >= int(tool[2])
	var row := HBoxContainer.new()
	row.name = "Tool_" + id
	row.add_theme_constant_override("separation", 14)
	var picture := TextureRect.new()
	picture.name = "Icon"
	picture.texture = Tools.icon(id, opened)
	picture.custom_minimum_size = Vector2.ONE * TOOL_ICON
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(picture)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var grey := Win95.SHADOW.darkened(0.3)
	words.add_child(Win95.label(tool[1] if Tools.is_named(id) else "???", 22))
	var effect := Win95.label("%s  ·  %s" % [tool[4], Progression.money_text(Tools.price_cents(id))] if opened else "???", 18, grey)
	words.add_child(effect)
	var state := ""
	if Progression.has_tool(id):
		state = "Owned"
	elif Progression.is_tool_ordered(id):
		state = "On its way"
	elif not opened:
		state = "Level %d" % tool[2]
	elif not Tools.has_needed(id):
		state = "Needs %s" % Tools.tool_name(Tools.needs(id))
	if state != "":
		var note := Win95.label(state, 18)
		note.autowrap_mode = TextServer.AUTOWRAP_OFF
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.custom_minimum_size.x = 130
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(note)
	else:
		var order := Win95.button("Order", order_tool.bind(id), 130)
		order.name = "Order"
		order.disabled = not Tools.can_order(id)
		order.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(order)
	var panel := Win95.well(row, Win95.FACE)
	panel.add_theme_stylebox_override("panel", Win95.bevel(Win95.Look.RAISED, Win95.FACE, 14))
	return panel


## Orders tool `id`, paying for it now (Tools.can_order). It arrives with
## the morning's orders. Returns whether it was ordered.
func order_tool(id: String) -> bool:
	if not Tools.can_order(id) or not Progression.spend_money(Tools.price_cents(id)):
		return false
	Progression.mark_tool_ordered(id)
	ordered.emit("tool", id)
	_refresh("tools")
	var window: Control = windows.get("tools")
	var status: Label = window.find_child("ToolStatus", true, false) if window != null else null
	if status != null:
		status.text = "Ordered: %s. It arrives tomorrow morning. You have %s left." % [
			Tools.tool_name(id), Progression.money_text(Progression.money)]
	return true


## The Card Shop's money line: what you have, and when orders come.
static func money_line() -> String:
	return "You have %s. Orders arrive inside the door the next morning." % Progression.money_text(Progression.money)


## Orders one of `kind` ("pack", "booster_box", "bulk_box") of set `code`,
## paying for it now. A locked set can't be ordered, nor anything you can't
## afford. Returns whether it was ordered.
func order_product(kind: String, code: String) -> bool:
	if not Progression.is_set_unlocked(code):
		return false
	var product: Array = PRODUCTS.filter(func(p: Array) -> bool: return p[0] == kind).front()
	if not Progression.spend_money(Prices.product_cents(kind, code)):
		if shop_status != null:
			shop_status.text = "Not enough money for a %s %s. %s" % [CardDatabase.get_set(code).name, product[1], money_line()]
		return false
	ordered.emit(kind, code)
	if shop_status != null:
		shop_status.text = "Ordered: %s %s. It arrives tomorrow morning. You have %s left." % [
			CardDatabase.get_set(code).name, product[1], Progression.money_text(Progression.money)]
	_redraw_shop(code)
	return true


# --- My Collection ----------------------------------------------------------

## My Collection's line on what's next: "Next at Level 4: Tithe".
static func next_unlock_text() -> String:
	var next := Progression.next_unlock()
	if next.is_empty():
		return "Every ability is yours."
	var names := PackedStringArray()
	for row in next[1]:
		names.append(row[3])
	return "Next at Level %d: %s" % [next[0], ", ".join(names)]


func _build_collection(into: Control) -> void:
	var s := _stats()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	into.add_child(column)
	var level := HBoxContainer.new()
	level.add_theme_constant_override("separation", 16)
	column.add_child(level)
	var level_name := Win95.label("Level %d" % Progression.level(), 28)
	level_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	level.add_child(level_name)
	var level_note := Win95.label(next_unlock_text(), 18)
	level_note.name = "NextUnlock"
	level_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level.add_child(level_note)
	var organized: int = s.get("organized", 0)
	var pockets: int = s.get("pockets", 0)
	if Progression.level_span() > 0:
		column.add_child(Win95.label("Mana: %d / %d to the next level" % [Progression.level_progress(), Progression.level_span()], 22))
	else:
		column.add_child(Win95.label("Mana: %d (top level)" % Progression.mana, 22))
	column.add_child(Win95.label("Cards Organized: %d/%d" % [organized, pockets], 22))
	var bar := ProgressBar.new()
	bar.name = "Organized"
	bar.custom_minimum_size = Vector2(0, 30)
	bar.max_value = maxi(1, pockets)
	bar.value = organized
	column.add_child(bar)
	var binders: Array = s.get("binders", [])
	column.add_child(Win95.label("Unlocked sets: %d" % binders.size(), 22))
	var list := VBoxContainer.new()
	list.name = "Binders"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	if binders.is_empty():
		list.add_child(Win95.label("None yet. Open product of a set to unlock its binder.", 18))
	for entry in binders:
		var set_data := CardDatabase.get_set(entry[0])
		list.add_child(Win95.label("%s (%s): %d/%d filed" % [set_data.name, entry[0], entry[1], entry[2]], 18))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var well := Win95.well(scroll)
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(well)


# --- To Do and Instructions -------------------------------------------------------

## The story so far at `organized` Cards Organized, as one page.
static func story_text(organized: int) -> String:
	var parts := PackedStringArray()
	for entry in LaptopText.story_entries(organized):
		parts.append("%s\n\n%s" % [entry.title.to_upper(), entry.text])
	return "\n\n\n".join(parts)


func _build_text(into: Control, which: String) -> void:
	var text := Win95.label(LaptopText.README if which == "readme" else story_text(_stats().get("organized", 0)), 20)
	text.name = "Text"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(text)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(margin)
	into.add_child(Win95.well(scroll))
