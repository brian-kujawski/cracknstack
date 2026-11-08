class_name Hands
extends Node
## The player's hands. One thing at a time: a card (or a ripped pack's
## stack), a binder, a pack, a box or the laptop.
##
## Keys and buttons are named here by their Controls actions (shown in
## comments as the default bindings). Left-click is context sensitive:
## - empty-handed: pick up the card under the crosshair (from the floor, a
##   table, or an unlocked card in an open binder), or pick up a closed
##   binder (off the floor, a table or a shelf);
## - holding a card: file it into the binder pocket you're looking at, or put
##   it down where you're looking (on the floor it rejoins the pile); a rare
##   card (RareCards) goes into its own shadow box when you click either
##   display cabinet;
## - carrying a binder: set it down where you're looking, or stand it in the
##   shelf space you're looking at.
## Putting something down happens when the button comes back up. Hold the
## button and a ghost shows where it will go, following your aim, so you can
## place it carefully; a quick click just puts it where you're looking.
## Right-click always empties your hand (toss_held()): every card in hand
## scatters onto the pile (or a table, if it comes down on one), and a
## binder, pack, box or the laptop tumbles through the air past other things
## and settles on whatever it comes down on. With empty hands, mid-glide or
## mid-reveal it does nothing. F brings
## the held card up close to inspect it (F again lowers it); while it's up
## close, R turns it over to show its back and T turns it a quarter turn
## clockwise (for split cards, printed sideways), and lowering it always turns
## it back face up and upright, so a held card is that way everywhere else.
## With empty hands, F on a card in an open binder or in a shadow box brings
## that card up close the same way, and F again sends it home. E opens or closes the binder
## you're looking at, and the mouse wheel turns its pages.
##
## Cards on tables count as lying about just like floor cards, for
## everything below.
##
## Abilities from levels (see Progression) change some of this: Snap speeds
## up every glide, Shunt files the card in hand into its own pocket wherever
## you click on its binder (Shunt I: its open pages; Shunt II: anywhere on
## the binder, open or closed), Tithe lights the binder a Needed card in hand
## belongs to and opens it at that card's page, and the sorcery Teleport (1)
## sends every card in hand to its binder.
##
## Rare cards have no binder, so nothing above that sends cards to their
## binders ever touches them.
##
## Cards and binders glide between the world and the hand rather than jumping;
## while one is on its way, the hands take no new orders.
##
## While a card is up close, the view holds still and the mouse tilts the card
## instead, directly and within a narrow range, like turning it in your hand.
##
## Booster packs: click a pack lying about with empty hands to take it, and
## click again to put it down where you're aiming. F brings the pack up close like a card, and
## R turns it over. Hold Space (Controls.RIP) to rip it open: the pack
## trembles, the foil tears slowly across the top, the room behind it goes
## dark, and with a flash it bursts open and its cards are in your hand, up
## close, commons on top and the rare slot at the back. They come out the
## size they were in the pack, a little further off, and come up to full
## size quickly. Each press of Space then shows the next card, the one on
## top going to the back; a rare or a mythic comes up with a glow, and once
## the last card is shown the room comes back. Space once more lowers the
## stack back into your hand. Let go of Space before the end and the tear stays where it
## got to, but the room comes back and the pack stops shaking. The cards
## are new copies (see PackContents), so they can be cards you already have.
##
## Selling (ShippingBox): with a card in hand, click a shipping box that
## stands on the floor or a table and the card is sold: it's sleeved,
## labelled with its price and drops in, and the money comes at once. A card
## your collection doesn't have yet asks first (sale_confirm_requested),
## unless that's turned off in Settings. E on a shipping box (aimed at, or
## in hand) seals it. Click the crate at the shipping corner by the door
## with empty hands for a new box, and E on the door ends the day.

signal held_changed(card: CardData, binder: BinderRange)
## The card whose details to show: the one in hand or up close (null for
## none).
signal shown_card_changed(card: CardData)
## What the binder under the crosshair holds and what you can do with it.
signal hint_changed(text: String)
## The first rare card of the game came to hand (the shop explains them).
signal rare_card_found
## The shop's radio was clicked (the shop opens the Radio menu).
signal radio_used
## A booster pack came to hand (its set's code), or left it ("").
signal held_pack_changed(set_code: String)
## E aimed at the laptop, or with it in hand: open the laptop screen.
signal laptop_used
## Selling the card in hand into `box` needs a yes first: the collection
## doesn't have it yet. The shop asks, and calls sell_held_card(box, true).
signal sale_confirm_requested(box: ShippingBox)
## A card was sold: copy `id`, for `cents`.
signal card_sold(id: int, cents: int)
## E on the shop door: the shop ends the day.
signal end_day_requested
## A card from a pack came up (copy `id`): the HUD tags it with its value.
signal card_revealed(id: int)

enum Aim { NONE, FLOOR, SURFACE, BINDER, LOOSE_CARD, SHELF, CABINET, RADIO, BOX, LOOSE_PACK, SHIPPING, DOOR, SORTER, SORTER_POCKET }

## How far from the eye the player can reach.
@export var reach := 2.6
## Toss: each throw picks its forward and upward speed (m/s) and its
## end-over-end flip rate (flips per second) at random between min and max.
## A gentle lob, not a throw.
@export var toss_forward_speed_min := 1.4
@export var toss_forward_speed_max := 1.8
@export var toss_up_speed_min := 0.8
@export var toss_up_speed_max := 1.2
@export var toss_flips_per_second_min := 0.8
@export var toss_flips_per_second_max := 1.8
## Slight wobble on the other two axes, up to this many turns per second
## either way: roll around the card's long axis, and spin flat like a
## frisbee. Keep these well under the flip rate so the flip still reads.
@export var toss_roll_per_second_max := 0.25
@export var toss_spin_per_second_max := 0.35
## A tossed binder: a heavier, slower lob than a card's, turning over about
## once in the air, end over end or sideways like a book flipping shut, so it
## lands on its cover or its back at random.
@export var binder_toss_forward_speed_min := 1.2
@export var binder_toss_forward_speed_max := 1.6
@export var binder_toss_up_speed_min := 0.9
@export var binder_toss_up_speed_max := 1.3
@export var binder_toss_flips_per_second_min := 0.5
@export var binder_toss_flips_per_second_max := 1.3
@export var binder_toss_wobble_per_second_max := 0.3
## Tossing a handful of cards: each card's speed forward and sideways is
## off by up to this much (m/s), so they scatter.
@export var toss_scatter := 0.35
## A lobbed pack or box lands this far ahead (metres, on the level), rising
## this high over a straight line on the way, and takes this long.
@export var lob_distance := 1.2
@export var lob_height := 0.35
@export var lob_seconds := 0.6
@export var zoom_seconds := 0.18
## How long a card or binder takes to come to hand or go where it's put, and
## how high a put-down arcs at its midpoint (metres). Deliberately unhurried,
## so Snap has room to speed them up.
@export var card_glide_seconds := 0.24
@export var binder_glide_seconds := 0.36
@export var put_down_lift := 0.04
## Filing: after gliding to just above its pocket, the card slides down into
## it, a little slower.
@export var pocket_slide_seconds := 0.33
## A rare card glides to just in front of its shadow box, this far out, then
## slides back into it.
@export var shadow_box_entry := 0.12
## Teleport: the card flies to its binder in an arc this high, taking this
## long plus this much per metre (at most the cap).
@export var teleport_lift := 0.6
@export var teleport_seconds := 0.35
@export var teleport_seconds_per_metre := 0.06
@export var teleport_seconds_max := 1.2
## Holding the button this long before letting go shows the ghost.
@export var ghost_after_seconds := 0.12
## How far a card up close can tilt each way (degrees), on both axes. Kept
## narrow so the card never turns far enough to show it's a flat quad.
@export var inspect_tilt_degrees := 15.0
## How long turning a card up close over (or back) takes.
@export var turn_over_seconds := 0.3
## How long turning a card up close sideways (or back upright) takes.
@export var turn_sideways_seconds := 0.2
## Booster packs: how long Space is held to rip one open, how long the torn
## strip takes to fly off, and how long the card on top takes to go to the
## back when the next one's shown.
@export var rip_seconds := 1.6
## With the pack knife (Tools "pack_knife"), ripping takes this share of
## rip_seconds.
@export var pack_knife_share := 0.375
@export var pack_burst_seconds := 0.45
@export var reveal_seconds := 0.22
## How long the cards out of a pack take to come up from the pack's size to
## full size up close, and how long they wait first.
@export var emerge_seconds := 0.3
@export var emerge_delay := 0.06
## Selling: how long a sold card takes from the hand to just over the
## shipping box (sleeved and labelled on the way), and then to drop in.
## Snap speeds both up; later unlocks can shorten them.
@export var sell_seconds := 0.3
## Holding the button on the sorting tray keeps dropping cards on it: the
## first at once, the next this many seconds later, then one every
## tray_repeat_seconds, until the hand's empty or a Needed card comes up.
@export var tray_repeat_delay := 0.25
@export var tray_repeat_seconds := 0.1
## A card dropped on the sorting tray glides over its slot, then drops in
## over this long.
@export var tray_drop_seconds := 0.08
@export var sell_drop_seconds := 0.18

## Where the held card sits relative to the camera: low and to the right,
## or close up and square to your face (see zoomed_distance).
const HELD_POSITION := Vector3(0.075, -0.05, -0.2)
## A pack is held a little lower, being taller than a card.
const PACK_HELD_POSITION := Vector3(0.075, -0.07, -0.21)
## A box in hand tips its top this far toward you (radians).
const BOX_HELD_TILT := 0.35
## How far the pack shakes while being ripped, at the very end (metres and
## radians); it starts at a sliver of that and grows.
const RIP_SHAKE := 0.0025
const RIP_SHAKE_TURN := 0.035
## How far the tear has run when the pack bursts (the burst does the rest),
## and how it runs: slowly at first.
const RIP_TEAR_AT_BURST := 0.85
const RIP_TEAR_CURVE := 2.2
const HELD_ROTATION := Vector3(0.12, -0.25, 0.04)
const ZOOMED_ROTATION := Vector3.ZERO
## How much of the screen's height a card up close fills, at any field of view.
const ZOOMED_SCREEN_FILL := 0.75
## A carried binder: held to the right, cover tilted toward you. High and
## close enough that all of it stays in view, and that it stays clear of a
## table top while you lean over one.
const CARRIED_POSITION := Vector3(0.22, -0.07, -0.44)
const CARRIED_ROTATION := Vector3(0.7, -0.5, 0.0)
## How many times faster every glide is at each rank of Snap (none, -, the
## one rank there is: Snap opens at rank 2, twice as fast).
const SNAP_SPEEDUP := [1.0, 1.5, 2.0]
## Cards held behind the top one fan out up and to the right, this far apart;
## past MAX_FANNED only the count is felt, not seen.
const FAN_STEP := Vector3(0.007, 0.006, -0.002)
const FAN_TURN := 0.05
const MAX_FANNED := 6

