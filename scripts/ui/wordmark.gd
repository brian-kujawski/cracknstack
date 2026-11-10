class_name Wordmark
extends HBoxContainer
## CRACK & STACK as carved letters (style bible §9): Almendra SC cut into
## pale stone (a light edge top-left, a deep shadow bottom-right) with the
## ampersand as the one flourish, Almendra italic in gold. It says nothing
## about cards, keeping the title screen's secret.

const STONE_LETTERS := Color("b9ae9f")


func _init(font_size := UiStyle.HERO) -> void:
	name = "Wordmark"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", int(font_size * 0.18))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_carved("Crack", UiStyle.name_caps(), font_size, STONE_LETTERS, Color(1, 1, 1, 0.38), Color("0d0b0b")))
	var amp: Label = _carved("&", UiStyle.name_italic(), int(font_size * 1.05), UiStyle.GLEAM, Color("fff3c4"), Color("4a3a12"))
	amp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(amp)
	add_child(_carved("Stack", UiStyle.name_caps(), font_size, STONE_LETTERS, Color(1, 1, 1, 0.38), Color("0d0b0b")))


## A word cut into stone: the letters with their shadow down and right,
## and a highlight copy up and left drawn behind them.
static func _carved(text: String, font: Font, font_size: int, colour: Color, highlight: Color, shadow: Color) -> Label:
	var letters := UiStyle.label(text, font, font_size, colour)
	letters.add_theme_color_override("font_shadow_color", shadow)
	letters.add_theme_constant_override("shadow_offset_x", 3)
	letters.add_theme_constant_override("shadow_offset_y", 4)
	letters.add_theme_constant_override("shadow_outline_size", 2)
	var lit := UiStyle.label(text, font, font_size, highlight)
	lit.position = Vector2(-2, -2)
	lit.show_behind_parent = true
	letters.add_child(lit)
	return letters
