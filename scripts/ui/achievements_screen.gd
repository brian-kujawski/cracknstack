class_name AchievementsScreen
extends RefCounted
## The Achievements page, opened from the main menu and the pause menu:
## grids of tiles, five across. Each tile is a square icon with a title and
## a line under it: ??? and "This achievement is locked." with the locked
## icon until it's earned, then its name, what it was for and the full icon.
## The rare card achievements come first, the wall art's under those, then
## the two for the banned cards, and the odd ones out last.

const ICON_SIZE := 96
const TILE_WIDTH := 280
const COLUMNS := 5
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
	var grids := {}
	for grid_name in ["RareCards", "WallArt", "BannedCards", "Other"]:
		var grid := GridContainer.new()
		grid.name = grid_name
		grid.columns = COLUMNS
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 20)
		sections.add_child(grid)
		grids[grid_name] = grid
	for index in Achievements.count():
		if Achievements.is_rare(index):
			grids.RareCards.add_child(tile(index))
		elif Achievements.is_wall_art(index):
			grids.WallArt.add_child(tile(index))
		elif Achievements.is_banned(index):
			grids.BannedCards.add_child(tile(index))
		else:
			grids.Other.add_child(tile(index))
	return screen


## One achievement: icon, title and explainer, centred.
static func tile(index: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Achievement%03d" % Achievements.icon_number(index)
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