var pile: PileWorld
## The top card in hand, or -1.
var held_card_id := -1
## The rest of the hand, behind the top card in order (a ripped pack).
var behind: Array[int] = []
var carried_binder: Binder
## The booster pack in hand (a prototype), or null.
var held_pack: BoosterPack
## A box of product in hand (ProductBox), or null.
var held_box: ProductBox
## The shipping corner by the door, with its crate of new boxes (the shop
## sets it).
var shipping_station: ShippingStation
## The card sorter, once you have one (Main).
var sorter: CardSorter
## Cards of the pack just ripped still to be shown (after the one on top).
var revealing := 0
## Seconds the room stays dim after the last card of a pack is shown, so
## the rare's glow plays out in the dark.
const REVEAL_LINGER := 1.6
var _linger := 0.0
## Every card of the pack just ripped has been shown, and the next Space
## lowers the stack.
var _revealed_all := false
## How far back toward the pack's size the card up close is (1 just out of
## the pack, 0 full size); see emerge_seconds.
var _emerge := 0.0
## Out of the pack, the cards start this much further off than the pack was
## up close, so they look as if they fitted inside it.
const EMERGE_DEPTH := 1.08
## The display cabinets (the shop sets them), whose shadow boxes hold the
## rare cards.
var cabinets: Array[DisplayCabinet] = []
## Every copy you've held at least once, by copy id (the first rare card's
## note looks here).
var seen_cards := {}

@onready var _camera: Camera3D = get_parent().get_node("Camera3D")
var _held_view: MeshInstance3D
var _fan_views: Array[MeshInstance3D] = []
var _zoomed := false
var _zoom_tween: Tween
## 0 = held low, 1 = up close; tweened, and the held card's pose follows it.
var _zoom_amount := 0.0
## Up-close tilt in radians: x tips the top toward or away from you, y turns
## the face left or right.
var _tilt := Vector2.ZERO
## Whether the card up close is turned to show its back, and how far round
## it is (0 face up, 1 back); tweened.
var _turned_over := false
var _turn_amount := 0.0
var _turn_tween: Tween
## The same for a quarter turn clockwise, to read a card printed sideways.
var _sideways := false
var _sideways_amount := 0.0
var _sideways_tween: Tween
## A card brought up close from its pocket or shadow box (F with empty
## hands): its id, or -1. It never leaves home: `_viewed_home` returns where
## it lies there, as a global pose, and `_viewed_lift` shows it gone from
## there (true) or back (false) while the hand shows it up close.
var _viewed_id := -1
var _viewed_home: Callable
var _viewed_lift: Callable
## The glide in progress, if any: something coming to hand or being put down.
var _glide: Tween
## While the button is held to put something down: how long it's been held.
## -1 when not placing.
var _placing := -1.0
## Seconds until the held button drops the next card on _tray_held_at
## (-1 when it isn't held there).
var _tray_repeat := -1.0
var _tray_held_at: SortingTray
## Whether a quick click (let go before the ghost shows) picks up the card
## you're aiming at instead of putting the top card down.
var _pick_on_release := false
var _ghost_card: MeshInstance3D
var _ghost_binder: MeshInstance3D

var _aim := Aim.NONE
var _aim_point := Vector3.ZERO
## The top floor card under the crosshair, or -1.
var _aim_floor_card := -1
var _aim_binder: Binder
var _aim_pocket := -1
var _aim_loose_card: LooseCard
var _aim_shelf: ShelfUnit
var _aim_space := -1
var _aim_cabinet: DisplayCabinet
## The shadow box the crosshair is on, in _aim_cabinet, or -1.
var _aim_slot := -1
var _aim_box: ProductBox
var _aim_pack: BoosterPack
var _hovered_binder: Binder
var _hint := ""
var _shown_card: CardData
## Tithe: the binder lit, and the top card and level it was worked out for.
var _tithe_binder: Binder
var _tithe_for := -1
var _tithe_level := 0
## Ripping: how far along (0 to 1), and whether Space is being held for it.
var _rip := 0.0
var _ripping := false
## The shake added to the pack's pose while it's ripped.
var _shake := Transform3D.IDENTITY
var _pack_effects: PackEffects
var _pack_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_held_view = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = PileWorld.CARD_SIZE
	_held_view.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/held_card.gdshader")
	_held_view.material_override = material
	_held_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held_view.visible = false
	_camera.add_child(_held_view)
	for i in MAX_FANNED:
		var view := MeshInstance3D.new()
		view.mesh = quad
		view.material_override = ShaderMaterial.new()
		view.material_override.shader = material.shader
		view.position = HELD_POSITION + FAN_STEP * (i + 1)
		view.rotation = HELD_ROTATION + Vector3(0, 0, -FAN_TURN * (i + 1))
		view.visible = false
		_camera.add_child(view)
		_fan_views.append(view)
	_pose_held_card()
	# Field of view can change in Settings while a card is up close. Deferred
	# so the player has set the camera's new field of view first.
	Settings.changed.connect(_pose_held_card.unbind(1), CONNECT_DEFERRED)

	var ghost_material := StandardMaterial3D.new()
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.albedo_color = Color(1, 1, 1, 0.35)
	ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_card = MeshInstance3D.new()
	_ghost_card.mesh = quad
	_ghost_binder = MeshInstance3D.new()
	_ghost_binder.mesh = BoxMesh.new()  # Sized to the carried binder when shown.
	for ghost in [_ghost_card, _ghost_binder]:
		ghost.material_override = ghost_material
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.top_level = true
		ghost.visible = false
		add_child(ghost)
	_pack_effects = PackEffects.new()
	_pack_effects.name = "PackEffects"
	add_child(_pack_effects)
	_pack_effects.setup(_camera)
	_pack_rng.randomize()


func _physics_process(delta: float) -> void:
	if pile == null:
		return
	_update_aim()
	if held_card_id != _tithe_for or Progression.level() != _tithe_level:
		_tithe_for = held_card_id
		_tithe_level = Progression.level()
		update_tithe()
	pile.set_highlight(_aim_lying_card() if has_room() else -1)
	_update_hover()
	_update_ghost(delta)
	_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	if pile == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_released(Controls.RIP):
		_ripping = false
	if event is InputEventMouseMotion:
		if _zoomed:
			# Hands sees input before the player, so marking it handled keeps
			# the view still while the card tilts.
			_tilt = inspect_tilt(_tilt, event.relative, get_parent().mouse_sensitivity(), deg_to_rad(inspect_tilt_degrees))
			_pose_held_card()
			get_viewport().set_input_as_handled()
		return
	if _gliding():
		return
	if _viewed_id >= 0:
		# Nothing else while a card from a pocket or a shadow box is up close.
		if event.is_action_pressed(Controls.INSPECT):
			_end_viewing()
		elif event.is_action_pressed(Controls.FLIP_CARD):
			turn_over(not _turned_over)
		elif event.is_action_pressed(Controls.TURN_SIDEWAYS):
			turn_sideways(not _sideways)
		return
	if event.is_action_released(Controls.USE_HAND):
		if _placing >= 0.0:
			var quick := _placing < ghost_after_seconds
			_placing = -1.0
			if quick and _pick_on_release:
				_ghost_card.visible = false
				_pick_up_aimed()
			else:
				_put_down_where_aimed()
			_pick_on_release = false
	elif _placing >= 0.0:
		return # One thing at a time while putting something down.
	elif event.is_action_pressed(Controls.RIP):
		press_rip()
	elif event.is_action_pressed(Controls.USE_HAND):
		_use_hand()
	elif event.is_action_pressed(Controls.TOSS):
		toss_held()
	elif event.is_action_pressed(Controls.INTERACT) and _shipping_box_at_hand() != null:
		_shipping_box_at_hand().seal()
	elif event.is_action_pressed(Controls.INTERACT) and _laptop_at_hand() != null:
		laptop_used.emit()
	elif event.is_action_pressed(Controls.INTERACT) and _aim == Aim.DOOR:
		end_day_requested.emit()
	elif event.is_action_pressed(Controls.INTERACT):
		_toggle_binder()
	elif event.is_action_pressed(Controls.INSPECT) and (held_card_id >= 0 or held_pack != null):
		_set_zoomed(not _zoomed)
	elif event.is_action_pressed(Controls.INSPECT) and _hands_empty():
		view_aimed()
	elif event.is_action_pressed(Controls.FLIP_CARD) and _zoomed:
		turn_over(not _turned_over)
	elif event.is_action_pressed(Controls.TURN_SIDEWAYS) and _zoomed:
		turn_sideways(not _sideways)
	elif event.is_action_pressed(Controls.FLIP_NEXT):
		_flip(1)
	elif event.is_action_pressed(Controls.FLIP_PREVIOUS):
		_flip(-1)
	elif event.is_action_pressed(Controls.CAST_TELEPORT):
		cast_teleport()


## The laptop, if it's in hand or you're aiming at it; else null.
func _laptop_at_hand() -> Laptop:
	if held_box is Laptop:
		return held_box
	if _aim == Aim.BOX and _aim_box is Laptop:
		return _aim_box
	return null


## The shipping box in hand, or else the one you're aiming at (with no
## other box in hand); null if neither.
func _shipping_box_at_hand() -> ShippingBox:
	if held_box is ShippingBox:
		return held_box
	if held_box == null and _aim == Aim.BOX and _aim_box is ShippingBox:
		return _aim_box
	return null


func _hands_empty() -> bool:
	return held_card_id < 0 and carried_binder == null and held_pack == null and held_box == null


## How many cards your hand holds when you pick them up one by one off the
## floor or a table (a quick click with cards in hand adds the aimed card).
## A ripped pack or a tray stack comes into your hand whole, past this.
const HAND_SIZE := 40


func hand_size() -> int:
	return HAND_SIZE


func hand_count() -> int:
	return (1 if held_card_id >= 0 else 0) + behind.size()


## Whether another card can come into your hand.
func has_room() -> bool:
	return carried_binder == null and held_pack == null and held_box == null and hand_count() < hand_size()


func _gliding() -> bool:
	return _glide != null and _glide.is_running()


func _use_hand() -> void:
	if _aim == Aim.RADIO:
		radio_used.emit()
		return
	if _aim == Aim.SORTER_POCKET:
		use_sorter_pocket(_aim_box)
		return
	if _aim == Aim.SORTER:
		if held_card_id >= 0:
			feed_sorter()
		return
	if held_box != null:
		if held_box is SortingTray and _aim == Aim.BOX and _aim_box is ShippingBox:
			sell_tray(held_box, _aim_box)
		elif _aim in [Aim.FLOOR, Aim.SURFACE, Aim.LOOSE_CARD]:
			put_down_box()
		return
	if held_pack != null:
		if _aim in [Aim.FLOOR, Aim.SURFACE, Aim.LOOSE_CARD, Aim.LOOSE_PACK]:
			put_down_pack()
		return # Otherwise a pack gets ripped.
	if _hands_empty() and _aim == Aim.BOX:
		take_box(_aim_box)
		return
	if _hands_empty() and _aim == Aim.SHIPPING and shipping_station != null:
		take_new_shipping_box()
		return
	if _hands_empty() and _aim == Aim.LOOSE_PACK:
		_take_pack_node(_aim_pack)
		return
	if carried_binder != null:
		if _aim == Aim.SHELF:
			_shelve_carried_binder()
		elif _can_put_down():
			_placing = 0.0
		return
	if held_card_id >= 0:
		if _aim == Aim.BOX and _aim_box is ShippingBox:
			sell_held_card(_aim_box)
			return
		if _aim == Aim.BOX and _aim_box is SortingTray:
			start_tray_drops(_aim_box)
			return
		if _try_display_held_card() or _try_file_held_card():
			return
		# With room in hand, a quick click on a card picks it up as well;
		# holding the button still puts the top card down.
		_pick_on_release = has_room() and ((_aim == Aim.FLOOR and _aim_floor_card >= 0) or _aim == Aim.LOOSE_CARD)
		if _pick_on_release or _can_put_down():
			_placing = 0.0
		return
	if _aim == Aim.BINDER and not _aim_binder.is_open():
		_carry(_aim_binder)
		return
	_pick_up_aimed()


