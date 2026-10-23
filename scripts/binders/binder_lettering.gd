class_name BinderLettering
extends RefCounted
## The lettering pressed into a binder's leather, like the title on a book:
## the set's name across the cover and up the spine, its number range under
## the cover title, and its code at the foot of the spine.
##
## Each piece of text is fitted to its panel (fit()): it never breaks inside
## a word, prefers one line, and shrinks or takes another line when the name
## is long. The fitted text is drawn once per binder into two coverage masks
## (cover and spine), which the leather shader (binder_leather.gdshader)
## presses into the leather, or gilds once the binder is complete.

const FONT := preload("res://assets/fonts/EBGaramond.ttf")
const WEIGHT := 600
## Extra space between capitals, as a fraction of the font size. Titles set
## in capitals read better a little open.
const TRACKING := 0.06
## Baseline to baseline, in cap heights.
const LEADING := 1.6
## Mask pixels per metre (2 per millimetre).
const DENSITY := 2000.0

## Set names laid out by hand where the rules don't do well enough, by set
## code. A "\n" breaks the line there; the size is still fitted.
## e.g. "AFR": "Adventures in the\nForgotten Realms"
const TITLE_OVERRIDES := {}

## A line that ends on one of these reads as cut off ("Shadows over /
## Innistrad"), so those breaks are avoided when another does nearly as well.
const WEAK_ENDINGS := ["a", "an", "and", "at", "for", "from", "in", "of", "on", "over", "the", "to", "with"]
## How much an extra line has to gain in size to be worth it, and how much
## a weak ending costs. A name with a colon breaks after it ("Strixhaven: /
## School of Mages") unless that's far worse; any other break in it costs.
const EXTRA_LINE := 0.8
const WEAK_ENDING := 0.9
const AFTER_COLON := 1.1
const AWAY_FROM_COLON := 0.85
const MAX_LINES := 3

## The cover, in the binder's x, z (the top of the book is -z). The title
## sits in the upper part, the number range below it. The mask covers both.
const COVER_TITLE := Rect2(-0.094, -0.118, 0.188, 0.1)
const COVER_TITLE_CAP := Vector2(0.006, 0.019)
const COVER_NUMBERS_Z := 0.012
const COVER_NUMBERS_CAP := 0.0055
const COVER_MASK := Rect2(-0.104, -0.124, 0.208, 0.15)
## The spine, along z: the title runs top to bottom between the two raised
## bands, and the set code sits across the spine below the lower band.
const SPINE_TITLE := Vector2(-0.119, 0.119)
const SPINE_MARGIN := 0.0075
const SPINE_TITLE_CAP := Vector2(0.004, 0.0125)
const SPINE_CODE_Z := 0.1495
const SPINE_CODE_CAP := 0.0055
const SPINE_MASK := Vector2(-0.124, 0.163)

static var _font: FontVariation
static var _cap_ratio := 0.0
## Word widths in cap heights, measured once each (fit() tries many lines
## made of the same words).
static var _word_widths := {}


