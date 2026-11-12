class_name RadioMenu
extends CanvasLayer
## The radio's menu (plan: sound-plan.md §7.2). Q (Controls.RADIO) stops the
## game and shows what's playing, Previous / Play / Next / Repeat, the
## radio's own volume, and every song: unlocked ones by title (click one to
## play it), locked ones as ???. Clicking the radio in the shop (ShopRadio)
## opens it too. Q or Esc goes back in.

const LIST_SIZE := Vector2(560, 330)
const SMALL_BUTTON := Vector2(170, 56)

## For the tests.
var title_label: Label
var time_label: Label
var play_button: Button
var repeat_button: Button
var volume_slider: HSlider
## One button per song, in order.
var song_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 9
	var backdrop := MenuStyle.backdrop()
	add_child(backdrop)
	var panel := MenuStyle.framed_column(16, "Radio")
	backdrop.add_child(panel)
	var column: VBoxContainer = panel.get_node("Column")
	column.add_child(MenuStyle.heading("Radio"))
	# What's playing: its name in the name voice, the time under it.
	title_label = MenuStyle.question("", UiStyle.LEAD)
	column.add_child(title_label)
	time_label = MenuStyle.line("", UiStyle.SMALL)
	column.add_child(time_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var previous := _small_button("Previous", Radio.previous)
	buttons.add_child(previous)
	play_button = _small_button("Play", Radio.toggle_playing)
	buttons.add_child(play_button)
	buttons.add_child(_small_button("Next", Radio.next))
	repeat_button = _small_button("", func() -> void: Radio.set_repeat(not Radio.repeat))
	buttons.add_child(repeat_button)

	var volume_row := HBoxContainer.new()
	volume_row.alignment = BoxContainer.ALIGNMENT_CENTER
	volume_row.add_theme_constant_override("separation", 16)
	column.add_child(volume_row)
	var volume_name := UiStyle.label("Volume")
	volume_row.add_child(volume_name)
	volume_slider = HSlider.new()
	volume_slider.custom_minimum_size = Vector2(320, 0)
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.scrollable = false
	volume_slider.focus_mode = Control.FOCUS_NONE
	volume_row.add_child(volume_slider)
	var volume_shown := UiStyle.label("", UiStyle.text_font(), UiStyle.BODY, UiStyle.PAPER_MUTED)
	volume_shown.custom_minimum_size = Vector2(70, 0)
	volume_row.add_child(volume_shown)
	volume_slider.value_changed.connect(func(value: float) -> void:
		volume_shown.text = "%d%%" % roundi(value * 100.0)
		if not is_equal_approx(value, Radio.volume):
			Radio.set_volume(value))
	volume_slider.value = Radio.volume
	volume_shown.text = "%d%%" % roundi(Radio.volume * 100.0)

	# The song list sits in a well cut into the panel.
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", UiStyle.Well.new(Vector2(8, 8)))
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(well)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = LIST_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	well.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for index in Radio.songs.size():
		var song := _song_button()
		song.pressed.connect(Radio.play_song.bind(index))
		list.add_child(song)
		song_buttons.append(song)

	var back := MenuStyle.menu_button("Back")
	back.pressed.connect(close)
	column.add_child(back)

	Radio.changed.connect(refresh)
	refresh()
	visible = false


## A row of the song list: plain text on the well, a stone highlight under
## the pointer.
func _song_button() -> Button:
	var song := Button.new()
	song.focus_mode = Control.FOCUS_NONE
	song.alignment = HORIZONTAL_ALIGNMENT_LEFT
	song.add_theme_font_override("font", UiStyle.text_font())
	song.add_theme_font_size_override("font_size", UiStyle.SMALL)
	var empty := UiStyle.fill(Color(0, 0, 0, 0), 2, Vector2(12, 4))
	for state in ["normal", "disabled", "focus"]:
		song.add_theme_stylebox_override(state, empty)
	for state in ["hover", "pressed", "hover_pressed"]:
		song.add_theme_stylebox_override(state, UiStyle.fill(UiStyle.STONE, 2, Vector2(12, 4)))
	song.add_theme_color_override("font_disabled_color", UiStyle.PAPER_FAINT)
	return song


func _small_button(text: String, pressed: Callable) -> Button:
	var button := MenuStyle.menu_button(text)
	button.custom_minimum_size = SMALL_BUTTON
	button.pressed.connect(pressed)
	return button


func _process(_delta: float) -> void:
	if visible:
		_refresh_time()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Controls.RADIO) or (visible and event.is_action_pressed(Controls.PAUSE)):
		if visible:
			close()
		elif not get_tree().paused:
			open()
		else:
			return
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


func open() -> void:
	refresh()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Redraws what's playing, the buttons and the song list.
func refresh() -> void:
	if Radio.current >= 0:
		title_label.text = Radio.songs[Radio.current].title
	else:
		title_label.text = "Nothing playing"
	play_button.text = "Pause" if Radio.playing else "Play"
	repeat_button.text = "Repeat: On" if Radio.repeat else "Repeat: Off"
	for index in song_buttons.size():
		var button := song_buttons[index]
		if Radio.is_unlocked(index):
			button.text = "%s%02d   %s" % ["▶ " if index == Radio.current else "    ", index + 1, Radio.songs[index].title]
			button.disabled = false
			# The song that's playing is picked out in gilt.
			for state in ["font_color", "font_hover_color"]:
				button.add_theme_color_override(state, UiStyle.GILT if index == Radio.current else UiStyle.PAPER)
		else:
			button.text = "    %02d   ???" % (index + 1)
			button.disabled = true
	_refresh_time()


## "1:23 / 3:40", or the song count before anything's played.
func _refresh_time() -> void:
	if Radio.current < 0:
		time_label.text = "%d of %d songs unlocked" % [Radio.unlocked_count, Radio.songs.size()]
	else:
		time_label.text = "%s / %s" % [clock(Radio.position()), clock(Radio.length())]


static func clock(seconds: float) -> String:
	var whole := int(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]
