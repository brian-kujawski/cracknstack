class_name MenuStyle
extends RefCounted
## The look every menu shares: the dark brown backdrop, headings and the
## buttons in a menu's column. Sizes are in pixels at 1920 × 1080; the
## project stretches the whole UI to fit the window (canvas_items, expand),
## so every menu scales with the resolution. A stand-in until M4c picks the real font and
## theme, kept in one place so that change is one file.

const BACKDROP := Color(0.07, 0.05, 0.04, 0.92)
## The title screen has nothing behind it, so it's fully opaque.
const TITLE_BACKDROP := Color(0.07, 0.05, 0.04, 1.0)
const BUTTON_SIZE := Vector2(300, 56)
const BUTTON_FONT_SIZE := 24
const SMALL_FONT_SIZE := 18


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


static func heading(text: String, font_size := 72) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


## One of a menu's buttons, all the same width. Menus are mouse-only: no
## button takes keyboard focus, so none is ever outlined. Disabled ones
## (Continue and Load Game until saves exist) are dimmed.
static func menu_button(text: String, enabled := true) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_NONE
	return button

