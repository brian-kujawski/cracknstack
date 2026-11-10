class_name Hud
extends Control
## The in-game HUD (thread "Redesign the in-game HUD"; the list of what shows
## when and why is in the design doc, the look in HudStyle). Four fixed
## zones the player learns once:
## - top left, always: Money (with a short "+$0.85" on each sale), the
##   current chapter's Cards Organized, and the Level with its Mana bar;
## - bottom left, in context: the card (or pack, or box) in hand;
## - bottom right, in context: what the crosshair is on and its key;
## - top right, for a few seconds: notices (achievements, the radio).
## Big moments (level up, a new set, a finished binder) get a banner at the
## top centre, a new day a report in the middle, and a shipping box's fill
## floats over the box itself after a moment's look. Main feeds it.


## How long the "+$0.85" beside Money stays, and its fade.
const DELTA_SHOWN := 1.6
const DELTA_FADE := 0.5
const TOAST_SHOWN := 4.0
const TOAST_FADE := 0.6
const BANNER_SHOWN := 3.0
const BANNER_FADE := 0.5
## A shipping box's panel floats over it once the crosshair has rested on
## it this long.
const POPUP_DWELL := 1.0
## How far above a shipping box's base its panel floats (metres).
const POPUP_LIFT := 0.24
## A revealed card's value tag: from RARE_TAG_CENTS it's gold, from
## HIGH_VALUE_CENTS it's "High value" with a glow. It shows this long.
const RARE_TAG_CENTS := 50
const HIGH_VALUE_CENTS := 300
const VALUE_TAG_SHOWN := 4.0
## Where the value tag sits, as a share of the screen: by the top right
## corner of a card held up close.
const VALUE_TAG_AT := Vector2(0.66, 0.14)

## Card plate chips.
enum CopyStatus { NONE, NEEDED, DUPLICATE }

## The Hands the HUD watches (aim, shipping boxes). Set by Main.
var hands: Hands
## Sorceries in key order: [name, action] each (Main.SORCERIES).
var sorceries: Array = []
## The saving icon (Main makes it); kept just above the prompt plate.
var saving_icon: Control

var status: PanelContainer
var money_label: Label
var delta_label: Label
var chapter_block: VBoxContainer
var level_label: Label
var mana_block: VBoxContainer
var card_plate: PanelContainer
var prompt_plate: PanelContainer
var toast: PanelContainer
var banner: PanelContainer
var popup: VBoxContainer
var value_tag: PanelContainer
var sorcery_bar: HBoxContainer
var crosshair: Control
var debug_label: Label
var morning: Control

var _delta_tween: Tween
var _toast_tween: Tween
var _banner_tween: Tween
var _tag_tween: Tween
var _tagged: CardData
var _dwell_box: ShippingBox
var _dwell := 0.0
var _crosshair_active := false


func _init() -> void:
	name = "Hud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_status()
	_build_card_plate()
	_build_prompt_plate()
	_build_toast()
	_build_banner()
	_build_popup()
	_build_value_tag()
	_build_sorcery_bar()
	_build_crosshair()
	_build_morning()
	debug_label = HudStyle.label("", 14, HudStyle.MUTED)
	debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	debug_label.add_theme_constant_override("outline_size", 4)
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_label.visible = false
	add_child(debug_label)


## Whether Needed / Duplicate shows on the card plate: from Fact or Fiction
## (Level 2).
static func needed_tag_unlocked() -> bool:
	return Progression.rank("Fact or Fiction") > 0


# --- Top left: Money, chapter, level ----------------------------------------

func _build_status() -> void:
	status = HudStyle.plate_panel(14, Vector2(20, 16), "Status")
	status.name = "Status"
	status.custom_minimum_size.x = 380
	var lines: VBoxContainer = status.get_node("Lines")
	var money_row := HBoxContainer.new()
	money_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(money_row)
	money_label = HudStyle.number("")
	money_label.name = "Money"
	money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_row.add_child(money_label)
	delta_label = HudStyle.number("", HudStyle.FONT_SIZE, HudStyle.GAIN)
	delta_label.name = "Delta"
	delta_label.modulate.a = 0.0
	delta_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money_row.add_child(delta_label)
	chapter_block = HudStyle.counter("Chapter 1")
	chapter_block.name = "Chapter"
	lines.add_child(chapter_block)
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 18)
	level_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(level_row)
	level_row.add_child(_level_badge())
	mana_block = HudStyle.counter("Mana", HudStyle.MANA)
	mana_block.name = "Mana"
	mana_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mana_block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_row.add_child(mana_block)
	add_child(status)


