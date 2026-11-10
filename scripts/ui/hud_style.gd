class_name HudStyle
extends RefCounted
## The in-game HUD's look, from the style bible (UiStyle): plates are thin
## artifact-stone frames round a dark window the room shows faintly through,
## captions are gilt tracked capitals, lines and numbers are EB Garamond, and
## names and big moments are Almendra. Keycaps are beige 1993 keys in the
## machine voice. Placement and content follow the HUD redesign (thread
## "Redesign the in-game HUD"). Sizes are pixels at 1920 × 1080; the whole
## UI scales with the window and the Interface size setting.

## The plates' window: the dark ground, a little see-through.
const PLATE := Color(UiStyle.GROUND, 0.9)
## Value and progress: gilt; earned value: gleam.
const GOLD := UiStyle.GILT
const GOLD_FAINT := Color(UiStyle.GILT, 0.4)
const GOLD_BRIGHT := UiStyle.GLEAM
const GOLD_TEXT := UiStyle.GILT
const TEXT := UiStyle.PAPER
const MUTED := UiStyle.PAPER_MUTED
const INK := UiStyle.INK
const GAIN := UiStyle.GAIN
const MANA := UiStyle.MANA
## A 1993 keyboard's keys: beige with a darker lip (bible §6.4).
const KEYCAP := Color("e6dcc6")
const KEYCAP_SHADOW := Color("a89c82")

## Distance of the corner plates from the screen's edges.
const EDGE := Vector2(32, 28)
## The HUD's frame band: narrow, so it never gets heavy over the room.
const BAND := 7.0
const FONT_SIZE := UiStyle.BODY
const SMALL_FONT_SIZE := UiStyle.SMALL
const NAME_FONT_SIZE := UiStyle.TITLE
const BIG_NUMBER_SIZE := UiStyle.TITLE

## A small diamond in the rarity's colour sits beside the rarity's name
## (colour is never the only cue).
const RARITY_GEMS := [Color(0.11, 0.11, 0.11), Color(0.72, 0.77, 0.8), Color(0.83, 0.65, 0.25),
	Color(0.88, 0.4, 0.17)]


## The text voice at its HUD weight (kept for callers that want the font).
static func serif() -> Font:
	return UiStyle.text_font(600)


## The frame every HUD panel sits in: a narrow stone band, a bevel and a
## dark window. `seed_text` picks where in the stone it starts.
static func plate(padding := Vector2(20, 16), seed_text := "") -> UiStyle.Frame:
	var frame := UiStyle.frame(BAND, padding, seed_text)
	frame.window = PLATE
	return frame


## A PanelContainer wearing plate(), holding a VBoxContainer (returned as
## the panel's only child, named "Lines").
static func plate_panel(separation := 12, padding := Vector2(20, 16), seed_text := "") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", plate(padding, seed_text))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.add_theme_constant_override("separation", separation)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lines)
	return panel


## A line in the text voice (numbers line up: tabular figures).
static func label(text := "", font_size := FONT_SIZE, colour := TEXT) -> Label:
	return UiStyle.label(text, UiStyle.text_font(), font_size, colour)


## A number that matters (Money, the morning report): the text voice, bolder.
static func number(text := "", font_size := BIG_NUMBER_SIZE, colour := TEXT) -> Label:
	return UiStyle.label(text, UiStyle.text_font(600), font_size, colour)


## A gilt caption in tracked capitals ("CHAPTER 1"), for what a number
## counts.
static func caption(text := "", font_size := UiStyle.CAPTION) -> Label:
	var l := UiStyle.label(text.to_upper(), UiStyle.caption_font(), font_size, GOLD_TEXT)
	l.add_theme_constant_override("line_spacing", 0)
	return l


## A card's or a moment's name: the name voice (Almendra) at 30 px and up,
## the text voice below that.
static func name_label(text := "", font_size := NAME_FONT_SIZE, colour := TEXT) -> Label:
	var font := UiStyle.name_font() if font_size >= UiStyle.LEAD else UiStyle.text_font(600)
	return UiStyle.label(text, font, font_size, colour)


