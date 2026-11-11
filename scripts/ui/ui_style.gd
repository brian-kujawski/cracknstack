class_name UiStyle
extends RefCounted
## The style bible in code (/mnt/project-files/plan/style-bible.md): every
## colour, type size, font, surface and duration the UI uses. "Stained glass
## in a stone frame": the cards are the coloured glass, everything else is
## the dark stone that holds it. One frame for everything (artifact stone),
## the five colours only as small accents, gold only for value.
##
## Sizes are pixels at 1920 x 1080; the whole UI scales from there. Screens
## take their look from here (directly, or through MenuStyle and HudStyle)
## and from the theme() every Control inherits, so nothing else names a
## colour or a font size.

# --- Colour (bible §4) ---

## The black of the old cards' borders: the outer edge of every frame and
## full-screen backdrops.
const BORDER := Color("121011")
## Inside of dark windows (HUD panels, menus).
const GROUND := Color("1b1817")
## Rows, wells and tabs at rest.
const GROUND_RAISED := Color("26211f")

const PAPER := Color("f1ead8")
const PAPER_MUTED := Color("c8bfaa")
const PAPER_FAINT := Color("8c8474")
## Text on light plaques, gold fills and keycaps.
const INK := Color("1a1612")

## The artifact stone, the average of assets/ui/frames/stone.png.
const STONE := Color("4e413f")
const STONE_LIGHT := Color("6b5a57")
const STONE_DARK := Color("332a29")
const PLAQUE := Color("d6d0c1")
## Captions and progress: the gilt that's always on a binder spine.
const GILT := Color("d9b45a")
## Earned value only: Needed, a big pull, a full binder, a level up.
const GLEAM := Color("f0cf73")

## The few places colour appears (bible §4.4).
const MANA := Color("5b9bd5")
const GAIN := Color("5fa86a")
## A pull's colour moment, by the card's colour (bible §7): W U B R G,
## multicolour and colourless.
const PULL_COLOURS := {
	"W": Color("f4ecd0"), "U": Color("5b9bd5"), "B": Color("9c8ca8"), "R": Color("d9643e"),
	"G": Color("5fa86a"), "multi": Color("f0cf73"), "colourless": Color("c9c4ba"),
}

# --- Type (bible §5) ---

const MICRO := 16
const CAPTION := 18
const SMALL := 20
const BODY := 24
const LEAD := 30
const TITLE := 38
const HEADING := 52
const DISPLAY := 76
const HERO := 120

const _GARAMOND := preload("res://assets/fonts/EBGaramond.ttf")
const _GARAMOND_ITALIC := preload("res://assets/fonts/EBGaramond-Italic.ttf")
const _ALMENDRA := preload("res://assets/fonts/Almendra-Regular.ttf")
const _ALMENDRA_ITALIC := preload("res://assets/fonts/Almendra-Italic.ttf")
const _ALMENDRA_SC := preload("res://assets/fonts/AlmendraSC-Regular.ttf")
const _SOURCE_SANS := preload("res://assets/fonts/SourceSans3.ttf")

# --- Surfaces (bible §6, §8) ---

const STONE_TEXTURE := preload("res://assets/ui/frames/stone.png")
const PLAQUE_TEXTURE := preload("res://assets/ui/frames/plaque.png")
const MARBLED_TEXTURE := preload("res://assets/ui/frames/marbled.png")
## The bevel where frame meets window, and the black outer edge.
const BEVEL := 2
const EDGE := 2
const RADIUS := 6

# --- Motion (bible §7) ---

const QUICK := 0.12
const EASE := 0.25
const SLOW := 0.6
const MOMENT := 1.5

static var _fonts := {}
static var _theme: Theme
static var _icons := {}


## The name voice (Almendra): headings, names, menu buttons. 30 px and up.
static func name_font() -> Font:
	return _ALMENDRA


static func name_italic() -> Font:
	return _ALMENDRA_ITALIC


## Almendra SC: screen headings and the wordmark.
static func name_caps() -> Font:
	return _ALMENDRA_SC