## Takes the card under the crosshair into your hand, on top: off the floor
## or a table. Cards in binder pockets are locked in for good.
func _pick_up_aimed() -> bool:
	if not has_room():
		return false
	match _aim:
		Aim.FLOOR:
			var id := _aim_floor_card
			if id >= 0:
				var from := pile.card_pose(id)
				pile.pick_up(id)
				_take_in_hand(id, from)
				return true
		Aim.LOOSE_CARD:
			var card := _aim_loose_card
			var from := card.card_pose()
			pile.pick_up(card.card_id)
			_take_in_hand(card.card_id, from)
			return true
	return false


## Files the held card into the binder pocket under the crosshair. Only its
## own pocket takes it: anywhere else nothing happens and it stays in hand.
## Returns false if there's no pocket there (so the click does something
## else).
func _try_file_held_card() -> bool:
	if _aim != Aim.BINDER:
		return false
	var binder := _aim_binder
	var pocket := shunt_pocket(binder)
	if pocket >= 0 and not binder.is_open():
		# Shunt III: in through the closed cover.
		var id := held_card_id
		_put_down_card(Glide.flat_card(binder.global_position + binder.global_basis.y * binder.thickness, binder.global_basis),
			func() -> void: _file(binder, pocket, id)).set_meta("pocket", [binder, pocket])
		return true
	if not binder.is_open():
		return false
	if pocket >= 0 and pocket != _aim_pocket:
		binder.show_pocket(pocket) # Shunt II turns to the card's page.
	if pocket < 0:
		pocket = _aim_pocket
	if pocket < 0:
		return false
	if not binder.contents.belongs(held_card_id, pocket) or binder.contents.card_at(pocket) >= 0:
		return true # Not its pocket, or taken: the card stays in hand.
	var id := held_card_id
	_put_down_card(binder.pocket_pose(pocket), func() -> void: _file(binder, pocket, id),
		binder.pocket_entry_pose(pocket)).set_meta("pocket", [binder, pocket])
	return true


## With a rare card on top of the hand, a click on either display cabinet
## sends it to its own shadow box, wherever that is. Returns false if
## that's not what the click does.
func _try_display_held_card() -> bool:
	if _aim != Aim.CABINET or not Collection.is_rare(held_card_id):
		return false
	var number := Collection.card(held_card_id).collector_number
	for cabinet in cabinets:
		var slot := cabinet.slot_for(number)
		if slot < 0 or cabinet.displayed[slot] >= 0:
			continue
		var id := held_card_id
		var to := cabinet.slot_pose(slot)
		var via := to.translated(to.basis.z * shadow_box_entry)
		_put_down_card(to, func() -> void: _display(cabinet, id), via).set_meta("cabinet", [cabinet, slot])
		return true
	return false


## A rare card has arrived in its shadow box: it locks in like a card in its
## pocket (glow, chime, Mana) and unlocks its achievement, and the last of
## them unlocks one more.
func _display(cabinet: DisplayCabinet, id: int) -> void:
	if not cabinet.display(id):
		return
	Progression.earn(Progression.CARD_LOCKED)
	Progression.card_filed_by_hand()
	var all := cabinets.all(func(c: DisplayCabinet) -> bool: return c.is_complete())
	Achievements.rare_card_displayed(Collection.card(id).collector_number, all)
	var slot := cabinet.slot_for(Collection.card(id).collector_number)
	FeedbackSounds.play(pile, cabinet.slot_pose(slot).origin,
		FeedbackSounds.Kind.BINDER_COMPLETE if all else FeedbackSounds.Kind.CARD_LOCKED)


## Shunt: with the held card's own pocket in this binder empty, that's
## where a click anywhere on the binder files it. Shunt I needs the pocket's
## page open, Shunt II just the binder open (it turns to the page), and
## Shunt III files into a closed binder too. -1 without Shunt, or if it
## doesn't apply.
func shunt_pocket(binder: Binder) -> int:
	var rank := Progression.rank("Shunt")
	if rank == 0 or held_card_id < 0 or (rank < 3 and not binder.is_open()):
		return -1
	var card := Collection.card(held_card_id)
	if card.set_code != binder.binder.set_code or not binder.binder.contains(card.collector_number):
		return -1
	var pocket := card.collector_number - binder.binder.first
	if binder.contents.card_at(pocket) >= 0:
		return -1
	var pages := BinderLayout.spread_pages(binder.binder, binder.spread)
	if rank < 2 and pocket / BinderLayout.POCKETS_PER_PAGE not in [pages.x, pages.y]:
		return -1
	return pocket


## The held card has arrived in its pocket.
func _file(binder: Binder, pocket: int, id: int) -> void:
	var result := binder.insert(pocket, id)
	if result != BinderContents.Result.LOCKED:
		# Its pocket filled on the way: it falls beside the binder.
		pile.land(id, binder.global_position + binder.global_basis.y * binder.thickness, binder.rotation.y,
			true, [binder.get_rid()])
		return
	Progression.card_filed_by_hand()
	_locked_in(binder, pocket)


## A card locked into its pocket, by hand or by Teleport: the chime.
func _locked_in(binder: Binder, pocket: int) -> void:
	var page := pocket / BinderLayout.POCKETS_PER_PAGE
	var sound := FeedbackSounds.Kind.CARD_LOCKED
	if binder.contents.is_complete():
		sound = FeedbackSounds.Kind.BINDER_COMPLETE
	elif binder.contents.is_page_complete(page):
		sound = FeedbackSounds.Kind.PAGE_COMPLETE
	FeedbackSounds.play(pile, binder.to_global(binder.pocket_position(pocket)), sound)


## Teleport: the top card in hand flies to its own binder, wherever it is
## (buried, closed, on a shelf, across the room), and files itself; at rank
## II, so does every card in hand. A card whose pocket is already filled
## stays in hand. Returns whether it was cast.
func cast_teleport() -> bool:
	if not Progression.can_cast("Teleport") or held_card_id < 0 or _gliding():
		return false
	var hand: Array[int] = [held_card_id]
	if Progression.rank("Teleport") >= 2:
		hand.append_array(behind)
	var sent: Array[int] = []
	for id in hand:
		var binder := pile.binder_for(id)
		if binder != null and binder.contents.card_at(Collection.card(id).collector_number - binder.binder.first) < 0:
			sent.append(id)
	if sent.is_empty():
		return false
	Progression.cast("Teleport")
	var from := _held_view.global_transform
	for id in sent:
		var binder := pile.binder_for(id)
		var pocket := Collection.card(id).collector_number - binder.binder.first
		if id == held_card_id:
			_release_top()
		else:
			behind.erase(id)
		_fly_to_pocket(id, from, binder, pocket, func() -> void: _locked_in(binder, pocket))
	_refresh_fan()
	return true


## Card `id` flies by magic from the global pose `from` into its own pocket
## of `binder`, wherever that is, and calls `landed` once it's locked in.
## Your hands are free while it flies.
func _fly_to_pocket(id: int, from: Transform3D, binder: Binder, pocket: int, landed: Callable) -> void:
	var card := _card_copy(id)
	card.set_meta("pocket", [binder, pocket])
	var to := func() -> Transform3D:
		if binder.is_open():
			return binder.pocket_pose(pocket)
		return Glide.flat_card(binder.global_position + binder.global_basis.y * binder.thickness, binder.global_basis)
	var flight := minf(teleport_seconds + teleport_seconds_per_metre * from.origin.distance_to(to.call().origin),
		teleport_seconds_max)
	Glide.start(card, from, to, glide_seconds(flight), teleport_lift).tween_callback(func() -> void:
		card.queue_free()
		if binder.insert(pocket, id) == BinderContents.Result.LOCKED:
			landed.call()
		else:
			# Its pocket filled while it flew: it falls beside the binder,
			# onto the pile or the table it's on.
			pile.land(id, binder.global_position + binder.global_basis.y * binder.thickness, binder.rotation.y,
				true, [binder.get_rid()]))


func _toggle_binder() -> void:
	if carried_binder != null or _aim != Aim.BINDER:
		return
	if _aim_binder.is_open():
		_aim_binder.close()
	elif _aim_binder.state == Binder.State.CLOSED:
		_aim_binder.open()
		var pocket := tithe_pocket(_aim_binder)
		if pocket >= 0:
			_aim_binder.show_pocket(pocket)


## Tithe: opening a binder with a Needed card of it in hand turns to that
## card's page. Its pocket, or -1 without Tithe or such a card.
func tithe_pocket(binder: Binder) -> int:
	if Progression.rank("Tithe") == 0 or held_card_id < 0 or Collection.is_rare(held_card_id):
		return -1
	if pile.binder_for(held_card_id) != binder or not collection_needs(held_card_id):
		return -1
	return Collection.card(held_card_id).collector_number - binder.binder.first


## Tithe: the binder the Needed card on top of your hand belongs to glows,
## wherever it is; nothing glows without one. Checked when the top card
## changes. Returns the binder lit, or null.
func update_tithe() -> Binder:
	var lit: Binder = null
	if Progression.rank("Tithe") > 0 and held_card_id >= 0 and not Collection.is_rare(held_card_id) \
			and collection_needs(held_card_id):
		lit = pile.binder_for(held_card_id)
	if lit != _tithe_binder:
		if is_instance_valid(_tithe_binder):
			_tithe_binder.set_tithe(false)
		_tithe_binder = lit
		if lit != null:
			lit.set_tithe(true)
	return lit


## The wheel turns the pages of the open binder you're aiming at, or else
## cycles which card in your hand is on top.
func _flip(direction: int) -> void:
	if _aim == Aim.BINDER and _aim_binder.is_open():
		_aim_binder.flip(direction)
	else:
		cycle_hand(direction)


## Brings the next card in hand to the top (1), or the bottom one (-1); the
## old top card goes to the back or just behind.
func cycle_hand(direction: int) -> void:
	if behind.is_empty():
		return
	if direction > 0:
		behind.append(held_card_id)
		_hold(behind.pop_front())
	else:
		behind.push_front(held_card_id)
		_hold(behind.pop_back())


## Whether what's in hand can be put down where you're aiming: the floor, a
## table, or (for a card) on top of a card lying on a table.
func _can_put_down() -> bool:
	return _aim == Aim.FLOOR or _aim == Aim.SURFACE or (_aim == Aim.LOOSE_CARD and held_card_id >= 0)


