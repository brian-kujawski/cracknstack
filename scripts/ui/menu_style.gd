class_name MenuStyle
extends RefCounted
## The look every menu shares, from the style bible (UiStyle): the dark
## backdrop, headings in the name voice (Almendra) and stone-tablet buttons.
## Sizes are in pixels at 1920 × 1080; the project stretches the whole UI to
## fit the window (canvas_items, expand), so every menu scales with the
## resolution.

## Over the game: the shop shows faintly through.
const BACKDROP := Color(UiStyle.BORDER, 0.82)
## The title screen and full pages have nothing behind them.
const TITLE_BACKDROP := Color(UiStyle.BORDER, 1.0)
const BUTTON_SIZE := Vector2(340, 60)
const BUTTON_FONT_SIZE := UiStyle.LEAD
const SMALL_FONT_SIZE := UiStyle.SMALL


## A full-screen backdrop that takes every click, so nothing reaches what's
## underneath.
static func backdrop(color := BACKDROP) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	return rect


## A column centred on the screen, for a heading and its buttons.
static func centred_column(separation := 20) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", separation)
	return column


## A stone-framed panel centred on the screen, holding a column (returned
## as the panel's only child, named "Column"). `seed_text` picks where in
## the stone the frame starts. A `reading` panel has a cream plaque for a
## window (notes), for dark ink text.
static func framed_column(separation := 14, seed_text := "", padding := Vector2(56, 36), reading := false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var frame := UiStyle.plaque_frame(14.0, padding, seed_text) if reading else UiStyle.frame(14.0, padding, seed_text)
	panel.add_theme_stylebox_override("panel", frame)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", separation)
	panel.add_child(column)
	return panel


## A screen heading: Almendra SC, so "Paused" reads as small capitals.
static func heading(text: String, font_size := UiStyle.HEADING) -> Label:
	var label := UiStyle.label(text, UiStyle.name_caps(), font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## A question or title line inside a panel: Almendra, not capitals.
static func question(text: String, font_size := UiStyle.TITLE) -> Label:
	var label := UiStyle.label(text, UiStyle.name_font(), font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## A line of explanation in the text voice.
static func line(text: String, font_size := UiStyle.BODY, colour := UiStyle.PAPER_MUTED) -> Label:
	var label := UiStyle.label(text, UiStyle.text_font(), font_size, colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## One of a menu's buttons, all the same width: a stone tablet with its
## label in Almendra. Menus are mouse-only: no button takes keyboard focus,
## so none is ever outlined. Disabled ones (Continue and Load Game until
## saves exist) are dimmed.
static func menu_button(text: String, enabled := true) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	UiStyle.stone_button(button, BUTTON_FONT_SIZE)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_NONE
	return button