## The level number on a gold diamond.
func _level_badge() -> Control:
	var badge := Control.new()
	badge.name = "Level"
	badge.custom_minimum_size = Vector2(54, 54)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func() -> void:
		var c := badge.size / 2
		var r := 26.0
		var points := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		badge.draw_colored_polygon(points, HudStyle.GOLD)
		# Cut like a gem: a lighter upper-left facet over the gilt.
		badge.draw_colored_polygon(PackedVector2Array([points[3], points[0], points[1], c]), Color(1, 1, 1, 0.16))
		points.append(points[0])
		badge.draw_polyline(points, UiStyle.BORDER, 2.0, true))
	level_label = HudStyle.number("1", 26, HudStyle.INK)
	level_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(level_label)
	return badge


## Fills the top-left plate. `chapter` is {"name", "organized", "pockets"},
## or empty before any set is unlocked (the chapter line hides).
func set_status(money: int, chapter: Dictionary, level: int, progress: int, per_level: int) -> void:
	money_label.text = Progression.money_text(money)
	chapter_block.visible = not chapter.is_empty()
	if not chapter.is_empty():
		(chapter_block.find_child("Caption", true, false) as Label).text = String(chapter.name).to_upper()
		HudStyle.set_counter(chapter_block, chapter.organized, chapter.pockets)
	level_label.text = str(level)
	if per_level > 0:
		HudStyle.set_counter(mana_block, progress, per_level)
	else:
		# The top level: a full bar.
		HudStyle.set_counter(mana_block, 1, 1)
		(mana_block.find_child("Count", true, false) as Label).text = "Max"


## "+$0.85" beside Money for a moment (a sale). Sales close together add up.
func show_money_delta(cents: int) -> void:
	var shown := 0
	if _delta_tween != null and _delta_tween.is_running():
		shown = int(delta_label.get_meta("cents", 0))
		_delta_tween.kill()
	shown += cents
	delta_label.set_meta("cents", shown)
	delta_label.text = "+" + Progression.money_text(shown)
	delta_label.modulate.a = 1.0
	_delta_tween = create_tween()
	_delta_tween.tween_interval(DELTA_SHOWN)
	_delta_tween.tween_property(delta_label, "modulate:a", 0.0, DELTA_FADE)


# --- Bottom left: what's in hand ----------------------------------------------

func _build_card_plate() -> void:
	card_plate = HudStyle.plate_panel(6, Vector2(20, 16), "CardPlate")
	card_plate.name = "CardPlate"
	card_plate.custom_minimum_size.x = 480
	card_plate.visible = false
	add_child(card_plate)


func _card_lines() -> VBoxContainer:
	var lines: VBoxContainer = card_plate.get_node("Lines")
	for child in lines.get_children():
		lines.remove_child(child)
		child.queue_free()
	return lines