## Where what's in hand would go if put down now: a global pose (a card quad
## for a card, the binder's own pose for a binder), or null if there's
## nowhere to put it.
func _put_down_pose():
	if not _can_put_down():
		return null
	var yaw := _yaw_facing_player(_aim_point)
	if held_card_id >= 0:
		if _aim == Aim.FLOOR:
			return pile.drop_pose(_aim_point, yaw)
		return LooseCard.pose_at(_aim_point, yaw)
	var point := _clear_of_obstacles(_aim_point, Binder.OPEN_HALF_FOOTPRINT, yaw)
	var y := carried_binder.rest_height(Vector2(point.x, point.z), yaw, point.y + Binder.DROP_HEIGHT)
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(point.x, y, point.z))


## Shows the ghost of what's in hand where it would go, once the button has
## been held a moment.
## Pausing lets go of a put-down in progress: its release goes to the pause
## screen, not to us.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _placing >= 0.0:
		_placing = -1.0
		_ghost_card.visible = false
		_ghost_binder.visible = false


func _update_ghost(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_placing = -1.0 # The release won't reach us; let it go.
	var pose = null
	if _placing >= 0.0:
		_placing += delta
		if _placing >= ghost_after_seconds:
			pose = _put_down_pose()
	var ghost := _ghost_card if held_card_id >= 0 else _ghost_binder
	_ghost_card.visible = pose != null and ghost == _ghost_card
	_ghost_binder.visible = pose != null and ghost == _ghost_binder
	if pose == null:
		return
	if ghost == _ghost_binder:
		# The box mesh is centred; a binder's origin is its underside.
		(_ghost_binder.mesh as BoxMesh).size = carried_binder.size
		pose = pose.translated_local(Vector3(0, carried_binder.thickness / 2, 0))
	ghost.global_transform = pose


## The button came up: put what's in hand down where you're aiming now, if
## that's somewhere it can go.
func _put_down_where_aimed() -> void:
	_ghost_card.visible = false
	_ghost_binder.visible = false
	if not _can_put_down():
		return
	if carried_binder != null:
		_set_binder_down()
		return
	var id := held_card_id
	var yaw := _yaw_facing_player(_aim_point)
	var point := _aim_point
	var card: MeshInstance3D
	if _aim == Aim.FLOOR:
		card = _put_down_card(pile.drop_pose(point, yaw), func() -> void: pile.drop(id, point, yaw))
	else:
		card = _put_down_card(LooseCard.pose_at(point, yaw), func() -> void: pile.lay_loose(id, point, yaw))
	card.set_meta("falls_to", [point, yaw])


## Glides the held card to `to` (a global card pose) and calls `land` when it
## gets there. Given `via`, it glides there first and then slides on to `to`.
## The hand is free at once; the card in flight is a copy, returned.
func _put_down_card(to: Transform3D, land: Callable, via = null) -> MeshInstance3D:
	var card := _card_copy(held_card_id)
	var from := _held_view.global_transform
	_release_top()
	if via is Transform3D:
		_glide = Glide.start(card, from, func() -> Transform3D: return via, glide_seconds(card_glide_seconds), put_down_lift)
		Glide.then(_glide, card, via, to, glide_seconds(pocket_slide_seconds))
	else:
		_glide = Glide.start(card, from, func() -> Transform3D: return to, glide_seconds(card_glide_seconds), put_down_lift)
	_glide.tween_callback(func() -> void:
		land.call()
		card.queue_free())
	return card


## A card on its own, in the world, looking like card `id`: one in flight
## somewhere. It has its own material, so the next pick-up can change the
## hand without changing it. A save finds where it's going by its metadata:
## "card_id", and "pocket" ([binder, pocket]) or "falls_to" ([point, yaw]).
func _card_copy(id: int) -> MeshInstance3D:
	var card := MeshInstance3D.new()
	card.set_meta("card_id", id)
	card.mesh = _held_view.mesh
	card.material_override = _card_material(id)
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pile.add_child(card)
	return card


func _card_material(id: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/held_card.gdshader")
	CardView.apply(material, id)
	return material


func _carry(binder: Binder) -> void:
	if binder.state == Binder.State.SHELVED:
		binder.shelf_unit.unshelve(binder.shelf_space)
	var from := binder.global_transform
	binder.carry(_camera, CARRIED_POSITION, CARRIED_ROTATION)
	carried_binder = binder
	held_changed.emit(null, binder.binder)
	var carried := binder.transform
	_glide = Glide.start(binder, from, func() -> Transform3D: return _camera.global_transform * carried, glide_seconds(binder_glide_seconds))


func _set_binder_down() -> void:
	var yaw := _yaw_facing_player(_aim_point)
	var binder := carried_binder
	var from := binder.global_transform
	binder.put_down(pile, _clear_of_obstacles(_aim_point, Binder.OPEN_HALF_FOOTPRINT, yaw), yaw)
	carried_binder = null
	held_changed.emit(null, null)
	# put_down() found where it rests; hold it still on the way there, then
	# hand it to physics.
	binder.freeze = true
	var to := binder.global_transform
	_glide = Glide.start(binder, from, func() -> Transform3D: return to, glide_seconds(binder_glide_seconds), put_down_lift)
	_glide.tween_callback(binder.let_go)


func _shelve_carried_binder() -> void:
	if _aim_shelf.shelved[_aim_space] != null:
		return
	var binder := carried_binder
	carried_binder = null
	var shelf := _aim_shelf
	var from := binder.global_transform
	shelf.shelve(_aim_space, binder)
	held_changed.emit(null, null)
	var to := binder.global_transform
	_glide = Glide.start(binder, from, func() -> Transform3D: return to, glide_seconds(binder_glide_seconds))
	if shelf.is_space_complete(_aim_space):
		var lit := shelf.is_section_complete(shelf.shelf_of(_aim_space))
		_glide.tween_callback(func() -> void:
			FeedbackSounds.play(pile, binder.global_position,
				FeedbackSounds.Kind.SECTION_COMPLETE if lit else FeedbackSounds.Kind.BINDER_SHELVED))


## Takes these cards into hand as a save left them (ShopSave): the first on
## top, the rest behind it, with no glide.
func restore_hand(ids: Array[int]) -> void:
	behind.assign(ids.slice(1))
	_hold(ids[0] if not ids.is_empty() else -1)


## Carries a binder as a save left it, with no glide.
func restore_carried(binder: Binder) -> void:
	binder.carry(_camera, CARRIED_POSITION, CARRIED_ROTATION)
	carried_binder = binder
	held_changed.emit(null, binder.binder)


## How long a glide that takes `seconds` at heart takes now, with Snap.
func glide_seconds(seconds: float) -> float:
	return seconds / SNAP_SPEEDUP[Progression.rank("Snap")]


## How far you can reach.
func current_reach() -> float:
	return reach


## On the floor, nudges a footprint at `point` clear of walls, shelves and
## table legs. Table tops are left as aimed.
func _clear_of_obstacles(point: Vector3, half_size: Vector2, yaw: float) -> Vector3:
	if _aim != Aim.FLOOR:
		return point
	var p := pile.clear_point(Vector2(point.x, point.z), half_size, yaw)
	return Vector3(p.x, point.y, p.y)


## Turned so its bottom edge (local +z) faces the player.
func _yaw_facing_player(point: Vector3) -> float:
	var to_player := _camera.global_position - point
	return atan2(to_player.x, to_player.z)


func _update_aim() -> void:
	_aim = Aim.NONE
	_aim_floor_card = -1
	_aim_binder = null
	_aim_pocket = -1
	_aim_loose_card = null
	_aim_shelf = null
	_aim_space = -1
	_aim_cabinet = null
	_aim_slot = -1
	_aim_box = null
	_aim_pack = null
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * current_reach()
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [(get_parent() as CollisionObject3D).get_rid()]
	# The pile's surface collider is only for binders to rest on; aim at the
	# cards through it. The block that stops you leaning over a table is
	# only for the player's body.
	query.collision_mask = ~(PileWorld.SURFACE_LAYER | preload("res://scripts/store/store_builder.gd").LEAN_STOP_LAYER)
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	# The floor's cards aren't colliders: the one you aim at is the first one
	# the crosshair's ray meets, unless something else is in front of it.
	var card: Dictionary = pile.card_on_ray(from, to) if pile != null else {}
	if not card.is_empty() and (hit.is_empty() or from.distance_to(card.position) < from.distance_to(hit.position)):
		_aim = Aim.FLOOR
		_aim_point = card.position
		_aim_floor_card = card.id
		return
	if hit.is_empty():
		return
	_aim_point = hit.position
	var collider: Object = hit.collider
	if collider is ShelfUnit:
		var at: int = collider.space_at(hit.position)
		if at >= 0 and collider.shelved[at] != null:
			collider = collider.shelved[at]
	if collider is Binder and collider.state == Binder.State.SHELVED and not Progression.is_set_unlocked(collider.binder.set_code):
		return # A locked set's binder stays on the shelf, untouchable.
	if collider is SortingTray and (collider as Node).has_meta("sorter_pocket"):
		_aim = Aim.SORTER_POCKET
		_aim_box = collider
		return
	if collider is CardSorter:
		_aim = Aim.SORTER
		return
	if collider is ProductBox:
		_aim = Aim.BOX
		_aim_box = collider
		return
	if collider is ShippingStation:
		_aim = Aim.SHIPPING
		return
	if collider is ShopDoor:
		_aim = Aim.DOOR
		return
	if collider is StaticBody3D and (collider as Node).get_parent() is BoosterPack:
		_aim = Aim.LOOSE_PACK
		_aim_pack = (collider as Node).get_parent()
		return
	if collider is Binder:
		_aim = Aim.BINDER
		_aim_binder = collider
		_aim_pocket = _aim_binder.pocket_at(hit.position)
	elif collider is LooseCard:
		_aim = Aim.LOOSE_CARD
		_aim_loose_card = collider
	elif collider is DisplayCabinet:
		_aim = Aim.CABINET
		_aim_cabinet = collider
		_aim_slot = _aim_cabinet.slot_on_ray(from, to)
	elif collider is ShopRadio:
		_aim = Aim.RADIO
	elif collider is Node and (collider as Node).is_in_group(ReadingCorner.FURNITURE):
		return # Nothing to do with the armchair, the side table or the lamp.
	elif collider is ShelfUnit:
		var space: int = collider.space_at(hit.position)
		if space < 0:
			return
		if collider.shelved[space] != null:
			_aim = Aim.BINDER
			_aim_binder = collider.shelved[space]
		else:
			_aim = Aim.SHELF
			_aim_shelf = collider
			_aim_space = space
	elif hit.normal.y > 0.9:
		# The floor itself is at y = 0; anything higher is a table or counter.
		_aim = Aim.FLOOR if hit.position.y < 0.05 else Aim.SURFACE


func _update_hover() -> void:
	var binder := _aim_binder if _aim == Aim.BINDER else null
	if _hovered_binder != binder and is_instance_valid(_hovered_binder):
		_hovered_binder.set_hover(-1)
	_hovered_binder = binder
	if binder != null:
		binder.set_hover(_aim_pocket)


func _update_hint() -> void:
	var text := ""
	match _aim:
		Aim.BINDER:
			text = _binder_hint(_aim_binder)
		Aim.CABINET:
			text = _cabinet_hint()
		Aim.RADIO:
			text = _radio_hint()
		Aim.DOOR:
			text = "%s: End Day" % _key(Controls.INTERACT)
	if _laptop_at_hand() != null:
		text = "%s: Use Laptop" % _key(Controls.INTERACT)
	if text != _hint:
		_hint = text
		hint_changed.emit(text)
	var id := shown_card_id()
	var shown: CardData = Collection.card(id) if id >= 0 else null
	if shown != _shown_card:
		_shown_card = shown
		shown_card_changed.emit(shown)


## The card whose details to show: the one up close from a pocket, or the
## one in hand. -1 for none.
func shown_card_id() -> int:
	if _viewed_id >= 0:
		return _viewed_id
	return held_card_id


## The card lying under the crosshair, on the floor or a table (or hovering
## there), or -1.
func _aim_lying_card() -> int:
	if _aim == Aim.FLOOR:
		return _aim_floor_card
	if _aim == Aim.LOOSE_CARD:
		return _aim_loose_card.card_id
	return -1


## How a hint shows an action's key or button (see Controls).
func _key(action: StringName) -> String:
	return Controls.label(action)


func _binder_hint(binder: Binder) -> String:
	var contents := binder.contents
	var lines := PackedStringArray(["Cards Filled: %d/%d (%d%%)" % [
		contents.locked_count, contents.capacity(), floori(100.0 * contents.locked_count / contents.capacity())]])
	match binder.state:
		Binder.State.CLOSED:
			if carried_binder == null:
				lines.append("%s: Open Binder" % _key(Controls.INTERACT))
		Binder.State.OPEN:
			var pages := BinderLayout.spread_pages(binder.binder, binder.spread)
			var shown := []
			for page in [pages.x, pages.y]:
				if page >= 0:
					shown.append(str(page + 1))
			lines.append("%s %s of %d" % ["Pages" if shown.size() > 1 else "Page", "–".join(shown),
				BinderLayout.page_count(binder.binder)])
			lines.append("%s: Close Binder" % _key(Controls.INTERACT))
			# On top: the block is anchored at the bottom, so lines that come and
			# go as you aim grow it upward and leave the binder's lines in place.
			if _aim_pocket >= 0:
				lines.insert(0, _pocket_hint(binder, _aim_pocket))
	return "\n".join(lines)


## How many rare cards are on display, across both cabinets.
func _cabinet_hint() -> String:
	var shown := 0
	var total := 0
	for cabinet in cabinets:
		shown += cabinet.displayed_count()
		total += cabinet.slots.size()
	return "Rare Cards Displayed: %d/%d" % [shown, total]


## Whether the crosshair is on something you can use: anything but bare
## air, or a table top while there's something in hand to put down.
func aim_usable() -> bool:
	match _aim:
		Aim.NONE:
			return false
		Aim.SURFACE:
			return not _hands_empty()
	return true


## Whether the crosshair is on the shop door.
func aiming_at_door() -> bool:
	return _aim == Aim.DOOR


## The shipping box the crosshair is on, or null. The HUD floats its fill
## over it after a moment's look (it isn't in the hint).
func aimed_shipping_box() -> ShippingBox:
	return _aim_box as ShippingBox if _aim == Aim.BOX else null


## The shipping box in hand, or null.
func held_shipping_box() -> ShippingBox:
	return held_box as ShippingBox


## How full a shipping box is, and E to seal it once it has cards in.
func shipping_box_hint(box: ShippingBox) -> String:
	if box.sealed:
		return "Sealed: %d Cards" % box.cards
	var lines := PackedStringArray(["Shipping Box: %d/%d Cards" % [box.cards, box.capacity]])
	if box.can_seal():
		lines.append("%s: Seal Box" % _key(Controls.INTERACT))
	return "\n".join(lines)


## What's on the radio, or that it's off.
static func _radio_hint() -> String:
	if not Radio.playing or Radio.current < 0:
		return "Radio: Off"
	return "Radio: %s" % Radio.songs[Radio.current].title


## A pocket shows its number, and the card's name once its own card is locked
## in. Until then the card is a mystery.
func _pocket_hint(binder: Binder, pocket: int) -> String:
	var set_data := CardDatabase.get_set(binder.binder.set_code)
	var number := "%s #%s" % [set_data.code, set_data.number_text(binder.binder.first + pocket)]
	if not binder.contents.is_locked(pocket):
		return number + ": ???"
	return "%s\n%s" % [number, Collection.card(binder.contents.card_at(pocket)).name]


## Right-click: empties your hand, whatever is in it. Every card in hand
## scatters (a ripped pack's whole stack too), a binder tumbles, and a pack,
## a box or the laptop is lobbed (see lob_product); tossing the laptop has
## its own achievement. Nothing happens with empty hands, while something
## glides, or while a pack is being ripped or its cards are still being
## revealed. Returns whether anything left your hand.
func toss_held() -> bool:
	if _gliding() or revealing > 0 or _ripping or _viewed_id >= 0:
		return false
	if held_card_id >= 0:
		var hand: Array[int] = [held_card_id]
		hand.append_array(behind)
		var poses: Array[Transform3D] = [_held_view.global_transform]
		for i in behind.size():
			poses.append(_fan_views[i].global_transform if i < _fan_views.size() else _held_view.global_transform)
		behind.clear()
		_revealed_all = false
		_hold(-1)
		for i in hand.size():
			_toss_card(hand[i], poses[i], 0.0 if hand.size() == 1 else toss_scatter)
		return true
	if carried_binder != null:
		toss_binder()
		return true
	if held_pack != null:
		if held_pack.tear > 0.0:
			return false
		var pack := held_pack
		held_pack = null
		_hold(-1)
		held_pack_changed.emit("")
		lob_product(pack)
		return true
	if held_box != null:
		var box := held_box
		held_box = null
		held_pack_changed.emit("")
		lob_product(box)
		if box is Laptop:
			Achievements.laptop_tossed()
		return true
	return false


## One card out of your hand, from the global pose `from`, tumbling onto the
## pile or a table (TossedCard). `scatter` (m/s) spreads a handful sideways
## and in speed, so a dropped stack fans out instead of landing in a heap.
func _toss_card(id: int, from: Transform3D, scatter := 0.0) -> void:
	var forward := -_camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var card := TossedCard.new()
	# The tossed card gets its own material so the next pick-up can change
	# the hand without changing the card in flight.
	var material := _card_material(id)
	pile.add_child(card)
	card.exclude = [(get_parent() as CollisionObject3D).get_rid()]
	var side := forward.cross(Vector3.UP)
	var velocity := forward * (randf_range(toss_forward_speed_min, toss_forward_speed_max) + randf_range(-scatter, scatter)) \
			+ side * randf_range(-scatter, scatter) \
			+ Vector3.UP * randf_range(toss_up_speed_min, toss_up_speed_max)
	# Turns per second around the card's own axes: mostly end over end
	# (left-right axis), with a little roll (long axis) and flat spin (face
	# normal) so no two tosses tumble quite the same.
	var flips := randf_range(toss_flips_per_second_min, toss_flips_per_second_max) * (1 if randf() < 0.5 else -1)
	var roll := randf_range(-toss_roll_per_second_max, toss_roll_per_second_max)
	var spin := randf_range(-toss_spin_per_second_max, toss_spin_per_second_max)
	card.launch(id, pile, material, from, velocity, Vector3(flips, roll, spin) * TAU)


## Lobs a pack or a box (the laptop and shipping boxes included) out of your
## hand in a scripted arc, like a binder's toss without the physics: it
## flies over everything, turning over once, and comes down where it would
## be put down that far ahead (lob_landing), short of any wall. A booster
## box stays sealed and a shipping box keeps its cards. While it flies
## nothing can aim at it, and a save puts it where it's landing ("lands_at").
func lob_product(product: Node3D) -> void:
	var from := product.global_transform
	var to := lob_landing(product)
	var yaw := _camera.global_rotation.y
	product.get_parent().remove_child(product)
	pile.add_child(product)
	product.global_transform = from
	product.set_meta("lands_at", to)
	var box := product as ProductBox
	var flips := 1.0 if randf() < 0.5 else -1.0
	var axis := Vector3.RIGHT if randf() < 0.5 else Vector3.BACK
	var tween := product.create_tween()
	product.set_meta("lob", tween)
	tween.tween_method(func(t: float) -> void:
		var pose := from.interpolate_with(to, t)
		pose.origin += Vector3.UP * 4.0 * lob_height * t * (1.0 - t)
		pose.basis = pose.basis * Basis(axis, TAU * flips * t)
		product.global_transform = pose, 0.0, 1.0, lob_seconds)
	tween.tween_callback(func() -> void:
		product.global_transform = to
		product.remove_meta("lands_at")
		product.remove_meta("lob")
		if box != null:
			box.collision_layer = Binder.PHYSICS_LAYER
		elif product is BoosterPack:
			(product as BoosterPack).lie(pile, to.origin - Vector3.UP * BoosterPack.THICKNESS / 2, yaw))


## Where a lobbed pack or box comes down (global): lob_distance ahead of you
## on the level, or short of the first wall or shelf in the way, then on the
## table there or the pile, kept clear like anything put down there.
func lob_landing(product: Node3D) -> Transform3D:
	var forward := -_camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var eye := _camera.global_position
	var player := (get_parent() as CollisionObject3D).get_rid()
	var space := _camera.get_world_3d().direct_space_state
	var distance := lob_distance
	var ahead := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + forward * lob_distance, 1, [player]))
	if not ahead.is_empty():
		distance = maxf(0.25, eye.distance_to(ahead.position) - 0.3)
	var point := eye + forward * distance
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(point, Vector3(point.x, -1.0, point.z), 1, [player]))
	var ground_y: float = down.position.y if not down.is_empty() and down.normal.y >= 0.7 else 0.0
	var yaw := _camera.global_rotation.y
	var local := pile.to_local(Vector3(point.x, ground_y, point.z))
	var p := Vector2(local.x, local.z)
	if product is BoosterPack:
		var half := Vector2(BoosterPack.SIZE.x, BoosterPack.SIZE.y) / 2
		var y := pile.height_at(p) if ground_y < 0.05 else local.y
		if ground_y >= 0.05:
			p = pile.onto_surface(p, yaw, half)
		return BoosterPack.lying_pose(pile.to_global(Vector3(p.x, y, p.y)), yaw)
	var box := product as ProductBox
	var half_box := box.half_footprint()
	var y_box := local.y
	if ground_y < 0.05:
		p = pile.clear_point(p, half_box, yaw)
		y_box = pile.height_under(p, half_box, yaw)
	else:
		p = pile.onto_surface(p, yaw, half_box)
	return pile.global_transform * Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y_box, p.y))


