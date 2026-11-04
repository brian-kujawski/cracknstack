class_name HudStyle
extends RefCounted
## The in-game HUD's look (thread "Redesign the in-game HUD", mockups on the
## HUD drafts canvas): near-black plates with a thin gold rule, cream text,
## gold small capitals for labels, EB Garamond for card names and big
## moments, keycaps for the few key prompts. It echoes the shelf nameplates
## and the gilt binder lettering. Sizes are pixels at 1920 × 1080; the whole
## UI scales with the window and the Interface size setting.

const SERIF := preload("res://assets/fonts/EBGaramond.ttf")
const SERIF_WEIGHT := 600

const PLATE := Color(0.063, 0.051, 0.039, 0.86)
const GOLD := Color(0.722, 0.576, 0.247)
const GOLD_FAINT := Color(0.722, 0.576, 0.247, 0.4)
const GOLD_BRIGHT := Color(0.925, 0.788, 0.416)
const GOLD_TEXT := Color(0.851, 0.706, 0.353)
const TEXT := Color(0.953, 0.914, 0.824)
const MUTED := Color(0.788, 0.737, 0.624)
const INK := Color(0.102, 0.071, 0.035)
const GAIN := Color(0.624, 0.878, 0.651)
const BAR_BACK := Color(1, 1, 1, 0.14)
const MANA := Color(0.42, 0.62, 0.9)
const KEYCAP := Color(0.953, 0.914, 0.824)
const KEYCAP_SHADOW := Color(0.561, 0.506, 0.4)

## Distance of the corner plates from the screen's edges.
const EDGE := Vector2(32, 28)
const FONT_SIZE := 22
const SMALL_FONT_SIZE := 20
const LABEL_FONT_SIZE := 21
const NAME_FONT_SIZE := 36
const BIG_NUMBER_SIZE := 38

## A small diamond in the rarity's colour sits beside the rarity's name
## (colour is never the only cue).
const RARITY_GEMS := [Color(0.11, 0.11, 0.11), Color(0.72, 0.77, 0.8), Color(0.83, 0.65, 0.25),
	Color(0.88, 0.4, 0.17)]

static var _serif: FontVariation


## EB Garamond at SERIF_WEIGHT, for card names and big moments.
static func serif() -> FontVariation:
	if _serif == null:
		_serif = FontVariation.new()
		_serif.base_font = SERIF
		_serif.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): SERIF_WEIGHT}
	return _serif


## The plate every HUD panel sits on: near black, a thin gold rule and a
## fainter gold line just inside it.
static func plate(padding := Vector2(22, 18)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PLATE
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
	return style


## A PanelContainer wearing plate(), holding a VBoxContainer (returned as
## the panel's only child, named "Lines").
static func plate_panel(separation := 12, padding := Vector2(22, 18)) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", plate(padding))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.add_theme_constant_override("separation", separation)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lines)
	return panel


static func label(text := "", font_size := FONT_SIZE, colour := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A gold label in small capitals ("CHAPTER 1"), for what a number counts.
static func caption(text := "", font_size := LABEL_FONT_SIZE) -> Label:
	var l := label(text.to_upper(), font_size - 3, GOLD_TEXT)
	l.add_theme_constant_override("line_spacing", 0)
	return l


## A card's or a moment's name, in the serif.
static func name_label(text := "", font_size := NAME_FONT_SIZE, colour := TEXT) -> Label:
	var l := label(text, font_size, colour)
	l.add_theme_font_override("font", serif())
	return l


## A thin progress bar (gold, or Mana blue): a ProgressBar with no text.
static func bar(colour := GOLD_BRIGHT, height := 8) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = BAR_BACK
	back.set_corner_radius_all(int(height / 2.0))
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.set_corner_radius_all(int(height / 2.0))
	b.add_theme_stylebox_override("background", back)
	b.add_theme_stylebox_override("fill", fill)
	return b


## A caption on the left, a number on the right, and a bar under them:
## "CHAPTER 1 ........ 112 / 287". Returns the block; its children are
## named "Caption", "Count" and "Bar".
static func counter(caption_text: String, colour := GOLD_BRIGHT) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 7)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(row)
	var c := caption(caption_text)
	c.name = "Caption"
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(c)
	var count := label("", FONT_SIZE)
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


## A key drawn as a keycap: "E" on a cream key with a darker lip.
static func keycap(key: String, font_size := 20) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = KEYCAP
	style.set_corner_radius_all(6)
	style.border_color = KEYCAP_SHADOW
	style.border_width_bottom = 3
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	cap.add_theme_stylebox_override("panel", style)
	var l := label(key.to_upper() if key.length() == 1 else key, font_size, INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(l)
	cap.custom_minimum_size = Vector2(34, 34)
	return cap


## A row: a keycap and what it does. "[E] Open Binder"
static func key_row(key: String, action: String, font_size := 23) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := keycap(key)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	row.add_child(label(action, font_size))
	return row


## A rounded tag: filled gold for "Needed", an outline for "Duplicate".
static func chip(text: String, filled: bool) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(16)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	if filled:
		style.bg_color = Color(0.906, 0.78, 0.408)
	else:
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = Color(0.616, 0.573, 0.486)
		style.set_border_width_all(2)
	tag.add_theme_stylebox_override("panel", style)
	tag.add_child(label(text, 19, INK if filled else Color(0.894, 0.855, 0.769)))
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return tag


## A thin gold rule across a plate, between a block's own lines and the
## lines that come and go above it.
static func rule() -> ColorRect:
	var line := ColorRect.new()
	line.color = GOLD_FAINT
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