## A card's plate: its Needed / Duplicate chip (if unlocked and known), name,
## set, number of total with its rarity, and what it sells for.
func show_card(card: CardData, copy_status := CopyStatus.NONE) -> void:
	var lines := _card_lines()
	if copy_status != CopyStatus.NONE and needed_tag_unlocked():
		var needed := copy_status == CopyStatus.NEEDED
		var chip := HudStyle.chip("Needed" if needed else "Duplicate", needed)
		chip.name = "Chip"
		lines.add_child(chip)
	var set_data := CardDatabase.get_set(card.set_code)
	lines.add_child(HudStyle.name_label(card.name))
	lines.add_child(HudStyle.label(set_data.name, HudStyle.FONT_SIZE, HudStyle.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(HudStyle.label("%s #%s/%s" % [set_data.code, set_data.number_text(card.collector_number),
		set_data.number_text(set_data.card_count)]))
	row.add_child(HudStyle.gem(card.rarity))
	var rarity := HudStyle.label(CardData.Rarity.keys()[card.rarity].capitalize())
	rarity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rarity)
	row.add_child(HudStyle.number(Progression.money_text(Prices.sale_cents(card)), HudStyle.FONT_SIZE))
	lines.add_child(row)
	card_plate.visible = true


## A pack or a box in hand: its first line as a name, the rest under it
## ("Khans of Tarkir" / "Booster Pack").
func show_product(details: String) -> void:
	var lines := _card_lines()
	var parts := details.split("\n")
	lines.add_child(HudStyle.name_label(parts[0], UiStyle.LEAD))
	for i in range(1, parts.size()):
		lines.add_child(HudStyle.label(parts[i], HudStyle.FONT_SIZE, HudStyle.MUTED))
	card_plate.visible = true


func clear_card() -> void:
	_card_lines()
	card_plate.visible = false


# --- Bottom right: what you're aiming at --------------------------------------

func _build_prompt_plate() -> void:
	prompt_plate = HudStyle.plate_panel(12, Vector2(20, 16), "PromptPlate")
	prompt_plate.name = "PromptPlate"
	prompt_plate.custom_minimum_size.x = 400
	prompt_plate.visible = false
	add_child(prompt_plate)


## Shows a hint (Hands.hint_changed) on the prompt plate, one line each:
## "E: Open Binder" becomes a keycap and its action, "Cards Filled:
## 12/269 (4%)" a counter with a bar, anything else plain text. Empty hides
## it.
func show_prompt(text: String) -> void:
	_fill_lines(prompt_plate.get_node("Lines"), text)
	prompt_plate.visible = not text.strip_edges().is_empty()


## Lines of a hint into `into`, replacing what's there (see show_prompt).
static func _fill_lines(into: VBoxContainer, text: String) -> void:
	for child in into.get_children():
		into.remove_child(child)
		child.queue_free()
	for line in text.split("\n", false):
		into.add_child(line_control(line))


## One hint line as the HUD draws it (see show_prompt).
static func line_control(line: String) -> Control:
	var parsed := parse_line(line)
	match parsed.kind:
		"key":
			return HudStyle.key_row(parsed.key, parsed.text)
		"count":
			var block := HudStyle.counter(parsed.text)
			HudStyle.set_counter(block, parsed.done, parsed.total,
				" (%d%%)" % parsed.percent if parsed.percent >= 0 else "")
			return block
	return HudStyle.label(line)


## How a hint line reads: {"kind": "key", "key", "text"} for a key prompt,
## {"kind": "count", "text", "done", "total", "percent" (-1 if none)} for a
## count out of a total, else {"kind": "text", "text"}.
static func parse_line(line: String) -> Dictionary:
	var at := line.find(": ")
	if at > 0:
		var head := line.left(at)
		var rest := line.substr(at + 2)
		if head in _key_labels():
			return {"kind": "key", "key": head, "text": rest}
		var count := RegEx.create_from_string("^(\\d+)/(\\d+)(?: \\((\\d+)%\\))?")
		var found := count.search(rest)
		if found != null:
			return {"kind": "count", "text": head, "done": int(found.get_string(1)), "total": int(found.get_string(2)),
				"percent": int(found.get_string(3)) if found.get_string(3) != "" else -1}
	return {"kind": "text", "text": line}


## The keys a hint can name (as Controls labels them).
static func _key_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for action in [Controls.INTERACT, Controls.RIP, Controls.INSPECT, Controls.FLIP_CARD, Controls.TURN_SIDEWAYS]:
		labels.append(Controls.label(action))
	return labels


# --- Top right: notices ----------------------------------------------------------

func _build_toast() -> void:
	toast = HudStyle.plate_panel(0, Vector2(14, 14), "Toast")
	toast.name = "Toast"
	toast.modulate.a = 0.0
	toast.visible = false
	toast.custom_minimum_size.x = 360
	var lines: VBoxContainer = toast.get_node("Lines")
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(row)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var caption := HudStyle.caption("")
	caption.name = "Caption"
	words.add_child(caption)
	var text := HudStyle.name_label("", UiStyle.LEAD)
	text.name = "Text"
	words.add_child(text)
	add_child(toast)


## A notice in the top right for a few seconds: a small gold caption
## ("Achievement"), its text, and an icon if there is one. A newer one
## takes its place.
func show_toast(caption: String, text: String, icon: Texture2D = null) -> void:
	(toast.find_child("Caption", true, false) as Label).text = caption.to_upper()
	(toast.find_child("Text", true, false) as Label).text = text
	var icon_rect: TextureRect = toast.find_child("Icon", true, false)
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	toast.visible = true
	toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SHOWN)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, TOAST_FADE)
	_toast_tween.tween_callback(toast.hide)