## Throws the carried binder forward in a lob (see Binder.toss).
func toss_binder() -> void:
	var binder := carried_binder
	carried_binder = null
	held_changed.emit(null, null)
	var forward := -_camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var start := binder.global_transform
	# Hard up against a wall, the carried binder pokes into it; start from
	# this side, so it bounces off rather than flying through.
	var player := (get_parent() as CollisionObject3D).get_rid()
	var middle := start * Vector3(0, binder.thickness / 2, 0)
	var eye := _camera.global_position
	var query := PhysicsRayQueryParameters3D.create(eye, middle + forward * Binder.TOSS_EDGE_REACH, 1, [player])
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var room := maxf(0.05, eye.distance_to(hit.position) - Binder.TOSS_EDGE_REACH - 0.02)
		start.origin += eye + (middle - eye).normalized() * room - middle
	var velocity := forward * randf_range(binder_toss_forward_speed_min, binder_toss_forward_speed_max) \
			+ Vector3.UP * randf_range(binder_toss_up_speed_min, binder_toss_up_speed_max)
	# Mostly one turn: end over end (around its width) or sideways round the
	# spine, either way, with a little wobble on the other axes.
	var flips := randf_range(binder_toss_flips_per_second_min, binder_toss_flips_per_second_max) * (1 if randf() < 0.5 else -1)
	var wobble := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * binder_toss_wobble_per_second_max
	var spin := Vector3(flips, 0, 0) if randf() < 0.5 else Vector3(0, 0, flips)
	binder.toss(pile, start, velocity, (spin + wobble) * TAU, [player])