## The cover and spine masks for one set's binder, as [cover, spine]
## textures (single channel, 1 = letter).
static func masks(set_data: SetData, binder: BinderRange, thickness: float) -> Array[ImageTexture]:
	var title := title_text(set_data)
	var cover := _blank(COVER_MASK.size)
	var fitted := fit(title, COVER_TITLE.size, COVER_TITLE_CAP)
	_draw_block(cover, fitted.lines, fitted.cap, (COVER_TITLE.get_center() - COVER_MASK.position) * DENSITY)
	var numbers := "%s – %s" % [set_data.number_text(binder.first), set_data.number_text(binder.last)]
	_draw_block(cover, PackedStringArray([numbers]), COVER_NUMBERS_CAP,
		(Vector2(0, COVER_NUMBERS_Z) - COVER_MASK.position) * DENSITY)

	# The spine mask runs along z (left to right) with the front cover (+y)
	# at the top, so the title is drawn as it reads.
	var spine := _blank(Vector2(SPINE_MASK.y - SPINE_MASK.x, thickness))
	var across := thickness - 2 * SPINE_MARGIN
	var spine_title := fit(title, Vector2(SPINE_TITLE.y - SPINE_TITLE.x, across), SPINE_TITLE_CAP, 2)
	_draw_block(spine, spine_title.lines, spine_title.cap,
		Vector2((SPINE_TITLE.x + SPINE_TITLE.y) / 2 - SPINE_MASK.x, thickness / 2) * DENSITY)
	# The code reads across the spine with the book standing up: drawn level
	# in its own image, then turned a quarter so its top faces the book's top.
	var code_size := Vector2(across, (SPINE_MASK.y - SPINE_TITLE.y) - 0.006)
	var code := _blank(code_size)
	var code_fit := fit(set_data.code, code_size, Vector2(0.003, SPINE_CODE_CAP), 1)
	_draw_block(code, code_fit.lines, code_fit.cap, code_size * DENSITY / 2)
	code.rotate_90(COUNTERCLOCKWISE)
	var at := Vector2(SPINE_CODE_Z - SPINE_MASK.x, thickness / 2) * DENSITY - Vector2(code.get_size()) / 2
	spine.blend_rect(code, Rect2i(Vector2i.ZERO, code.get_size()), Vector2i(at.round()))
	return [_texture(cover), _texture(spine)]


## The set's name as it's lettered: in capitals, or as laid out by hand.
static func title_text(set_data: SetData) -> String:
	return TITLE_OVERRIDES.get(set_data.code, set_data.name).to_upper()


## The best way to set `text` in a box (metres) with a cap height in
## `cap_range` (smallest, largest): {lines, cap}. Lines only break between
## words (or where the text has a "\n"). Fewer lines win unless more of them
## let the text be clearly bigger. If even the best layout needs letters
## smaller than the smallest cap height, it's used anyway, at that size.
static func fit(text: String, box: Vector2, cap_range: Vector2, max_lines := MAX_LINES) -> Dictionary:
	var layouts: Array[PackedStringArray] = []
	if "\n" in text:
		layouts.append(text.split("\n"))
	else:
		var words := text.split(" ", false)
		for count in range(1, mini(max_lines, words.size()) + 1):
			_split(words, count, PackedStringArray(), layouts)
	var best := {}
	var best_score := -1.0
	for lines in layouts:
		var widest := 0.0
		for line in lines:
			widest = maxf(widest, line_width(line))
		var cap := minf(cap_range.y, minf(box.x / widest, box.y / (1.0 + (lines.size() - 1) * LEADING)))
		var score := cap * pow(EXTRA_LINE, lines.size() - 1)
		for line in lines:
			if line.to_lower() in WEAK_ENDINGS:
				score *= WEAK_ENDING  # A line of just "of" or "over".
		for i in lines.size() - 1:
			var last_word := lines[i].get_slice(" ", lines[i].count(" "))
			if last_word.to_lower() in WEAK_ENDINGS:
				score *= WEAK_ENDING
			elif last_word.ends_with(":"):
				score *= AFTER_COLON
			elif ":" in text:
				score *= AWAY_FROM_COLON
		if score > best_score:
			best_score = score
			best = {lines = lines, cap = cap}
	return best


## How wide a line is, in cap heights: its words, and a tracked space
## between each two.
static func line_width(line: String) -> float:
	var words := line.split(" ", false)
	var width := _measure(" ") * (words.size() - 1)
	for word in words:
		width += _measure(word)
	return width


## How wide a word is set on its own, in cap heights, tracking included.
static func _measure(word: String) -> float:
	if not _word_widths.has(word):
		var size := 100
		var width := 0.0
		var glyphs := _shape(word, size)
		for glyph in glyphs:
			width += glyph.advance * glyph.repeat
		# A word's own letter spaces, plus the one after it (a space's
		# tracking, or the next word's).
		_word_widths[word] = (width + TRACKING * size * glyphs.size()) / (size * _cap())
	return _word_widths[word]