# --- Top centre: big moments ----------------------------------------------------

func _build_banner() -> void:
	banner = PanelContainer.new()
	banner.name = "Banner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.custom_minimum_size.x = 800
	# A stone frame round a dark window, with a soft gold glow behind it:
	# completions are gold (bible §7).
	var style := UiStyle.frame(12.0, Vector2(40, 16), "Banner")
	style.window = Color(UiStyle.GROUND, 0.94)
	style.glow = Color(UiStyle.GLEAM, 0.28)
	style.glow_size = 34
	banner.add_theme_stylebox_override("panel", style)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(lines)
	var kicker := HudStyle.caption("", UiStyle.BODY)
	kicker.name = "Kicker"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(kicker)
	var title := HudStyle.name_label("", UiStyle.DISPLAY, HudStyle.GOLD_BRIGHT)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(title)
	var sub := HudStyle.label("", HudStyle.FONT_SIZE, HudStyle.MUTED)
	sub.name = "Sub"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(sub)
	banner.visible = false
	banner.modulate.a = 0.0
	add_child(banner)


## A big moment across the top centre for a few seconds: "LEVEL UP" /
## "Level 2", with an optional line under it.
func show_banner(kicker: String, title: String, sub := "") -> void:
	(banner.find_child("Kicker", true, false) as Label).text = kicker.to_upper()
	(banner.find_child("Title", true, false) as Label).text = title
	var sub_label: Label = banner.find_child("Sub", true, false)
	sub_label.text = sub
	sub_label.visible = not sub.is_empty()
	banner.visible = true
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.25).from(0.0)
	_banner_tween.tween_interval(BANNER_SHOWN)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, BANNER_FADE)
	_banner_tween.tween_callback(banner.hide)


# --- In the room: a shipping box's fill -------------------------------------------

func _build_popup() -> void:
	popup = VBoxContainer.new()
	popup.name = "BoxPopup"
	popup.add_theme_constant_override("separation", 0)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := HudStyle.plate_panel(10, Vector2(18, 14), "BoxPopup")
	plate.name = "Plate"
	plate.custom_minimum_size.x = 290
	popup.add_child(plate)
	var pointer := Control.new()
	pointer.custom_minimum_size = Vector2(0, 16)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.draw.connect(func() -> void:
		var c := pointer.size.x / 2
		pointer.draw_colored_polygon(PackedVector2Array([Vector2(c - 13, 0), Vector2(c + 13, 0), Vector2(c, 15)]),
			UiStyle.BORDER)
		pointer.draw_colored_polygon(PackedVector2Array([Vector2(c - 10, 0), Vector2(c + 10, 0), Vector2(c, 11)]),
			UiStyle.STONE))
	popup.add_child(pointer)
	popup.visible = false
	add_child(popup)


## Floats the shipping box panel over the box in hand at once, or over the
## one the crosshair has rested on for POPUP_DWELL seconds.
func _update_popup(delta: float) -> void:
	var box: ShippingBox = null
	var held := false
	if hands != null:
		box = hands.held_shipping_box()
		held = box != null
		if not held:
			box = hands.aimed_shipping_box()
	if box != _dwell_box:
		_dwell_box = box
		_dwell = 0.0
	else:
		_dwell += delta
	if box == null or not is_instance_valid(box) or (not held and _dwell < POPUP_DWELL):
		popup.visible = false
		return
	var text := hands.shipping_box_hint(box)
	if String(popup.get_meta("text", "")) != text:
		popup.set_meta("text", text)
		_fill_lines(popup.get_node("Plate/Lines"), text)
	var camera := get_viewport().get_camera_3d()
	var point := box.global_position + Vector3.UP * POPUP_LIFT
	if camera == null or camera.is_position_behind(point):
		popup.visible = false
		return
	popup.visible = true
	popup.size = popup.get_combined_minimum_size()
	var visible_size := get_viewport().get_visible_rect().size
	var at := camera.unproject_position(point) / visible_size * size
	popup.position = (at - Vector2(popup.size.x / 2, popup.size.y)).clamp(Vector2.ZERO, size - popup.size)


# --- A revealed card's value -------------------------------------------------------