## Adds a mouse movement to the up-close tilt, one to one with mouse look's
## sensitivity, and clamps it to `limit` radians each way. Moving the mouse
## right turns the face to the right; moving it up tips the top away.
static func inspect_tilt(tilt: Vector2, mouse_relative: Vector2, sensitivity: float, limit: float) -> Vector2:
	return Vector2(
		clampf(tilt.x + mouse_relative.y * sensitivity, -limit, limit),
		clampf(tilt.y + mouse_relative.x * sensitivity, -limit, limit))


## How far in front of the camera a card `card_height` tall sits so it fills
## ZOOMED_SCREEN_FILL of the screen's height at vertical field of view `fov`
## (degrees). Wider views bring it closer.
static func zoomed_distance(fov: float, card_height: float) -> float:
	return card_height / (ZOOMED_SCREEN_FILL * 2.0 * tan(deg_to_rad(fov) / 2.0))


func _set_zoomed(zoomed: bool) -> void:
	_zoomed = zoomed
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_method(_set_zoom_amount, _zoom_amount, 1.0 if zoomed else 0.0, zoom_seconds)
	if not zoomed:
		# The tilt eases out with the lowering, so the card settles flat.
		_zoom_tween.parallel().tween_property(self, "_tilt", Vector2.ZERO, zoom_seconds)
		# And it turns face up and upright as it comes down, so it's never
		# held any other way.
		if _turned_over or _turn_amount > 0.0:
			turn_over(false, zoom_seconds)
		if _sideways or _sideways_amount > 0.0:
			turn_sideways(false, zoom_seconds)


## Turns the card up close over to show its back (or face up again), round
## its own upright axis, taking `seconds` (turn_over_seconds for a whole
## turn if negative).
func turn_over(back: bool, seconds := -1.0) -> void:
	_turned_over = back
	if _turn_tween:
		_turn_tween.kill()
	var target := 1.0 if back else 0.0
	if seconds < 0.0:
		seconds = turn_over_seconds * absf(target - _turn_amount)
	if seconds <= 0.0:
		_set_turn_amount(target)
		return
	_turn_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_turn_tween.tween_method(_set_turn_amount, _turn_amount, target, seconds)


func _set_turn_amount(amount: float) -> void:
	_turn_amount = amount
	_pose_held_card()


## Turns the card up close a quarter turn clockwise (or upright again), in
## the plane of the screen, taking `seconds` (turn_sideways_seconds for a
## whole quarter turn if negative).
func turn_sideways(sideways: bool, seconds := -1.0) -> void:
	_sideways = sideways
	if _sideways_tween:
		_sideways_tween.kill()
	var target := 1.0 if sideways else 0.0
	if seconds < 0.0:
		seconds = turn_sideways_seconds * absf(target - _sideways_amount)
	if seconds <= 0.0:
		_set_sideways_amount(target)
		return
	_sideways_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sideways_tween.tween_method(_set_sideways_amount, _sideways_amount, target, seconds)


func _set_sideways_amount(amount: float) -> void:
	_sideways_amount = amount
	_pose_held_card()


func _set_zoom_amount(amount: float) -> void:
	_zoom_amount = amount
	_pose_held_card()
	_show_fan()


## Places the held card between its low and up-close poses, with the tilt on
## top. Tilt only shows up close, so it's scaled by how far up the card is.
## Turning over is innermost, round the card's own upright axis, then the
## quarter turn sideways, so the tilt follows the mouse the same way
## whichever side is showing and the quarter turn is always clockwise.
func _pose_held_card() -> void:
	if held_pack != null:
		_pose_pack()
		return
	if _gliding() and (held_card_id >= 0 or _viewed_id >= 0):
		return # Still on its way to the hand (or back home).
	var zoomed_position := Vector3(0.0, 0.0, -lerpf(zoomed_distance(_camera.fov, PileWorld.CARD_SIZE.y),
		zoomed_distance(_camera.fov, BoosterPack.SIZE.y) * EMERGE_DEPTH, _emerge))
	# Edge on, halfway over, a side of the card comes this much nearer; it
	# backs off by that much so it stays clear of the near plane.
	zoomed_position.z -= sin(PI * _turn_amount) * PileWorld.CARD_SIZE.x / 2.0
	_held_view.position = HELD_POSITION.lerp(zoomed_position, _zoom_amount)
	_held_view.basis = held_basis(HELD_ROTATION.lerp(ZOOMED_ROTATION, _zoom_amount) \
			+ Vector3(_tilt.x, _tilt.y, 0.0) * _zoom_amount, _turn_amount, _sideways_amount)


## The pack in hand, posed as a held card is (low, or up close and tilted,
## turned over) and shaken while it's being ripped.
func _pose_pack() -> void:
	if _gliding():
		return # Still on its way to the hand.
	var zoomed_position := Vector3(0.0, 0.0, -zoomed_distance(_camera.fov, BoosterPack.SIZE.y))
	zoomed_position.z -= sin(PI * _turn_amount) * BoosterPack.SIZE.x / 2.0
	held_pack.transform = Transform3D(held_basis(HELD_ROTATION.lerp(ZOOMED_ROTATION, _zoom_amount) \
			+ Vector3(_tilt.x, _tilt.y, 0.0) * _zoom_amount, _turn_amount, _sideways_amount),
		PACK_HELD_POSITION.lerp(zoomed_position, _zoom_amount)) * _shake


## Takes a pack into your hand from where it lies.
func _take_pack_node(pack: BoosterPack) -> void:
	pack.stop_lying()
	var from := pack.global_transform
	_hold(-1)
	pack.get_parent().remove_child(pack)
	_camera.add_child(pack)
	held_pack = pack
	_rip = 0.0
	_ripping = false
	_shake = Transform3D.IDENTITY
	_pose_held_card()
	var held := pack.transform
	pack.global_transform = from
	_glide = Glide.start(pack, from, func() -> Transform3D: return _camera.global_transform * held,
		glide_seconds(card_glide_seconds))
	held_pack_changed.emit(pack.set_code)


## Space: with a pack in hand, start ripping it; once a pack's cards have
## all been shown, lower the stack into your hand; otherwise show the next
## card.
func press_rip() -> void:
	if held_box != null and not is_product(held_box):
		return
	if held_box != null:
		open_box(held_box)
	elif _hands_empty() and _aim == Aim.BOX:
		if is_product(_aim_box):
			open_box(_aim_box)
	elif held_pack != null:
		_start_ripping()
	elif _revealed_all and _zoomed:
		_revealed_all = false
		_set_zoomed(false)
	else:
		reveal_next()


## A new, empty shipping box from the crate by the door, into your hand.
## Returns it.
## Whether `box` is sealed product to open (a booster or bulk box), not
## the laptop, a shipping box or the sorting tray.
static func is_product(box: ProductBox) -> bool:
	return not (box is Laptop or box is ShippingBox or box is SortingTray)


## The sorting tray, aimed at with a card in hand: a duplicate glides over
## it and drops in at the front. A card the collection still needs stays in
## hand, and so does any card once the tray is full. Returns whether the
## card went.
func drop_on_tray(tray: SortingTray) -> bool:
	if held_card_id < 0 or tray == null or tray == held_box or _gliding() or collection_needs(held_card_id) \
			or not tray.has_room():
		return false
	var id := held_card_id
	var card := _card_copy(id)
	var from := _held_view.global_transform
	_release_top()
	var above := tray.card_entry_pose()
	var to := tray.card_slot_pose()
	tray.add(id, true) # The front card changes once this one's in.
	# Its own glide, not the hand's: holding the button drops the next one
	# while this one is still on its way.
	var glide := Glide.start(card, from, func() -> Transform3D: return above, glide_seconds(sell_seconds), put_down_lift)
	Glide.then(glide, card, above, to, glide_seconds(tray_drop_seconds))
	glide.tween_callback(func() -> void:
		if is_instance_valid(tray):
			tray.landed()
		card.queue_free())
	return true


## The button's pressed on the sorting tray: the top card goes on, and if
## it did, more follow while it's held (repeat_tray_drop).
func start_tray_drops(tray: SortingTray) -> bool:
	if not drop_on_tray(tray):
		return false
	_tray_held_at = tray
	_tray_repeat = tray_repeat_delay
	return true


## While the button's held on the sorting tray, the next card goes on when
## it's due. Letting go, looking away, or a Needed card (or no card) on top
## of the hand stops it.
func repeat_tray_drop(delta: float, held: bool) -> void:
	if _tray_repeat < 0.0:
		return
	if not held or not is_instance_valid(_tray_held_at) or _aim != Aim.BOX or _aim_box != _tray_held_at:
		_tray_repeat = -1.0
		return
	_tray_repeat -= delta
	if _tray_repeat > 0.0 or _gliding():
		return # Not due yet, or something else in hand is still moving.
	_tray_repeat = maxf(_tray_repeat + tray_repeat_seconds, 0.0) if drop_on_tray(_tray_held_at) else -1.0


## The sorting tray in hand, clicking a shipping box: the tray's stack is
## sold into the box in one go, top card first, as many as it has room for.
## Returns the cents paid.
func sell_tray(tray: SortingTray, box: ShippingBox) -> int:
	# All in one go: taking cards off the tray, or dropping them in the box,
	# one at a time redraws its top card each time, and each of those reads
	# a card image from disk (a freeze of seconds for a full box).
	var room := box.capacity - box.cards if box.has_room() else 0
	var sold := tray.take(mini(room, tray.cards.size()))
	var each := Sales.sell_all(sold)
	box.add_cards(sold)
	var paid := 0
	for i in sold.size():
		seen_cards.erase(sold[i])
		paid += each[i]
		card_sold.emit(sold[i], each[i])
	if paid > 0:
		FeedbackSounds.play(pile, box.global_position, FeedbackSounds.Kind.CARD_SOLD)
	held_pack_changed.emit(tray.set_code) # The corner's count changes.
	return paid


## The whole hand goes into the card sorter's hopper, the top card first.
## Returns how many cards went.
func feed_sorter() -> int:
	if sorter == null or held_card_id < 0 or _gliding():
		return 0
	var ids: Array[int] = [held_card_id]
	ids.append_array(behind)
	var card := _card_copy(held_card_id)
	var from := _held_view.global_transform
	behind.clear()
	_hold(-1)
	sorter.feed(ids)
	var to := sorter.hopper_pose()
	_glide = Glide.start(card, from, func() -> Transform3D: return to, glide_seconds(sell_seconds), put_down_lift)
	_glide.tween_callback(card.queue_free)
	return ids.size()


