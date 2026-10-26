class_name AchievementsScreen
extends RefCounted
## The Achievements page, opened from the main menu and the pause menu: a
## grid of tiles, one column per colour in the upgrade tree's order (white,
## blue, black, red, green). Each tile is a square icon with a title and a
## line under it: ??? and "This achievement is locked." with the locked icon
## until it's earned, then the card's name, what it was for and the full
## icon. The rare card achievements, which have no colour, follow in rows
## under the columns.

const ICON_SIZE := 96
const TILE_WIDTH := 280
const COLOUR_COUNT := 5
const TEXT_LINE_HEIGHT := 28


static func make() -> MenuScreen:
	var screen := MenuScreen.new("Achievements")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.content.add_child(scroll)
	var sections := VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 40)
	scroll.add_child(sections)
	var columns := HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	sections.add_child(columns)
	var rare := GridContainer.new()
	rare.name = "RareCards"
	rare.columns = COLOUR_COUNT
	rare.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rare.add_theme_constant_override("h_separation", 24)
	rare.add_theme_constant_override("v_separation", 20)
	sections.add_child(rare)
	var by_colour: Array[VBoxContainer] = []
	for colour in COLOUR_COUNT:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 20)
		columns.add_child(column)
		by_colour.append(column)
	for index in Achievements.count():
		if Achievements.is_rare(index):
			rare.add_child(tile(index))
		else:
			by_colour[Achievements.colour(index)].add_child(tile(index))
	return screen


## One achievement: icon, title and explainer, centred.
static func tile(index: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Achievement%03d" % (index + 1)
	box.custom_minimum_size.x = TILE_WIDTH
	box.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = Achievements.icon(index)
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var title := MenuStyle.heading(Achievements.title(index), 20)
	title.name = "Title"
	box.add_child(title)
	var text := Label.new()
	text.name = "Text"
	text.text = Achievements.description(index)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Room for two lines on every tile, so the rows line up across columns.
	text.custom_minimum_size = Vector2(TILE_WIDTH, 2 * TEXT_LINE_HEIGHT)
	text.add_theme_font_size_override("font_size", MenuStyle.SMALL_FONT_SIZE)
	text.modulate = Color(1, 1, 1, 0.7)
	box.add_child(text)
	return box