## A progress bar: a sunken channel, filled gilt (or Mana blue) with a
## faint highlight along the top.
static func bar(colour := GOLD, height := 10) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("background", UiStyle.Well.new(Vector2.ZERO, UiStyle.BORDER))
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.border_color = colour.lightened(0.35)
	fill.border_width_top = 2
	fill.expand_margin_top = -2
	fill.expand_margin_bottom = -2
	fill.expand_margin_left = -2
	b.add_theme_stylebox_override("fill", fill)
	return b


## A caption on the left, a number on the right, and a bar under them:
## "CHAPTER 1 ........ 112 / 287". Returns the block; its children are
## named "Caption", "Count" and "Bar".
static func counter(caption_text: String, colour := GOLD) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(row)
	var c := caption(caption_text)
	c.name = "Caption"
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(c)
	var count := label("", SMALL_FONT_SIZE)
	count.name = "Count"
	row.add_child(count)
	var b := bar(colour)
	b.name = "Bar"
	block.add_child(b)
	return block


## Fills a counter(): "done / total" and the bar.
static func set_counter(block: Control, done: int, total: int, extra := "") -> void:
	var count: Label = block.find_child("Count", true, false)
	count.text = "%d / %d%s" % [done, total, extra]
	var b: ProgressBar = block.find_child("Bar", true, false)
	b.max_value = maxi(total, 1)
	b.value = clampi(done, 0, maxi(total, 1))


## A key drawn as a keycap: "E" on a beige 1993 key with a darker lip, in
## the machine voice.
static func keycap(key: String, font_size := 20) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = KEYCAP
	style.set_corner_radius_all(5)
	style.border_color = KEYCAP_SHADOW
	style.border_width_bottom = 4
	style.border_width_right = 2
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	cap.add_theme_stylebox_override("panel", style)
	var l := UiStyle.label(key.to_upper() if key.length() == 1 else key, UiStyle.machine_font(600), font_size, INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(l)
	cap.custom_minimum_size = Vector2(34, 34)
	return cap


## A row: a keycap and what it does. "[E] Open Binder"
static func key_row(key: String, action: String, font_size := FONT_SIZE) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := keycap(key)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	row.add_child(label(action, font_size))
	return row


## A small gem-cut plaque (bible §6.4): gold for "Needed", artifact stone
## for "Duplicate".
static func chip(text: String, filled: bool) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	# One-step corners: cut like a gem rather than rounded.
	style.set_corner_radius_all(8)
	style.corner_detail = 1
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 1
	style.content_margin_bottom = 3
	style.bg_color = GOLD_BRIGHT if filled else UiStyle.STONE
	style.border_color = UiStyle.GILT.darkened(0.35) if filled else UiStyle.STONE_DARK
	style.border_width_bottom = 2
	style.border_width_right = 1
	tag.add_theme_stylebox_override("panel", style)
	tag.add_child(UiStyle.label(text, UiStyle.text_font(600), SMALL_FONT_SIZE, INK if filled else TEXT))
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return tag


## A thin bevelled groove across a plate, between a block's own lines and
## the lines that come and go above it.
static func rule() -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func() -> void:
		line.draw_rect(Rect2(0, 0, line.size.x, 1), Color(0, 0, 0, 0.6))
		line.draw_rect(Rect2(0, 1, line.size.x, 1), Color(1, 1, 1, 0.1)))
	return line


## The diamond beside a rarity's name.
static func gem(rarity: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(18, 18)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var diamond := ColorRect.new()
	diamond.color = RARITY_GEMS[clampi(rarity, 0, RARITY_GEMS.size() - 1)]
	diamond.size = Vector2(12, 12)
	diamond.position = Vector2(3, 3)
	diamond.pivot_offset = Vector2(6, 6)
	diamond.rotation = PI / 4
	diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(diamond)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return holder


## A small diamond fleuron with a groove either side (bible §6.4), drawn
## into `on` across its width at its vertical centre.
static func fleuron(on: Control) -> void:
	var c := on.size / 2
	for half: Rect2 in [Rect2(0, c.y - 1, c.x - 14, 1), Rect2(c.x + 14, c.y - 1, on.size.x - c.x - 14, 1)]:
		on.draw_rect(half, Color(0, 0, 0, 0.6))
		on.draw_rect(Rect2(half.position + Vector2(0, 1), half.size), Color(1, 1, 1, 0.1))
	on.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7),
		c + Vector2(-7, 0)]), GOLD)
