class_name Win95
extends RefCounted
## The laptop's look: a mid-90s desktop that has joined the game's family
## (style bible §10). The structure is Win95's (bevelled windows and
## buttons, title bars, taskbar, Start menu), but the chrome is pale warm
## stone, the title bars dark stone and the wallpaper the marbled paper,
## pixelated (tools/bake_laptop_wallpaper.py). Chrome is drawn in code
## (Bevel, a StyleBox). Sizes are in pixels at 1920 x 1080, like every
## menu; LINE is one "screen pixel" of the old look, drawn two pixels wide
## so it reads at that size.

const LINE := 2
## The screen glass: how dark a scanline is, how dark the corners get, and
## how long one swell of the shimmer takes.
const SCANLINE_ALPHA := 0.06
const VIGNETTE_ALPHA := 0.22
const SHIMMER_SECONDS := 2.5
## The marbled wallpaper's average colour (tools/bake_laptop_wallpaper.py
## prints it), for the screen's glow in the room.
const DESKTOP := Color8(135, 135, 131)
## The wallpaper: marbled paper at half size, 256 colours, drawn at 2x.
const WALLPAPER := preload("res://assets/ui/frames/marbled_laptop.png")
## Pale warm stone where Win95 had grey, with its light and shade.
const FACE := Color("cbc3b3")
const LIGHT := Color("dfd8ca")
const WHITE := Color("f6f1e6")
const SHADOW := Color("857b6c")
const DARK := UiStyle.INK
## Title bars: dark stone, lighter towards the right (Win95.title_shade()).
const TITLE := Color("2b2523")
const TITLE_INACTIVE := Color("6f665c")
const TEXT := UiStyle.INK
const TEXT_DISABLED := Color("857b6c")
## Selected rows and menu items: artifact stone with cream text.
const SELECTED := UiStyle.STONE
const FONT_SIZE := 20
const TITLE_FONT_SIZE := 20


## The edges of the old look, each two lines deep: outer then inner, top
## and left, then bottom and right.
enum Look {
	RAISED, ## A window or a button.
	PRESSED, ## A button held down, or a toggle that's on.
	SUNKEN, ## A text field, a list, the taskbar clock.
	FLAT, ## A plain fill (selection, title bar).
}


## A bevelled box: a fill and two lines of light and shade round it.
class Bevel:
	extends StyleBox

	var look := Look.RAISED
	var fill := FACE

	func _init(bevel_look := Look.RAISED, colour := FACE, margin := 8) -> void:
		look = bevel_look
		fill = colour
		content_margin_left = margin
		content_margin_right = margin
		content_margin_top = margin * 0.6
		content_margin_bottom = margin * 0.6

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		RenderingServer.canvas_item_add_rect(to_canvas_item, rect, fill)
		var edges := []
		match look:
			Look.RAISED:
				edges = [[WHITE, DARK], [LIGHT, SHADOW]]
			Look.PRESSED:
				edges = [[DARK, WHITE], [SHADOW, LIGHT]]
			Look.SUNKEN:
				edges = [[SHADOW, WHITE], [DARK, LIGHT]]
		var r := rect
		for pair in edges:
			Win95.edge(to_canvas_item, r, pair[0], pair[1])
			r = r.grow(-LINE)


## One ring of a bevel: `top_left` along the top and left, `bottom_right`
## along the bottom and right (it wins the corners).
static func edge(canvas: RID, r: Rect2, top_left: Color, bottom_right: Color) -> void:
	RenderingServer.canvas_item_add_rect(canvas, Rect2(r.position, Vector2(r.size.x, LINE)), top_left)
	RenderingServer.canvas_item_add_rect(canvas, Rect2(r.position, Vector2(LINE, r.size.y)), top_left)
	RenderingServer.canvas_item_add_rect(canvas, Rect2(r.position.x, r.end.y - LINE, r.size.x, LINE), bottom_right)
	RenderingServer.canvas_item_add_rect(canvas, Rect2(r.end.x - LINE, r.position.y, LINE, r.size.y), bottom_right)


static func bevel(look := Look.RAISED, colour := FACE, margin := 8) -> Bevel:
	return Bevel.new(look, colour, margin)