func _build_value_tag() -> void:
	value_tag = PanelContainer.new()
	value_tag.name = "ValueTag"
	value_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_tag.custom_minimum_size.x = 250
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.add_theme_constant_override("separation", 2)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_tag.add_child(lines)
	var top := HBoxContainer.new()
	top.name = "Top"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(top)
	var tier := HudStyle.caption("", UiStyle.SMALL)
	tier.name = "Tier"
	tier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tier)
	var new_chip := HudStyle.chip("NEW", true)
	new_chip.name = "New"
	top.add_child(new_chip)
	var price := HudStyle.name_label("", UiStyle.HEADING)
	price.name = "Price"
	lines.add_child(price)
	value_tag.visible = false
	add_child(value_tag)


## 0 plain, 1 gold (RARE_TAG_CENTS and up), 2 "High value" (HIGH_VALUE_CENTS).
static func value_tier(cents: int) -> int:
	if cents >= HIGH_VALUE_CENTS:
		return 2
	return 1 if cents >= RARE_TAG_CENTS else 0


## The tag beside a card just revealed from a pack: what it sells for, gold
## for a good one and glowing for a big one, NEW if it's the first copy.
func show_value_tag(card: CardData, first_copy: bool) -> void:
	_tagged = card
	var cents := Prices.sale_cents(card)
	var tier := value_tier(cents)
	# A HUD plate; a valuable card's price is gilt, a high-value one gleams
	# with a gold glow round the frame (earned value, bible §4).
	var style: UiStyle.Frame = HudStyle.plate(Vector2(20, 10), "ValueTag")
	style.glow = Color(UiStyle.GLEAM, [0.0, 0.22, 0.5][tier])
	style.glow_size = [0, 16, 34][tier]
	value_tag.add_theme_stylebox_override("panel", style)
	var tier_label: Label = value_tag.find_child("Tier", true, false)
	tier_label.text = ["", "VALUABLE", "HIGH VALUE"][tier]
	(value_tag.find_child("New", true, false) as Control).visible = first_copy
	var price: Label = value_tag.find_child("Price", true, false)
	price.text = Progression.money_text(cents)
	price.add_theme_font_size_override("font_size", [UiStyle.LEAD, UiStyle.TITLE, UiStyle.HEADING][tier])
	price.add_theme_color_override("font_color", [HudStyle.TEXT, HudStyle.GOLD, HudStyle.GOLD_BRIGHT][tier])
	value_tag.visible = true
	value_tag.modulate.a = 1.0
	if _tag_tween != null:
		_tag_tween.kill()
	_tag_tween = create_tween()
	_tag_tween.tween_interval(VALUE_TAG_SHOWN)
	_tag_tween.tween_property(value_tag, "modulate:a", 0.0, 0.4)
	_tag_tween.tween_callback(value_tag.hide)


## The card shown changed: a tag that belongs to another card goes.
func card_changed(card: CardData) -> void:
	if value_tag.visible and card != _tagged:
		value_tag.visible = false


# --- Bottom centre: sorceries --------------------------------------------------------

func _build_sorcery_bar() -> void:
	sorcery_bar = HBoxContainer.new()
	sorcery_bar.name = "Sorceries"
	sorcery_bar.add_theme_constant_override("separation", 12)
	sorcery_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sorcery_bar)


## The Mana colour under each sorcery's slot, by name.
const SORCERY_COLOURS := {"Teleport": Color(0.31, 0.56, 0.85), "Serra's Blessing": Color(0.937, 0.902, 0.784)}
const SLOT := 76.0
static var _slot_frame: StyleBox = HudStyle.plate(Vector2.ZERO, "Sorcery")


## One slot per learned sorcery: its icon, its key, and a dark sweep while
## it recharges (with the seconds left).
func refresh_sorceries() -> void:
	var learned := []
	for i in sorceries.size():
		if Progression.rank(sorceries[i][0]) > 0:
			learned.append(i)
	if sorcery_bar.get_child_count() != learned.size() or str(learned) != String(sorcery_bar.get_meta("learned", "")):
		sorcery_bar.set_meta("learned", str(learned))
		for child in sorcery_bar.get_children():
			sorcery_bar.remove_child(child)
			child.queue_free()
		for i in learned:
			sorcery_bar.add_child(_sorcery_slot(i))
	for slot in sorcery_bar.get_children():
		slot.queue_redraw()
		var node: String = sorceries[int(slot.get_meta("index"))][0]
		var left := Progression.recharge_left(node)
		var seconds: Label = slot.get_node("Seconds")
		seconds.text = str(ceili(left)) if left > 0.0 else ""


