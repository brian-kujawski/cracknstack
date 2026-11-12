class_name AchievementsScreen
extends RefCounted
## The Achievements page, opened from the main menu and the pause menu:
## grids of tiles, five across. Each tile is a square icon with a title and
## a line under it: ??? and "This achievement is locked." with the locked
## icon until it's earned, then its name, what it was for and the full icon.
## The rare card achievements come first, the wall art's under those, then
## the two for the banned cards, and the odd ones out last.

const ICON_SIZE := 96
const TILE_WIDTH := 272
const COLUMNS := 5
const TEXT_LINE_HEIGHT := 26
## Stone round a tile's contents.
const PADDING := 18


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


## One achievement: a stone tile (bible §6.3) with the icon set in a
## sunken frame, the title and the explainer, centred. Locked tiles are
## dimmer stone with faint lettering.
static func tile(index: int) -> VBoxContainer:
	var unlocked := Achievements.is_unlocked(index)
	var box := Tile.new()
	box.name = "Achievement%03d" % Achievements.icon_number(index)
	box.custom_minimum_size.x = TILE_WIDTH
	box.add_theme_constant_override("separation", 6)
	var stone := UiStyle.Frame.new(0.0, Vector2.ZERO)
	stone.offset = UiStyle.stone_offset(box.name)
	box.stone = stone if unlocked else stone.varied(UiStyle.Frame.Look.FLAT, Color(0.62, 0.6, 0.6))
	box.add_child(_gap(PADDING))
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = Achievements.icon(index)
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	box.icon = icon
	box.add_child(_gap(4))
	var title := UiStyle.label(Achievements.title(index), UiStyle.text_font(600), UiStyle.SMALL,
		UiStyle.GILT if unlocked else UiStyle.PAPER_FAINT)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadow(title)
	box.add_child(title)
	var text := UiStyle.label(Achievements.description(index), UiStyle.text_font(), UiStyle.CAPTION,
		UiStyle.PAPER if unlocked else UiStyle.PAPER_MUTED)
	text.name = "Text"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Room for two lines on every tile, so the rows line up across columns.
	text.custom_minimum_size = Vector2(TILE_WIDTH - 2 * PADDING, 2 * TEXT_LINE_HEIGHT)
	text.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_shadow(text)
	box.add_child(text)
	box.add_child(_gap(PADDING - 6))
	return box


static func _gap(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


## A dark drop shadow, so small lettering reads on the stone.
static func _shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)


## A tile draws its stone behind its column, and a sunken frame round the
## icon, so the hand-drawn art shares an edge with the UI.
class Tile:
	extends VBoxContainer

	var stone: StyleBox
	var icon: Control

	func _init() -> void:
		sort_children.connect(queue_redraw)

	func _draw() -> void:
		draw_style_box(stone, Rect2(Vector2.ZERO, size))
		var well := Rect2(icon.position, icon.size).grow(4)
		draw_rect(well, UiStyle.BORDER)
		UiStyle.bevel(get_canvas_item(), well.grow(2), Color(0, 0, 0, 0.5), Color(1, 1, 1, 0.16))