## The theme everything on the laptop screen inherits: black text, grey
## bevelled buttons, sunken scroll wells.
static func theme() -> Theme:
	var t := Theme.new()
	# The machine voice (style bible §5): a plain 90s system sans.
	t.default_font = UiStyle.machine_font()
	t.default_font_size = FONT_SIZE
	t.set_color("font_color", "Label", TEXT)
	for state in ["normal", "hover"]:
		t.set_stylebox(state, "Button", bevel(Look.RAISED, FACE, 14))
	t.set_stylebox("pressed", "Button", bevel(Look.PRESSED, FACE, 14))
	t.set_stylebox("hover_pressed", "Button", bevel(Look.PRESSED, FACE, 14))
	t.set_stylebox("disabled", "Button", bevel(Look.RAISED, FACE, 14))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for colour in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(colour, "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_DISABLED)
	t.set_stylebox("panel", "Panel", bevel(Look.RAISED))
	t.set_stylebox("panel", "PanelContainer", bevel(Look.RAISED))
	# Scroll bars: a dotted grey well with a raised thumb.
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, bevel(Look.FLAT, LIGHT, 0))
		t.set_stylebox("scroll_focus", bar, bevel(Look.FLAT, LIGHT, 0))
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			var thumb := bevel(Look.RAISED, FACE, 0)
			thumb.content_margin_left = 10
			thumb.content_margin_right = 10
			thumb.content_margin_top = 10
			thumb.content_margin_bottom = 10
			t.set_stylebox(state, bar, thumb)
	t.set_stylebox("background", "ProgressBar", bevel(Look.SUNKEN, WHITE, 4))
	t.set_stylebox("fill", "ProgressBar", bevel(Look.FLAT, SELECTED, 0))
	t.set_color("font_color", "ProgressBar", TEXT)
	return t


## The lighter right-hand end of a title bar (#2b2523 to #4a3f3c), laid
## over the bar's colour so it works for active and inactive bars alike.
static func title_shade() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 0.92, 0.88, 0.14))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 1
	var shade := TextureRect.new()
	shade.name = "Shade"
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shade


## The glass over the whole screen (style bible §10): faint scanlines,
## one dark line every other pixel row, a soft darkening into the corners
## and a slow shimmer. It takes no clicks.
static func crt_glass() -> Control:
	var glass := Control.new()
	glass.name = "Glass"
	glass.set_anchors_preset(Control.PRESET_FULL_RECT)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.process_mode = Node.PROCESS_MODE_ALWAYS
	var rows := Image.create(1, LINE * 2, false, Image.FORMAT_RGBA8)
	for y in LINE * 2:
		rows.set_pixel(0, y, Color(0, 0, 0, SCANLINE_ALPHA if y >= LINE else 0.0))
	var lines := TextureRect.new()
	lines.name = "Scanlines"
	lines.texture = ImageTexture.create_from_image(rows)
	lines.stretch_mode = TextureRect.STRETCH_TILE
	lines.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lines.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lines.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.add_child(lines)
	var falloff := Gradient.new()
	falloff.set_color(0, Color(0, 0, 0, 0))
	falloff.set_color(1, Color(0, 0, 0, VIGNETTE_ALPHA))
	falloff.add_point(0.55, Color(0, 0, 0, 0))
	var round_texture := GradientTexture2D.new()
	round_texture.gradient = falloff
	round_texture.fill = GradientTexture2D.FILL_RADIAL
	round_texture.fill_from = Vector2(0.5, 0.5)
	round_texture.fill_to = Vector2(1.2, 1.2)
	round_texture.width = 256
	round_texture.height = 256
	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	vignette.texture = round_texture
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.add_child(vignette)
	glass.ready.connect(func() -> void:
		var tween := glass.create_tween().set_loops()
		tween.tween_property(lines, "modulate:a", 0.6, SHIMMER_SECONDS).set_trans(Tween.TRANS_SINE)
		tween.tween_property(lines, "modulate:a", 1.0, SHIMMER_SECONDS).set_trans(Tween.TRANS_SINE))
	return glass


## A label in the laptop's text colour, wrapping to its width.
static func label(text: String, font_size := FONT_SIZE, colour := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A grey push button. Mouse-only, like every menu: it never takes focus.
static func button(text: String, pressed: Callable = Callable(), min_width := 120) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_width, 40)
	if pressed.is_valid():
		b.pressed.connect(pressed)
	return b


## Makes `b` exactly `height` tall, its text centred in it. A button's
## own minimum height is its text's line plus the bevel's margins, which
## outgrows a short bar and pokes out of its bottom; with no top or bottom
## margin the text sits centred in whatever height it's given.
static func snug(b: Button, height: int) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var look := Look.PRESSED if state.ends_with("pressed") else Look.RAISED
		var box := bevel(look, FACE, 14)
		box.content_margin_top = 0
		box.content_margin_bottom = 0
		b.add_theme_stylebox_override(state, box)
	b.custom_minimum_size.y = height


## A sunken white well (a list or a page of text) round `content`.
static func well(content: Control, colour := WHITE) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bevel(Look.SUNKEN, colour, 10))
	panel.add_child(content)
	return panel