func _sorcery_slot(index: int) -> Control:
	var slot := Control.new()
	slot.name = String(sorceries[index][0]).replace(" ", "")
	slot.set_meta("index", index)
	slot.custom_minimum_size = Vector2(SLOT, SLOT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.draw.connect(_draw_slot.bind(slot, index))
	var seconds := HudStyle.label("", 24)
	seconds.name = "Seconds"
	seconds.add_theme_color_override("font_outline_color", Color.BLACK)
	seconds.add_theme_constant_override("outline_size", 5)
	seconds.set_anchors_preset(Control.PRESET_FULL_RECT)
	seconds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seconds.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(seconds)
	var cap := HudStyle.keycap(Controls.label(sorceries[index][1]), 15)
	cap.custom_minimum_size = Vector2(22, 22)
	cap.position = Vector2(5, SLOT - 29)
	slot.add_child(cap)
	return slot


func _draw_slot(slot: Control, index: int) -> void:
	var node: String = sorceries[index][0]
	var r := Rect2(Vector2.ZERO, slot.size)
	# A small stone frame round a dark well, the sorcery's colour along its
	# foot.
	slot.draw_style_box(_slot_frame, r)
	var inner := r.grow(-HudStyle.BAND - UiStyle.EDGE)
	slot.draw_rect(Rect2(inner.position.x, inner.end.y - 4, inner.size.x, 4), SORCERY_COLOURS.get(node, HudStyle.GOLD))
	_draw_icon(slot, node, r.get_center() + Vector2(0, -3), 17.0)
	var ranks: Array = Progression.COOLDOWNS.get(node, [])
	var rank := Progression.rank(node)
	var cooldown: float = ranks[clampi(rank - 1, 0, ranks.size() - 1)] if not ranks.is_empty() and rank > 0 else 0.0
	var left := Progression.recharge_left(node)
	if left > 0.0 and cooldown > 0.0:
		var share := clampf(left / cooldown, 0.0, 1.0)
		var points := PackedVector2Array([r.get_center()])
		var steps := 32
		for s in steps + 1:
			var angle := -PI / 2 + TAU * share * s / steps
			var p := r.get_center() + Vector2(cos(angle), sin(angle)) * r.size.x
			points.append(p.clamp(Vector2.ZERO, r.size))
		slot.draw_colored_polygon(points, Color(0, 0, 0, 0.66))


## Each sorcery's line drawing: Teleport a swirl, anything else (Serra's
## Blessing, to come) a sun.
func _draw_icon(slot: Control, node: String, c: Vector2, s: float) -> void:
	var ink := HudStyle.TEXT
	var w := 2.4
	match node:
		"Teleport":
			slot.draw_arc(c, s * 0.9, -PI * 0.4, PI * 1.4, 28, ink, w, true)
			slot.draw_arc(c, s * 0.48, PI * 0.6, PI * 2.4, 20, ink, w, true)
			slot.draw_circle(c, 2.0, ink)
		_:
			slot.draw_arc(c, s * 0.42, 0, TAU, 24, ink, w, true)
			for i in 8:
				var a := TAU * i / 8
				var d := Vector2(cos(a), sin(a))
				slot.draw_line(c + d * s * 0.62, c + d * s * 0.95, ink, w, true)


# --- The crosshair ---------------------------------------------------------------

func _build_crosshair() -> void:
	crosshair = Control.new()
	crosshair.name = "Crosshair"
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.custom_minimum_size = Vector2(32, 32)
	crosshair.draw.connect(func() -> void:
		var c := crosshair.size / 2
		crosshair.draw_circle(c, 4.5, Color(0, 0, 0, 0.5))
		crosshair.draw_circle(c, 3.0, Color.WHITE)
		if _crosshair_active:
			crosshair.draw_arc(c, 13.0, 0, TAU, 40, Color(0, 0, 0, 0.45), 4.5, true)
			crosshair.draw_arc(c, 13.0, 0, TAU, 40, HudStyle.TEXT, 2.5, true))
	add_child(crosshair)


## The dot grows a ring while the crosshair is on something you can use.
func set_crosshair_active(active: bool) -> void:
	if active != _crosshair_active:
		_crosshair_active = active
		crosshair.queue_redraw()


# --- A new day ------------------------------------------------------------------

func _build_morning() -> void:
	morning = Control.new()
	morning.name = "Morning"
	morning.set_anchors_preset(Control.PRESET_FULL_RECT)
	morning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.BORDER, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	morning.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	morning.add_child(center)
	var card := HudStyle.plate_panel(10, Vector2(48, 40), "Morning")
	card.custom_minimum_size.x = 800
	center.add_child(card)
	var lines: VBoxContainer = card.get_node("Lines")
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	var hello := HudStyle.caption("Good morning", UiStyle.BODY)
	hello.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(hello)
	var day := HudStyle.name_label("", UiStyle.DISPLAY, HudStyle.GOLD_BRIGHT)
	day.name = "Day"
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(day)
	var ornament := Control.new()
	ornament.custom_minimum_size = Vector2(0, 40)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament.draw.connect(HudStyle.fleuron.bind(ornament))
	lines.add_child(ornament)
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(stats)
	for key in ["Worked", "Earned", "Cards"]:
		var stat := VBoxContainer.new()
		stat.name = key
		stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var number := HudStyle.number("", UiStyle.HEADING)
		number.name = "Number"
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat.add_child(number)
		var what := HudStyle.label("", HudStyle.FONT_SIZE, HudStyle.MUTED)
		what.name = "What"
		what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat.add_child(what)
		stats.add_child(stat)
	morning.visible = false
	add_child(morning)


## The morning report (from Day 2): which day it is, how many days you've
## worked, what yesterday earned and how many cards it filed. Any key or
## click puts it away.
func show_morning(day: int, earned_cents: int, new_cards: int) -> void:
	(morning.find_child("Day", true, false) as Label).text = "Day %d" % day
	var worked := day - 1
	_set_stat("Worked", str(worked), "day worked" if worked == 1 else "days worked")
	_set_stat("Earned", Progression.money_text(earned_cents), "earned yesterday")
	_set_stat("Cards", str(new_cards), "new card yesterday" if new_cards == 1 else "new cards yesterday")
	morning.visible = true
	morning.modulate.a = 1.0


func _set_stat(key: String, number: String, what: String) -> void:
	var stat: Control = morning.find_child(key, true, false)
	(stat.get_node("Number") as Label).text = number
	(stat.get_node("What") as Label).text = what


func _input(event: InputEvent) -> void:
	if not morning.visible:
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var click: bool = event is InputEventMouseButton and event.pressed
	if key or click:
		morning.visible = false
		get_viewport().set_input_as_handled()


# --- Placement ------------------------------------------------------------------

func _process(delta: float) -> void:
	if hands != null:
		set_crosshair_active(hands.aim_usable())
	_update_popup(delta)
	refresh_sorceries()
	place()


## Puts every panel in its corner, sized to what it holds. Bottom panels
## grow upward, so lines added at their top don't move the lines below.
func place() -> void:
	_fit(status, HudStyle.EDGE)
	_fit(card_plate, Vector2(HudStyle.EDGE.x, size.y - HudStyle.EDGE.y), Vector2(0, 1))
	_fit(prompt_plate, size - HudStyle.EDGE, Vector2(1, 1))
	_fit(toast, Vector2(size.x - HudStyle.EDGE.x, HudStyle.EDGE.y), Vector2(1, 0))
	_fit(banner, Vector2(size.x / 2, 84), Vector2(0.5, 0))
	_fit(sorcery_bar, Vector2(size.x / 2, size.y - 30), Vector2(0.5, 1))
	_fit(value_tag, size * VALUE_TAG_AT, Vector2(0, 0))
	_fit(debug_label, Vector2(size.x / 2, 4), Vector2(0.5, 0))
	crosshair.size = crosshair.custom_minimum_size
	crosshair.position = (size - crosshair.size) / 2
	if saving_icon != null:
		var bottom := size.y - HudStyle.EDGE.y
		if prompt_plate.visible:
			bottom = prompt_plate.position.y - 12
		saving_icon.position = Vector2(size.x - HudStyle.EDGE.x - saving_icon.size.x, bottom - saving_icon.size.y)


## Sizes `control` to its content and puts its `pivot` (0..1 of its size)
## at `at`.
static func _fit(control: Control, at: Vector2, pivot := Vector2.ZERO) -> void:
	control.size = control.get_combined_minimum_size()
	control.position = (at - control.size * pivot).round()