## The text voice (EB Garamond) at a weight, with lining tabular figures so
## counts don't wobble.
static func text_font(weight := 500) -> Font:
	return _variation("text%d" % weight, _GARAMOND, weight, {"lnum": 1, "tnum": 1})


static func text_italic(weight := 500) -> Font:
	return _variation("italic%d" % weight, _GARAMOND_ITALIC, weight, {})


## Captions: EB Garamond 600 capitals, tracked. (Not the font's true small
## caps: those turn figures into old-style ones, so "Chapter 1" read as
## "Chapter I".) Callers pass the text in capitals.
static func caption_font() -> Font:
	if not _fonts.has("caption"):
		var f := _variation("caption", _GARAMOND, 600, {"lnum": 1, "tnum": 1}) as FontVariation
		f.spacing_glyph = 2
		_fonts["caption"] = f
	return _fonts["caption"]


## The machine voice (Source Sans 3): the laptop screen, printed labels, keycaps.
static func machine_font(weight := 400) -> Font:
	return _variation("machine%d" % weight, _SOURCE_SANS, weight, {})


## The machine voice with tabular (even-width) figures, for readouts.
static func machine_mono(weight := 600) -> Font:
	return _variation("mono%d" % weight, _SOURCE_SANS, weight, {"tnum": 1})


static func _variation(key: String, base: Font, weight: int, features: Dictionary) -> FontVariation:
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = base
		var ts := TextServerManager.get_primary_interface()
		f.variation_opentype = {ts.name_to_tag("wght"): weight}
		var tags := {}
		for feature in features:
			tags[ts.name_to_tag(feature)] = features[feature]
		f.opentype_features = tags
		_fonts[key] = f
	return _fonts[key]