## Every way to put the remaining words on `count` more lines.
static func _split(words: PackedStringArray, count: int, done: PackedStringArray, out: Array[PackedStringArray]) -> void:
	if count == 1:
		var lines := done.duplicate()
		lines.append(" ".join(words))
		out.append(lines)
		return
	for take in range(1, words.size() - count + 2):
		var lines := done.duplicate()
		lines.append(" ".join(words.slice(0, take)))
		_split(words.slice(take), count - 1, lines, out)


## Draws lines of capitals `cap` metres high, each centred on `center`'s x,
## the block centred on its y (pixels).
static func _draw_block(image: Image, lines: PackedStringArray, cap: float, center: Vector2) -> void:
	# Font sizes are rounded down to even pixels, so binders share glyph
	# caches.
	var size := maxi(2 * floori(cap * DENSITY / _cap() / 2), 2)
	var cap_px := size * _cap()
	var pitch := cap_px * LEADING
	var top := center.y - (cap_px + pitch * (lines.size() - 1)) / 2
	for i in lines.size():
		var glyphs := _shape(lines[i], size)
		var width := TRACKING * size * maxi(glyphs.size() - 1, 0)
		for glyph in glyphs:
			width += glyph.advance * glyph.repeat
			TextServerManager.get_primary_interface().font_render_glyph(glyph.font_rid, Vector2i(glyph.font_size, 0), glyph.index)
		_draw_glyphs(image, glyphs, Vector2(center.x - width / 2, top + cap_px + pitch * i), TRACKING * size)


## Copies each glyph's coverage out of the font's glyph cache onto the image,
## starting at a baseline point.
static func _draw_glyphs(image: Image, glyphs: Array[Dictionary], pen: Vector2, tracking: float) -> void:
	var ts := TextServerManager.get_primary_interface()
	var pages := {}
	for glyph in glyphs:
		var size := Vector2i(glyph.font_size, 0)
		var page_index := ts.font_get_glyph_texture_idx(glyph.font_rid, size, glyph.index)
		if page_index >= 0:
			var key := [glyph.font_rid, size, page_index]
			if not pages.has(key):
				var page := ts.font_get_texture_image(glyph.font_rid, size, page_index)
				page.convert(Image.FORMAT_LA8)
				pages[key] = page
			var source := Rect2i(ts.font_get_glyph_uv_rect(glyph.font_rid, size, glyph.index))
			var at: Vector2 = pen + glyph.offset + ts.font_get_glyph_offset(glyph.font_rid, size, glyph.index)
			image.blend_rect(pages[key], source, Vector2i(at.round()))
		pen.x += glyph.advance * glyph.repeat + tracking


static func _shape(text: String, size: int) -> Array[Dictionary]:
	var line := TextLine.new()
	line.add_string(text, _variation(), size)
	return TextServerManager.get_primary_interface().shaped_text_get_glyphs(line.get_rid())


## Cap height as a fraction of the font size.
static func _cap() -> float:
	if _cap_ratio == 0.0:
		var glyphs := _shape("H", 200)
		var ts := TextServerManager.get_primary_interface()
		_cap_ratio = ts.font_get_glyph_size(glyphs[0].font_rid, Vector2i(200, 0), glyphs[0].index).y / 200.0
	return _cap_ratio


static func _variation() -> FontVariation:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = FONT
		_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): WEIGHT}
	return _font


## An empty mask this many metres across: opaque black, so white glyphs
## blended onto it leave their coverage as brightness.
static func _blank(metres: Vector2) -> Image:
	var size := Vector2i((metres * DENSITY).ceil())
	var image := Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_LA8)
	image.fill(Color(0, 0, 0, 1))
	return image


static func _texture(image: Image) -> ImageTexture:
	image.convert(Image.FORMAT_L8)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