## Clicking one of the sorter's pockets (`tray`): with empty hands, its
## stack comes into your hand, top card first; with the Sorting Tray in
## hand, the Surplus stack tips onto it. Returns how many cards moved.
func use_sorter_pocket(tray: SortingTray) -> int:
	if sorter == null or tray == null or tray.cards.is_empty() or _gliding():
		return 0
	var from := tray.front_card_pose()
	if held_box is SortingTray:
		var into := held_box as SortingTray
		if tray != sorter.surplus_tray or not into.has_room():
			return 0
		# Only as many as the tray has room for, the front ones; the rest
		# wait in the pocket. All in one go, so it's redrawn once.
		var tipped := sorter.take_surplus(into.room())
		tipped.reverse() # Its front card stays in front.
		into.add_cards(tipped)
		held_pack_changed.emit(into.set_code) # The corner's count changes.
		return tipped.size()
	if not _hands_empty():
		return 0
	var ids := sorter.take_needed() if tray == sorter.needed_tray else sorter.take_surplus()
	behind.assign(ids.slice(1))
	for id in ids:
		seen_cards[id] = true
	_hold(ids[0], from)
	return ids.size()


## How long Space is held to rip a pack open now: quicker with the pack
## knife.
func rip_time() -> float:
	return rip_seconds * (pack_knife_share if Progression.has_tool("pack_knife") else 1.0)


func take_new_shipping_box() -> ShippingBox:
	var box := ShippingBox.new()
	box.build()
	pile.add_child(box)
	box.global_transform = shipping_station.new_box_pose()
	take_box(box)
	return box


## Whether the collection still needs copy `id`: its own binder pocket is
## empty (or, for a rare card, its shadow box).
func collection_needs(id: int) -> bool:
	if Collection.is_rare(id):
		var number := Collection.card(id).collector_number
		for cabinet in cabinets:
			var slot := cabinet.slot_for(number)
			if slot >= 0:
				return cabinet.displayed[slot] < 0
		return false
	var binder := pile.binder_for(id)
	if binder == null:
		return false
	var pocket := Collection.card(id).collector_number - binder.binder.first
	return binder.contents.card_at(pocket) < 0


## What the card plate's chip says about copy `id` (Hud.CopyStatus):
## NEEDED while its pocket (or shadow box) is empty, DUPLICATE once another
## copy fills it, NONE for the copy that fills it or a card with no home.
func copy_status(id: int) -> int:
	if id < 0:
		return Hud.CopyStatus.NONE
	if collection_needs(id):
		return Hud.CopyStatus.NEEDED
	if Collection.is_rare(id):
		var number := Collection.card(id).collector_number
		for cabinet in cabinets:
			var slot := cabinet.slot_for(number)
			if slot >= 0:
				return Hud.CopyStatus.NONE if cabinet.displayed[slot] == id else Hud.CopyStatus.DUPLICATE
		return Hud.CopyStatus.NONE
	var binder := pile.binder_for(id)
	if binder == null:
		return Hud.CopyStatus.NONE
	var pocket := Collection.card(id).collector_number - binder.binder.first
	return Hud.CopyStatus.NONE if binder.contents.card_at(pocket) == id else Hud.CopyStatus.DUPLICATE


## Sells the card in hand into `box` (ShippingBox): the money comes now and
## the card is gone for good; it's sleeved and labelled on its way over and
## drops in. A card the collection doesn't have yet needs `confirmed` (the
## shop asks; Settings "confirm_new_sales" turns that off). Returns whether
## it was sold.
func sell_held_card(box: ShippingBox, confirmed := false) -> bool:
	if held_card_id < 0 or box == null or not box.has_room() or box == held_box or _gliding():
		return false
	var id := held_card_id
	if not confirmed and Settings.value("confirm_new_sales") and collection_needs(id):
		sale_confirm_requested.emit(box)
		return false
	var card := _card_copy(id)
	card.remove_meta("card_id") # Sold: nothing for a save to put back.
	var cents := Sales.sell(id)
	_sleeve(card, cents)
	var from := _held_view.global_transform
	_release_top()
	var via := box.card_entry_pose()
	var to := box.card_slot_pose()
	_glide = Glide.start(card, from, func() -> Transform3D: return via, glide_seconds(sell_seconds), put_down_lift)
	Glide.then(_glide, card, via, to, glide_seconds(sell_drop_seconds))
	_glide.tween_callback(func() -> void:
		if is_instance_valid(box):
			box.add_card(id)
		FeedbackSounds.play(pile, to.origin, FeedbackSounds.Kind.CARD_SOLD)
		card.queue_free())
	seen_cards.erase(id)
	card_sold.emit(id, cents)
	return true


## A card on its way to a shipping box: in a clear sleeve, with a little
## white label showing its price.
static func _sleeve(card: MeshInstance3D, cents: int) -> void:
	var sleeve := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = ShippingBox.SLEEVE
	sleeve.mesh = quad
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.92, 0.95, 1.0, 0.22)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.1
	clear.cull_mode = BaseMaterial3D.CULL_DISABLED
	sleeve.material_override = clear
	sleeve.position.z = 0.0006
	sleeve.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.add_child(sleeve)
	var label := MeshInstance3D.new()
	var paper := QuadMesh.new()
	paper.size = Vector2(0.036, 0.016)
	label.mesh = paper
	var white := StandardMaterial3D.new()
	white.albedo_color = ProductBox.LABEL_PAPER
	label.material_override = white
	label.position = Vector3(0.0, -0.03, 0.0012)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.add_child(label)
	var price := Label3D.new()
	price.text = Progression.money_text(cents)
	price.font = BinderLettering.FONT
	price.font_size = 48
	price.outline_size = 0
	price.modulate = ProductBox.INK
	price.pixel_size = 0.00022
	price.position = Vector3(0.0, -0.03, 0.0016)
	card.add_child(price)
	sleeve.scale = Vector3.ONE * 1.25
	label.scale = Vector3.ONE * 1.6
	var tween := card.create_tween().set_parallel()
	tween.tween_property(sleeve, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE, 0.12).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Picks a box of product up off the floor or a table.
func take_box(box: ProductBox) -> void:
	var from := box.global_transform
	_hold(-1)
	box.get_parent().remove_child(box)
	_camera.add_child(box)
	box.collision_layer = 0 # Not in the way of your aim (or you).
	held_box = box
	var held := Transform3D(Basis(Vector3.RIGHT, BOX_HELD_TILT), box_held_position(box))
	box.global_transform = from
	_glide = Glide.start(box, from, func() -> Transform3D: return _camera.global_transform * held,
		glide_seconds(binder_glide_seconds))
	held_pack_changed.emit(box.set_code)


## Where a box is held, below and in front of the eyes, further for a big one.
static func box_held_position(box: ProductBox) -> Vector3:
	var size := box.box_size()
	return Vector3(0.0, -0.12 - size.y, -0.25 - size.z)


## Where a box put down where you're aiming would stand (global): on the
## pile, or on the table or card you're aiming at, its front toward you.
func box_drop_pose(box: ProductBox) -> Transform3D:
	var yaw := _camera.global_rotation.y
	var half := box.half_footprint()
	var local := pile.to_local(_aim_point)
	var p := Vector2(local.x, local.z)
	var y := local.y
	if _aim == Aim.FLOOR or local.y < 0.05:
		p = pile.clear_point(p, half, yaw)
		y = pile.height_under(p, half, yaw)
	else:
		p = pile.onto_surface(p, yaw, half)
	return pile.global_transform * Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y, p.y))


## Puts the box in hand down where you're aiming.
func put_down_box() -> void:
	var box := held_box
	var to := box_drop_pose(box)
	if box is ShippingBox and sorter != null and sorter.snaps_to_dock(to.origin):
		to = sorter.dock_pose() # Into place at the surplus chute.
	var from := box.global_transform
	held_box = null
	box.get_parent().remove_child(box)
	pile.add_child(box)
	box.global_transform = from
	_glide = Glide.start(box, from, func() -> Transform3D: return to, glide_seconds(binder_glide_seconds))
	_glide.tween_callback(func() -> void: box.collision_layer = Binder.PHYSICS_LAYER)
	held_pack_changed.emit("")


## Puts the pack in hand down, lying where you're aiming, unless it's
## started to tear.
func put_down_pack() -> void:
	var pack := held_pack
	if pack.tear > 0.0:
		return
	var local := pile.to_local(_aim_point)
	var p := Vector2(local.x, local.z)
	var y := local.y if _aim != Aim.FLOOR else pile.height_at(p)
	var from := pack.global_transform
	held_pack = null
	_hold(-1)
	pack.lie(pile, pile.to_global(Vector3(p.x, y, p.y)), _camera.global_rotation.y)
	var to := pack.global_transform
	pack.global_transform = from
	_glide = Glide.start(pack, from, func() -> Transform3D: return to, glide_seconds(card_glide_seconds))
	held_pack_changed.emit("")


## Opens a box of product, in hand or lying about. A booster box tips its
## packs out in a heap where it stands (or where you're aiming, or at your
## feet, from your hand); a bulk box tips its cards out there, onto the
## table or the floor. Opening a set's product unlocks the set (for now).
## Returns the packs tipped out, or the copies made.
func open_box(box: ProductBox) -> Array:
	if not is_product(box):
		return [] # Not product: E uses the laptop, and seals a shipping box.
	var at := box.global_position
	if box == held_box:
		if _aim in [Aim.FLOOR, Aim.SURFACE, Aim.LOOSE_CARD]:
			at = box_drop_pose(box).origin
		else:
			var ahead := _camera.global_position - _camera.global_basis.z.slide(Vector3.UP).normalized() * 0.6
			var local := pile.to_local(ahead)
			at = pile.to_global(Vector3(local.x, 0.0, local.z))
		held_box = null
		held_pack_changed.emit("")
	box.get_parent().remove_child(box)
	box.queue_free()
	FeedbackSounds.play(pile, at, FeedbackSounds.Kind.PACK_RIP)
	if box.kind == ProductBox.Kind.BULK:
		var copies := Collection.add_all(PackContents.bulk_box(box.set_code, _pack_rng))
		Achievements.cards_found(copies)
		pile.tip_out(copies, at, _pack_rng.randi())
		return Array(copies)
	return tip_out_packs(box.set_code, PackContents.BOX_PACKS, at)


## A booster box's packs tumble out in a loose heap around `at` (global,
## where the box stood): on the table there, or the floor. Returns them.
func tip_out_packs(code: String, count: int, at: Vector3) -> Array:
	var local := pile.to_local(at)
	var on_floor := local.y < 0.05
	var packs := []
	var placed: Array[Vector3] = []
	for i in count:
		var p := Vector2(local.x, local.z) + Vector2(_pack_rng.randfn(0.0, 0.07), _pack_rng.randfn(0.0, 0.07))
		var yaw := _pack_rng.randf() * TAU
		if on_floor:
			p = pile.clear_point(p, BoosterPack.SIZE / 2, yaw)
		else:
			p = pile.onto_surface(p, yaw, BoosterPack.SIZE / 2)
		var y := pile.height_at(p) if on_floor else local.y
		for other in placed:
			if Vector2(other.x, other.z).distance_to(p) < BoosterPack.SIZE.x:
				y = maxf(y, other.y + BoosterPack.THICKNESS)
		placed.append(Vector3(p.x, y, p.y))
		var pack := BoosterPack.new()
		pack.setup(code)
		pack.lie(pile, pile.to_global(Vector3(p.x, y, p.y)), yaw)
		packs.append(pack)
	return packs