## A label in one of the voices.
static func label(text := "", font: Font = null, font_size := BODY, colour := PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font != null else text_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A frame (bible §6.1): the black edge, a band of stone, a bevel, then a
## dark window (or a cream plaque). `band` 0 makes a solid stone tablet
## (buttons). Each frame can start the stone at its own `offset`, so panels
## side by side don't show the same patch of stone.
class Frame:
	extends StyleBox

	enum Look { RAISED, PRESSED, FLAT }

	var band := 12.0
	var look := Look.RAISED
	## The window inside the band: GROUND by default; a clear colour leaves
	## the stone showing (a solid tablet).
	var window := UiStyle.GROUND
	var plaque := false
	var offset := Vector2.ZERO
	## Multiplies the stone (lighter on hover, dimmer when disabled).
	var tint := Color.WHITE
	## A soft light round the frame (gold for earned value), if glow_size > 0.
	var glow := Color(0, 0, 0, 0)
	var glow_size := 0
	var _edge: StyleBoxFlat

	func _init(band_width := 12.0, padding := Vector2(24, 20), frame_look := Look.RAISED) -> void:
		band = band_width
		look = frame_look
		content_margin_left = UiStyle.EDGE + band + padding.x
		content_margin_right = UiStyle.EDGE + band + padding.x
		content_margin_top = UiStyle.EDGE + band + padding.y
		content_margin_bottom = UiStyle.EDGE + band + padding.y
		_edge = StyleBoxFlat.new()
		_edge.bg_color = UiStyle.BORDER
		_edge.set_corner_radius_all(UiStyle.RADIUS)
		_edge.shadow_color = Color(0, 0, 0, 0.45)
		_edge.shadow_size = 10
		_edge.shadow_offset = Vector2(0, 4)

	## A copy with another look, tint or offset (a button's states).
	func varied(new_look: Look, new_tint := Color.WHITE) -> Frame:
		var f := Frame.new(band)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			f.set_content_margin(side, get_content_margin(side))
		f._edge = _edge
		f.window = window
		f.plaque = plaque
		f.offset = offset
		f.look = new_look
		f.tint = new_tint
		f.glow = glow
		f.glow_size = glow_size
		return f

	func _draw(item: RID, rect: Rect2) -> void:
		if glow_size > 0:
			var light := StyleBoxFlat.new()
			light.bg_color = Color(glow, 0.0)
			light.set_corner_radius_all(UiStyle.RADIUS)
			light.shadow_color = glow
			light.shadow_size = glow_size
			light.draw(item, rect)
		var stone := rect.grow(-UiStyle.EDGE)
		RenderingServer.canvas_item_set_default_texture_repeat(item, RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
		if band > 0.0 and window.a < 1.0 and not plaque:
			# A see-through window (Settings' Graphics tab over the shop): only
			# the edge and the band are solid, so the room shows inside.
			_draw_open(item, rect, stone)
		else:
			_edge.draw(item, rect)
			RenderingServer.canvas_item_add_texture_rect_region(item, stone, UiStyle.STONE_TEXTURE.get_rid(),
				Rect2(offset, stone.size), tint)
		match look:
			Look.RAISED:
				UiStyle.bevel(item, stone, Color(1, 1, 1, 0.22), Color(0, 0, 0, 0.45))
			Look.PRESSED:
				UiStyle.bevel(item, stone, Color(0, 0, 0, 0.5), Color(1, 1, 1, 0.14))
		if band <= 0.0 or (window.a <= 0.0 and not plaque):
			return
		var inside := stone.grow(-band)
		if plaque:
			RenderingServer.canvas_item_add_texture_rect_region(item, inside, UiStyle.PLAQUE_TEXTURE.get_rid(),
				Rect2(offset * 0.7, inside.size))
		else:
			RenderingServer.canvas_item_add_rect(item, inside, window)
		# The window is cut into the stone: dark top-left, light bottom-right.
		UiStyle.bevel(item, inside, Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.16))


	func _draw_open(item: RID, rect: Rect2, stone: Rect2) -> void:
		var outline := StyleBoxFlat.new()
		outline.draw_center = false
		outline.border_color = UiStyle.BORDER
		outline.set_border_width_all(UiStyle.EDGE)
		outline.set_corner_radius_all(UiStyle.RADIUS)
		outline.draw(item, rect)
		var strips := [
			Rect2(stone.position, Vector2(stone.size.x, band)),
			Rect2(stone.position.x, stone.end.y - band, stone.size.x, band),
			Rect2(stone.position.x, stone.position.y + band, band, stone.size.y - 2 * band),
			Rect2(stone.end.x - band, stone.position.y + band, band, stone.size.y - 2 * band),
		]
		for strip: Rect2 in strips:
			RenderingServer.canvas_item_add_texture_rect_region(item, strip, UiStyle.STONE_TEXTURE.get_rid(),
				Rect2(offset + strip.position - stone.position, strip.size), tint)


## One ring of bevel round `r`, BEVEL wide: `top_left` along the top and
## left, `bottom_right` along the bottom and right.
static func bevel(item: RID, r: Rect2, top_left: Color, bottom_right: Color) -> void:
	RenderingServer.canvas_item_add_rect(item, Rect2(r.position, Vector2(r.size.x, BEVEL)), top_left)
	RenderingServer.canvas_item_add_rect(item, Rect2(r.position + Vector2(0, BEVEL), Vector2(BEVEL, r.size.y - BEVEL)), top_left)
	RenderingServer.canvas_item_add_rect(item, Rect2(r.position.x + BEVEL, r.end.y - BEVEL, r.size.x - BEVEL, BEVEL), bottom_right)
	RenderingServer.canvas_item_add_rect(item, Rect2(r.end.x - BEVEL, r.position.y + BEVEL, BEVEL, r.size.y - 2 * BEVEL), bottom_right)


## A panel's frame: a stone band round a dark window (or a plaque).
static func frame(band := 12.0, padding := Vector2(24, 20), seed_text := "") -> Frame:
	var f := Frame.new(band, padding)
	f.offset = stone_offset(seed_text)
	return f


## A reading plaque in a stone frame (notes, Instructions).
static func plaque_frame(band := 12.0, padding := Vector2(24, 20), seed_text := "") -> Frame:
	var f := frame(band, padding, seed_text)
	f.plaque = true
	return f


## Where in the stone a frame starts, from some text that names it, so the
## same panel always looks the same and neighbours differ.
static func stone_offset(seed_text: String) -> Vector2:
	var h := hash(seed_text)
	return Vector2(h % 509, (h / 509) % 503)


## Gives `button` the stone-tablet look: raised at rest, lighter on hover,
## pressed in when held, flat and dim when disabled.
static func stone_button(button: Button, font_size := LEAD, font: Font = null) -> void:
	var rest := Frame.new(0.0, Vector2(20, 6))
	rest.offset = stone_offset(button.text)
	button.add_theme_stylebox_override("normal", rest)
	button.add_theme_stylebox_override("hover", rest.varied(Frame.Look.RAISED, Color(1.28, 1.24, 1.2)))
	button.add_theme_stylebox_override("pressed", rest.varied(Frame.Look.PRESSED, Color(0.85, 0.82, 0.8)))
	button.add_theme_stylebox_override("hover_pressed", rest.varied(Frame.Look.PRESSED, Color(0.95, 0.92, 0.9)))
	button.add_theme_stylebox_override("disabled", rest.varied(Frame.Look.FLAT, Color(0.62, 0.6, 0.6)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_override("font", font if font != null else name_font())
	button.add_theme_font_size_override("font_size", font_size)
	_button_colours(button)


static func _button_colours(button: Control) -> void:
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color("fff6dc"))
	button.add_theme_color_override("font_pressed_color", PAPER_MUTED)
	button.add_theme_color_override("font_hover_pressed_color", PAPER)
	button.add_theme_color_override("font_disabled_color", PAPER_FAINT)
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 2)


## The theme every Control inherits (set on the root window by SceneFlow):
## the text voice in paper on dark, stone buttons, dark wells. Screens that
## want something else (the laptop's Win95 theme) set their own.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = text_font()
	t.default_font_size = BODY
	t.set_color("font_color", "Label", PAPER)
	var rest := Frame.new(0.0, Vector2(16, 6))
	t.set_stylebox("normal", "Button", rest)
	t.set_stylebox("hover", "Button", rest.varied(Frame.Look.RAISED, Color(1.28, 1.24, 1.2)))
	t.set_stylebox("pressed", "Button", rest.varied(Frame.Look.PRESSED, Color(0.85, 0.82, 0.8)))
	t.set_stylebox("hover_pressed", "Button", rest.varied(Frame.Look.PRESSED, Color(0.95, 0.92, 0.9)))
	t.set_stylebox("disabled", "Button", rest.varied(Frame.Look.FLAT, Color(0.62, 0.6, 0.6)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", text_font(600))
	for entry in [["font_color", PAPER], ["font_hover_color", Color("fff6dc")], ["font_pressed_color", PAPER_MUTED],
			["font_hover_pressed_color", PAPER], ["font_disabled_color", PAPER_FAINT], ["font_focus_color", PAPER]]:
		t.set_color(entry[0], "Button", entry[1])
	var panel := Frame.new(12.0)
	t.set_stylebox("panel", "PanelContainer", panel)
	# Dropdowns: stone tablets like the buttons, a paper chevron, and a
	# stone-framed list.
	var drop := Frame.new(0.0, Vector2(16, 6))
	drop.offset = stone_offset("dropdown")
	t.set_stylebox("normal", "OptionButton", drop)
	t.set_stylebox("hover", "OptionButton", drop.varied(Frame.Look.RAISED, Color(1.28, 1.24, 1.2)))
	t.set_stylebox("pressed", "OptionButton", drop.varied(Frame.Look.PRESSED, Color(0.85, 0.82, 0.8)))
	t.set_stylebox("hover_pressed", "OptionButton", drop.varied(Frame.Look.PRESSED, Color(0.95, 0.92, 0.9)))
	t.set_stylebox("disabled", "OptionButton", drop.varied(Frame.Look.FLAT, Color(0.62, 0.6, 0.6)))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_icon("arrow", "OptionButton", arrow_icon())
	t.set_font("font", "OptionButton", text_font(600))
	for entry in [["font_color", PAPER], ["font_hover_color", Color("fff6dc")], ["font_pressed_color", PAPER],
			["font_hover_pressed_color", PAPER], ["font_disabled_color", PAPER_FAINT], ["font_focus_color", PAPER]]:
		t.set_color(entry[0], "OptionButton", entry[1])
	var list := Frame.new(6.0, Vector2(6, 6))
	list.offset = stone_offset("list")
	t.set_stylebox("panel", "PopupMenu", list)
	t.set_stylebox("hover", "PopupMenu", fill(STONE, 2))
	t.set_font("font", "PopupMenu", text_font())
	t.set_color("font_color", "PopupMenu", PAPER)
	t.set_color("font_hover_color", "PopupMenu", Color("fff6dc"))
	t.set_color("font_disabled_color", "PopupMenu", PAPER_FAINT)
	t.set_constant("v_separation", "PopupMenu", 8)
	# Sliders: a sunken channel, gilt where it's filled, a stone grabber.
	t.set_stylebox("slider", "HSlider", Well.new(Vector2(0, 5)))
	t.set_stylebox("grabber_area", "HSlider", fill(GILT.darkened(0.15), 1, Vector2(0, 5)))
	t.set_stylebox("grabber_area_highlight", "HSlider", fill(GILT, 1, Vector2(0, 5)))
	t.set_icon("grabber", "HSlider", grabber_icon())
	t.set_icon("grabber_highlight", "HSlider", grabber_icon(true))
	t.set_icon("grabber_disabled", "HSlider", grabber_icon())
	# Checkboxes: a well, a gilt tablet when on.
	for state in [["checked", true, false], ["unchecked", false, false], ["checked_disabled", true, true], ["unchecked_disabled", false, true]]:
		t.set_icon(state[0], "CheckBox", check_icon(state[1], state[2]))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	# Scrollbars: a thin channel with a stone grabber.
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, Well.new(Vector2(5, 5), GROUND))
		t.set_stylebox("scroll_focus", bar, Well.new(Vector2(5, 5), GROUND))
		t.set_stylebox("grabber", bar, fill(STONE_LIGHT, 3))
		t.set_stylebox("grabber_highlight", bar, fill(STONE_LIGHT.lightened(0.15), 3))
		t.set_stylebox("grabber_pressed", bar, fill(STONE_LIGHT.lightened(0.25), 3))
	_theme = t
	return t


## A well cut into the stone (bible §6.4): a dark, sunken channel. Slider
## tracks, scrollbar channels, save rows and the radio's song list.
class Well:
	extends StyleBox

	var colour := UiStyle.GROUND_RAISED

	func _init(padding := Vector2(16, 10), fill := UiStyle.GROUND_RAISED) -> void:
		colour = fill
		content_margin_left = padding.x
		content_margin_right = padding.x
		content_margin_top = padding.y
		content_margin_bottom = padding.y

	func _draw(item: RID, rect: Rect2) -> void:
		RenderingServer.canvas_item_add_rect(item, rect, colour)
		UiStyle.bevel(item, rect, Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.12))


## A flat fill: a slider's gilt fill, a scrollbar's stone grabber, a hovered
## row.
static func fill(colour: Color, radius := 2, padding := Vector2.ZERO) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding.x
	box.content_margin_right = padding.x
	box.content_margin_top = padding.y
	box.content_margin_bottom = padding.y
	return box


## A checkbox (bible §6.4): a small sunken well, a gilt tablet in it when on.
static func check_icon(on: bool, disabled := false, side := 30) -> ImageTexture:
	var key := "check%d%d%d" % [int(on), int(disabled), side]
	if _icons.has(key):
		return _icons[key]
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(BORDER)
	image.fill_rect(Rect2i(1, 1, side - 2, side - 2), GROUND_RAISED)
	_bevel_image(image, Rect2i(1, 1, side - 2, side - 2), Color(0, 0, 0, 0.6), Color(1, 1, 1, 0.14))
	if on:
		var inner := Rect2i(7, 7, side - 14, side - 14)
		image.fill_rect(inner, GILT)
		_bevel_image(image, inner, Color(1, 1, 1, 0.45), Color(0, 0, 0, 0.35))
	if disabled:
		for x in side:
			for y in side:
				var c := image.get_pixel(x, y)
				image.set_pixel(x, y, Color(c, c.a * 0.4))
	_icons[key] = ImageTexture.create_from_image(image)
	return _icons[key]


## A slider's grabber: a small raised stone tablet.
static func grabber_icon(lit := false) -> ImageTexture:
	var key := "grabber%d" % int(lit)
	if _icons.has(key):
		return _icons[key]
	var image := Image.create(18, 30, false, Image.FORMAT_RGBA8)
	image.fill(BORDER)
	var face := Rect2i(1, 1, 16, 28)
	image.fill_rect(face, STONE_LIGHT.lightened(0.18) if lit else STONE_LIGHT)
	_bevel_image(image, face, Color(1, 1, 1, 0.35), Color(0, 0, 0, 0.45))
	image.fill_rect(Rect2i(8, 8, 2, 14), Color(0, 0, 0, 0.35))
	_icons[key] = ImageTexture.create_from_image(image)
	return _icons[key]


## A dropdown's arrow: a small downward chevron in paper.
static func arrow_icon() -> ImageTexture:
	if _icons.has("arrow"):
		return _icons["arrow"]
	var image := Image.create(16, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in 8:
		for x in range(y, 16 - y):
			image.set_pixel(x, y + 1, PAPER_MUTED)
	_icons["arrow"] = ImageTexture.create_from_image(image)
	return _icons["arrow"]


static func _bevel_image(image: Image, r: Rect2i, top_left: Color, bottom_right: Color) -> void:
	for i in r.size.x:
		for j in BEVEL:
			_blend(image, r.position.x + i, r.position.y + j, top_left)
			_blend(image, r.position.x + i, r.end.y - 1 - j, bottom_right)
	for i in range(BEVEL, r.size.y - BEVEL):
		for j in BEVEL:
			_blend(image, r.position.x + j, r.position.y + i, top_left)
			_blend(image, r.end.x - 1 - j, r.position.y + i, bottom_right)


static func _blend(image: Image, x: int, y: int, over: Color) -> void:
	image.set_pixel(x, y, image.get_pixel(x, y).blend(over))


## Marbled paper (bible §8) filling its rect: the tile turned by
## `quarter_turns`, mirrored or not, shifted by `offset`, at `tile_scale`,
## and drifting very slowly by `drift` pixels a second. Each use picks its
## own orientation so it never looks the same twice.
class Marbled:
	extends Control

	var quarter_turns := 0
	var mirrored := false
	var offset := Vector2.ZERO
	var tile_scale := 1.0
	var drift := Vector2.ZERO
	var texture: Texture2D = UiStyle.MARBLED_TEXTURE

	func _init(turns := 0, mirror := false, shift := Vector2.ZERO, scale_by := 1.0, drift_by := Vector2.ZERO) -> void:
		quarter_turns = turns
		mirrored = mirror
		offset = shift
		tile_scale = scale_by
		drift = drift_by
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(drift != Vector2.ZERO)

	func _process(delta: float) -> void:
		offset += drift * delta
		queue_redraw()

	func _draw() -> void:
		# Draw a square big enough to cover the rect at any quarter turn,
		# turned about the rect's centre; the texture repeats inside it.
		var centre := size / 2.0
		var side := size.length()
		var flip := Vector2(-1, 1) if mirrored else Vector2.ONE
		draw_set_transform(centre, quarter_turns * PI / 2.0, flip)
		var area := Rect2(Vector2(-side, -side) / 2.0, Vector2(side, side))
		draw_texture_rect_region(texture, area, Rect2(offset, area.size / tile_scale))
		draw_set_transform(Vector2.ZERO)


## Marbled paper behind a dark vignette: the title screen's backdrop.
static func marbled_backdrop(turns := 0, mirror := false, shift := Vector2.ZERO, scale_by := 1.0, drift := Vector2.ZERO, darkness := 0.56) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var paper := Marbled.new(turns, mirror, shift, scale_by, drift)
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(paper)
	var dim := ColorRect.new()
	dim.color = Color(BORDER, darkness)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var vignette := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(BORDER, 0.1))
	gradient.set_color(1, Color(BORDER, 0.92))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	vignette.texture = tex
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)
	return root
