class_name Win95
extends RefCounted
## The laptop's look: a mid-90s desktop. Grey bevelled windows and buttons,
## navy title bars, a teal desktop. Everything is drawn in code (Bevel, a
## StyleBox), so there are no images to keep. Sizes are in pixels at
## 1920 x 1080, like every menu; LINE is one "screen pixel" of the old
## look, drawn two pixels wide so it reads at that size.

const LINE := 2
const DESKTOP := Color8(0, 128, 128)
const FACE := Color8(192, 192, 192)
const LIGHT := Color8(223, 223, 223)
const WHITE := Color8(255, 255, 255)
const SHADOW := Color8(128, 128, 128)
const DARK := Color8(0, 0, 0)
const TITLE := Color8(0, 0, 128)
const TITLE_INACTIVE := Color8(128, 128, 128)
const TEXT := Color8(0, 0, 0)
const TEXT_DISABLED := Color8(128, 128, 128)
const SELECTED := Color8(0, 0, 128)
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
	t.set_stylebox("fill", "ProgressBar", bevel(Look.FLAT, TITLE, 0))
	t.set_color("font_color", "ProgressBar", TEXT)
	return t


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