## Space on a pack in hand: start ripping, bringing it up close if it isn't.
func _start_ripping() -> void:
	_ripping = true
	if not _zoomed:
		_set_zoomed(true)


## How far the tear has run when ripping's `amount` of the way along:
## slowly at first, and not all the way (the burst finishes it).
static func rip_tear(amount: float) -> float:
	return pow(clampf(amount, 0.0, 1.0), RIP_TEAR_CURVE) * RIP_TEAR_AT_BURST


func _process(delta: float) -> void:
	if _pack_effects == null:
		return
	repeat_tray_drop(delta, Input.is_action_pressed(Controls.USE_HAND) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if _ripping and (held_pack == null or not Input.is_action_pressed(Controls.RIP)):
		_ripping = false
	if _ripping and not _gliding():
		_rip = minf(1.0, _rip + delta / rip_time())
		held_pack.set_tear(rip_tear(_rip))
		# It shakes harder the further it's torn, quick and uneven.
		var strength := lerpf(0.08, 1.0, _rip * _rip)
		var t := Time.get_ticks_msec() / 1000.0
		_shake = Transform3D(
			Basis.from_euler(Vector3(sin(t * 61.0), sin(t * 47.0 + 1.3), sin(t * 53.0 + 2.1)) * RIP_SHAKE_TURN * strength),
			Vector3(sin(t * 71.0), sin(t * 67.0 + 0.7), 0.0) * RIP_SHAKE * strength)
		_pose_held_card()
		if _rip >= 1.0:
			rip_pack()
	elif _shake != Transform3D.IDENTITY:
		_shake = Transform3D.IDENTITY
		_pose_held_card()
	# The room dims as the pack tears, stays dim while its cards are shown,
	# and comes back once they all have been (or the hand's lowered).
	if not _zoomed:
		revealing = 0
		_linger = 0.0
		_revealed_all = false
	_linger = maxf(_linger - delta, 0.0)
	var veil := 0.0
	if _ripping:
		veil = smoothstep(0.0, 1.0, _rip)
	elif revealing > 0 or _linger > 0.0:
		veil = 1.0
	_pack_effects.set_veil(veil)


## Tears the pack in hand open with a flash: its cards (new copies, see
## PackContents) are in your hand, up close, in the order they're revealed.
## Returns them.
func rip_pack() -> Array[int]:
	var pack := held_pack
	if pack == null:
		return []
	var ids: Array[int] = []
	ids.assign(Collection.add_all(PackContents.draw(pack.set_code, _pack_rng)))
	Achievements.cards_found(ids)
	held_pack = null
	_ripping = false
	_rip = 0.0
	_shake = Transform3D.IDENTITY
	# The pack's gone in the flash, but for the torn strip flying off.
	pack.get_node("Body").visible = false
	pack.burst(pack_burst_seconds)
	pack.create_tween().tween_callback(pack.queue_free).set_delay(pack_burst_seconds)
	_pack_effects.flash()
	FeedbackSounds.play(pile, _camera.global_position, FeedbackSounds.Kind.PACK_RIP)
	held_pack_changed.emit("")
	_hold(-1)
	if ids.is_empty():
		return ids
	behind.assign(ids.slice(1))
	_hold(ids[0])
	for id in ids:
		seen_cards[id] = true
	_zoomed = true
	_emerge = 1.0
	_set_zoom_amount(1.0)
	var emerge := create_tween()
	emerge.tween_method(_set_emerge, 1.0, 0.0, emerge_seconds).set_delay(emerge_delay) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	revealing = ids.size() - 1
	_revealed_all = revealing == 0
	_reveal_flourish(ids[0])
	return ids


func _set_emerge(amount: float) -> void:
	_emerge = amount
	_pose_held_card()


## Space with cards in hand: the one on top slides off to the back and the
## next comes up. While a pack's being revealed, a rare or a mythic comes
## up with a glow.
func reveal_next() -> void:
	if behind.is_empty() or held_card_id < 0:
		return
	var outgoing := _card_copy(held_card_id)
	outgoing.reparent(_camera, false)
	var start := _held_view.transform.translated_local(Vector3(0, 0, 0.001))
	var end := start.translated_local(Vector3(0.09, -0.05, -0.03)).rotated_local(Vector3.BACK, -0.5).scaled_local(Vector3.ONE * 0.7)
	outgoing.transform = start
	var tween := outgoing.create_tween()
	tween.tween_method(func(t: float) -> void: outgoing.transform = start.interpolate_with(end, t), 0.0, 1.0,
		glide_seconds(reveal_seconds)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(outgoing.queue_free)
	var zoomed := _zoomed
	cycle_hand(1)
	if zoomed:
		_zoomed = true
		_set_zoom_amount(1.0)
	_pack_effects.end_glow()
	if revealing > 0:
		revealing -= 1
		_reveal_flourish(held_card_id)
		if revealing == 0:
			_linger = REVEAL_LINGER
			_revealed_all = true


## A rare or mythic just revealed glows (gold or orange-red) and chimes.
## Every revealed card gets its value tag (card_revealed).
func _reveal_flourish(id: int) -> void:
	card_revealed.emit(id)
	match Collection.card(id).rarity:
		CardData.Rarity.MYTHIC:
			_pack_effects.glow(PackEffects.MYTHIC_GLOW, _held_view.position)
			FeedbackSounds.play(pile, _camera.global_position, FeedbackSounds.Kind.MYTHIC_REVEALED)
		CardData.Rarity.RARE:
			_pack_effects.glow(PackEffects.RARE_GLOW, _held_view.position)
			FeedbackSounds.play(pile, _camera.global_position, FeedbackSounds.Kind.RARE_REVEALED)


## The held card's orientation: `euler` (as Node3D.rotation) with the card
## turned `turn` of the way over (0 face up, 1 showing its back) and
## `sideways` of a quarter turn clockwise as you look at it.
static func held_basis(euler: Vector3, turn: float, sideways := 0.0) -> Basis:
	return Basis.from_euler(euler) * Basis(Vector3.BACK, -PI / 2.0 * sideways) * Basis(Vector3.UP, PI * turn)


## With empty hands, F on a card in an open binder's pocket or in a shadow
## box brings it up close, as if held, until F again sends it back. Returns
## false if there's no card there.
func view_aimed() -> bool:
	if _aim == Aim.BINDER and _aim_pocket >= 0 and _aim_binder.is_open():
		var binder := _aim_binder
		var pocket := _aim_pocket
		var id := binder.contents.card_at(pocket)
		if id < 0:
			return false
		_view(id, func() -> Transform3D: return binder.pocket_pose(pocket),
			func(lifted: bool) -> void: binder.set_lifted(pocket if lifted else -1))
		return true
	if _aim == Aim.CABINET and _aim_slot >= 0 and _aim_cabinet.displayed[_aim_slot] >= 0:
		var cabinet := _aim_cabinet
		var slot := _aim_slot
		_view(cabinet.displayed[slot], func() -> Transform3D: return cabinet.slot_pose(slot),
			func(lifted: bool) -> void: cabinet.set_lifted(slot, lifted))
		return true
	return false


func _view(id: int, home: Callable, lift: Callable) -> void:
	_viewed_id = id
	_viewed_home = home
	_viewed_lift = lift
	lift.call(true)
	CardView.apply(_held_view.material_override, id)
	_zoomed = true
	_zoom_amount = 1.0
	_tilt = Vector2.ZERO
	_pose_held_card()
	var close := _held_view.transform
	var from: Transform3D = home.call()
	_held_view.global_transform = from
	_held_view.visible = true
	_glide = Glide.start(_held_view, from, func() -> Transform3D: return _camera.global_transform * close,
		glide_seconds(card_glide_seconds))


## Sends the card up close back to its pocket or shadow box, turning face up
## and upright on the way.
func _end_viewing() -> void:
	for tween in [_zoom_tween, _turn_tween, _sideways_tween]:
		if tween:
			tween.kill()
	_zoomed = false
	_turned_over = false
	_sideways = false
	_glide = Glide.start(_held_view, _held_view.global_transform, _viewed_home, glide_seconds(card_glide_seconds))
	_glide.tween_callback(_finish_viewing)


func _finish_viewing() -> void:
	_viewed_lift.call(false)
	_viewed_id = -1
	_zoom_amount = 0.0
	_tilt = Vector2.ZERO
	_turn_amount = 0.0
	_sideways_amount = 0.0
	_held_view.visible = held_card_id >= 0
	_pose_held_card()


## Puts card `id` on top of the hand, the old top card going just behind it
## (see _hold for `from`, `seconds` and `lift`).
func _take_in_hand(id: int, from = null, seconds := -1.0, lift := 0.0) -> void:
	var first_rare := Collection.is_rare(id) and not seen_cards.keys().any(Collection.is_rare)
	if first_rare:
		rare_card_found.emit.call_deferred()
	if held_card_id >= 0:
		behind.push_front(held_card_id)
	_hold(id, from, seconds, lift)


## The top card has left the hand: the next one comes up, if there is one.
func _release_top() -> void:
	_hold(behind.pop_front() if not behind.is_empty() else -1)


## Redraws the cards behind the top one.
func _refresh_fan() -> void:
	for i in mini(behind.size(), _fan_views.size()):
		CardView.apply(_fan_views[i].material_override, behind[i])
	_show_fan()


## Shows the cards behind the top one, fanned out, except while inspecting.
func _show_fan() -> void:
	for i in _fan_views.size():
		_fan_views[i].visible = i < behind.size() and _zoom_amount < 0.05


## Puts card `id` on top of the hand in place of the top card (-1 for none;
## the cards behind stay). Given `from`, a global card
## pose, the card glides up to the hand from there, taking `seconds` (a
## normal pick-up's if negative; before Snap) and arcing `lift` metres up.
func _hold(id: int, from = null, seconds := -1.0, lift := 0.0) -> void:
	if _zoom_tween:
		_zoom_tween.kill()
	for tween in [_turn_tween, _sideways_tween]:
		if tween:
			tween.kill()
	_zoomed = false
	_zoom_amount = 0.0
	_tilt = Vector2.ZERO
	_turned_over = false
	_turn_amount = 0.0
	_sideways = false
	_sideways_amount = 0.0
	held_card_id = -1
	_pose_held_card()
	held_card_id = id
	if id >= 0 and from is Transform3D:
		var held := _held_view.transform
		_glide = Glide.start(_held_view, from, func() -> Transform3D: return _camera.global_transform * held,
			glide_seconds(seconds if seconds >= 0.0 else card_glide_seconds), lift)
	_held_view.visible = id >= 0
	_refresh_fan()
	if id < 0:
		held_changed.emit(null, null)
		return
	seen_cards[id] = true
	CardView.apply(_held_view.material_override, id)
	held_changed.emit(Collection.card(id), null)
