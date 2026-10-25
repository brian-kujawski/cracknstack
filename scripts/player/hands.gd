class_name Hands
extends Node
## The player's hands. One thing at a time: a card (a few, with Harmonize)
## or a binder.
##
## Keys and buttons are named here by their Controls actions (shown in
## comments as the default bindings). Left-click is context sensitive:
## - empty-handed: pick up the card under the crosshair (from the floor, a
##   table, or an unlocked card in an open binder), or pick up a closed
##   binder (off the floor, a table or a shelf);
## - holding a card: file it into the binder pocket you're looking at, or put
##   it down where you're looking (on the floor it rejoins the pile);
## - carrying a binder: set it down where you're looking, or stand it in the
##   shelf space you're looking at.
## Putting something down happens when the button comes back up. Hold the
## button and a ghost shows where it will go, following your aim, so you can
## place it carefully; a quick click just puts it where you're looking.
## Right-click tosses a held card back onto the pile (or a table, if it
## comes down on one), or a carried binder, which tumbles through the air
## past other binders and settles on whatever it comes down on. F brings
## the held card up close to inspect it (F again lowers it). E opens or closes the binder
## you're looking at, and the mouse wheel turns its pages.
##
## Right-click with empty hands, aimed at the pile or cards on a table, flips
## them: a few of the top cards there jump up, spin and land face up or down
## at random. Cards on tables count as lying about just like floor cards, for
## everything below.
##
## Upgrades bought with Mana (see Progression) change some of this: Snap
## speeds up every glide, Spider Climb lengthens your reach, Remember the
## Fallen names cards you've held wherever you see them again, Enlightened
## Tutor shows the set of a card lying about that you look at (at rank II,
## the whole card), and Unmask flips more
## cards, more of them face up; with Demonic Consultation, flipped cards for
## an open binder hover, ready to grab. Harmonize lets you hold several cards: a
## quick click on another card picks it up too (hold the button to put the
## top one down instead), and the wheel cycles which is on top when you're
## not aiming at an open binder. Brainstorm sends missing cards flying into
## a binder when you finish one of its pages by hand. Shunt files the card in hand into its own
## pocket wherever you click on its open pages. Sorceries: Tithe (1) lights
## up missing cards for the binder you hold or look at (with Serra's
## Blessing, always), Teleport (2) sends
## the top card to its binder, Demonic Tutor (3) brings the card for the
## aimed pocket up out of the pile, Chain Lightning (4) makes your next
## lock-in light up a missing card from that page where it lies, and
## Abundance (5) fills your hand with the cards that come next.
##
## Cards and binders glide between the world and the hand rather than jumping;
## while one is on its way, the hands take no new orders.
##
## While a card is up close, the view holds still and the mouse tilts the card
## instead, directly and within a narrow range, like turning it in your hand.

signal held_changed(card: CardData, binder: BinderRange)
## The card whose details to show: the one in hand, or else a card you're
## looking at that you've held before (null for none). With `set_only`, all
## you know is its set (Enlightened Tutor).
signal shown_card_changed(card: CardData, set_only: bool)
## What the binder under the crosshair holds and what you can do with it.
signal hint_changed(text: String)

enum Aim { NONE, FLOOR, SURFACE, BINDER, LOOSE_CARD, SHELF }

## How far from the eye the player can reach, and with Spider Climb.
@export var reach := 2.6
@export var spider_climb_reach := 3.4
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
## Demonic Tutor: the card flies up out of the pile in an arc this high, and
## takes this long plus this much per metre (at most the cap).
@export var tutor_lift := 0.5
@export var tutor_seconds := 0.3
@export var tutor_seconds_per_metre := 0.08
@export var tutor_seconds_max := 1.0
## Teleport: the card flies to its binder in an arc this high, taking this
## long plus this much per metre (at most the cap).
@export var teleport_lift := 0.6
@export var teleport_seconds := 0.35
@export var teleport_seconds_per_metre := 0.06
@export var teleport_seconds_max := 1.2
## Chain Lightning: how long the cards it finds glow.
@export var chain_lightning_glow_seconds := 15.0
## Pile flip: cards jump up at this speed (m/s), drift sideways up to this
## speed, and tumble at the toss's flip rates.
@export var flip_up_speed_min := 1.6
@export var flip_up_speed_max := 2.2
@export var flip_drift_speed_max := 0.4
## Holding the button this long before letting go shows the ghost.
@export var ghost_after_seconds := 0.12
## How far a card up close can tilt each way (degrees), on both axes. Kept
## narrow so the card never turns far enough to show it's a flat quad.
@export var inspect_tilt_degrees := 15.0

## Where the held card sits relative to the camera: low and to the right,
## or close up and square to your face (see zoomed_distance).
const HELD_POSITION := Vector3(0.075, -0.05, -0.2)
const HELD_ROTATION := Vector3(0.12, -0.25, 0.04)
const ZOOMED_ROTATION := Vector3.ZERO
## How much of the screen's height a card up close fills, at any field of view.
const ZOOMED_SCREEN_FILL := 0.75
## A carried binder: held to the right, cover tilted toward you. High and
## close enough that all of it stays in view, and that it stays clear of a
## table top while you lean over one.
const CARRIED_POSITION := Vector3(0.22, -0.07, -0.44)
const CARRIED_ROTATION := Vector3(0.7, -0.5, 0.0)
## How many times faster every glide is at each rank of Snap (none, I, II).
const SNAP_SPEEDUP := [1.0, 1.5, 2.0]
## Cards you can hold at each rank of Harmonize (none, I, II, III).
const HAND_SIZES := [1, 3, 7, 15]
## Pile flip at each rank of Unmask (none, I, II): cards tossed, and the
## chance each lands face up.
const FLIP_COUNTS := [4, 8, 16]
const FLIP_FACE_UP_CHANCE := [0.5, 0.75, 1.0]
## Brainstorm at each rank (I, II, III): cards it pulls in.
const BRAINSTORM_CARDS := [1, 3, 9]
## Serra's Blessing tops up its glow this often.
const BLESSING_REFRESH_SECONDS := 0.5
## Demonic Consultation at each rank (I, II): how long flipped cards for an
## open binder hover.
const CONSULTATION_SECONDS := [5.0, 15.0]
## Tithe at each rank (I, II, III): missing cards lit (0 for all of them)
## and for how long.
const TITHE_CARDS := [5, 10, 0]
const TITHE_SECONDS := [5.0, 10.0, 15.0]
## Chain Lightning at each rank (I, II, III): missing cards from the page it
## lights. 0 means all of them.
const CHAIN_LIGHTNING_CARDS := [1, 3, 0]
## Cards held behind the top one fan out up and to the right, this far apart;
## past MAX_FANNED only the count is felt, not seen.
const FAN_STEP := Vector3(0.007, 0.006, -0.002)
const FAN_TURN := 0.05
const MAX_FANNED := 6

var pile: PileWorld
## The top card in hand, or -1.
var held_card_id := -1
## The rest of the hand, behind the top card in order (Harmonize).
var behind: Array[int] = []
## Cards still flying into the hand (Abundance). They're already in
## `behind`; the fan shows once they've all arrived.
var _incoming := 0
var carried_binder: Binder
## Every card you've held at least once, by id. With Remember the Fallen
## you know one of these wherever you see it again.
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
## The glide in progress, if any: something coming to hand or being put down.
var _glide: Tween
## While the button is held to put something down: how long it's been held.
## -1 when not placing.
var _placing := -1.0
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
var _hovered_binder: Binder
var _hint := ""
var _shown_card: CardData
var _shown_set_only := false
## Serra's Blessing: the binder whose missing cards glow, and when it next
## refreshes them.
var _blessed: Binder
var _blessing_refresh := 0.0


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


func _physics_process(delta: float) -> void:
	if pile == null:
		return
	_update_aim()
	_aim_floor_card = pile.top_card_at(_aim_point) if _aim == Aim.FLOOR else -1
	pile.set_highlight(_aim_lying_card() if has_room() else -1)
	_update_hover()
	_update_blessing(delta)
	_update_ghost(delta)
	_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	if pile == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
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
	elif event.is_action_pressed(Controls.USE_HAND):
		_use_hand()
	elif event.is_action_pressed(Controls.TOSS) and held_card_id >= 0:
		_toss()
		_release_top()
	elif event.is_action_pressed(Controls.TOSS) and carried_binder != null:
		toss_binder()
	elif event.is_action_pressed(Controls.TOSS):
		flip_pile()
	elif event.is_action_pressed(Controls.INTERACT):
		_toggle_binder()
	elif event.is_action_pressed(Controls.INSPECT) and held_card_id >= 0:
		_set_zoomed(not _zoomed)
	elif event.is_action_pressed(Controls.FLIP_NEXT):
		_flip(1)
	elif event.is_action_pressed(Controls.FLIP_PREVIOUS):
		_flip(-1)
	elif event.is_action_pressed(Controls.CAST_TITHE):
		cast_tithe()
	elif event.is_action_pressed(Controls.CAST_ABUNDANCE):
		cast_abundance()
	elif event.is_action_pressed(Controls.CAST_TELEPORT):
		cast_teleport()
	elif event.is_action_pressed(Controls.CAST_DEMONIC_TUTOR):
		cast_demonic_tutor()
	elif event.is_action_pressed(Controls.CAST_CHAIN_LIGHTNING):
		Progression.arm("Chain Lightning")


func _hands_empty() -> bool:
	return held_card_id < 0 and carried_binder == null


## How many cards you can hold, with Harmonize.
func hand_size() -> int:
	return HAND_SIZES[Progression.rank("Harmonize")]


func hand_count() -> int:
	return (1 if held_card_id >= 0 else 0) + behind.size()


## Whether another card can come into your hand.
func has_room() -> bool:
	return carried_binder == null and hand_count() < hand_size()


func _gliding() -> bool:
	return _glide != null and _glide.is_running()


func _use_hand() -> void:
	if carried_binder != null:
		if _aim == Aim.SHELF:
			_shelve_carried_binder()
		elif _can_put_down():
			_placing = 0.0
		return
	if held_card_id >= 0:
		if _try_file_held_card():
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


## Takes the card under the crosshair into your hand, on top: off the floor,
## a table, or out of an open binder's pocket (unless it's locked in).
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
			if pile.is_lying(card.card_id):
				pile.pick_up(card.card_id)
			else:
				card.queue_free() # Hovering (Demonic Consultation).
			_take_in_hand(card.card_id, from)
			return true
		Aim.BINDER:
			if _aim_binder.is_open() and _aim_pocket >= 0:
				var from := _aim_binder.pocket_pose(_aim_pocket)
				var id := _aim_binder.take(_aim_pocket)
				if id >= 0:
					_take_in_hand(id, from)
					return true
	return false


## Files the held card into the binder pocket under the crosshair. Returns
## false if there's no pocket there (so the click does something else).
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
	if binder.contents.card_at(pocket) >= 0:
		_pick_up_aimed() # With room in hand, a misplaced card comes out.
		return true # The pocket's taken; the card stays in hand.
	var id := held_card_id
	_put_down_card(binder.pocket_pose(pocket), func() -> void: _file(binder, pocket, id),
		binder.pocket_entry_pose(pocket)).set_meta("pocket", [binder, pocket])
	return true


## Shunt: with the held card's own pocket in this binder empty, that's
## where a click anywhere on the binder files it. Shunt I needs the pocket's
## page open, Shunt II just the binder open (it turns to the page), and
## Shunt III files into a closed binder too. -1 without Shunt, or if it
## doesn't apply.
func shunt_pocket(binder: Binder) -> int:
	var rank := Progression.rank("Shunt")
	if rank == 0 or held_card_id < 0 or (rank < 3 and not binder.is_open()):
		return -1
	var card := CardDatabase.get_card(held_card_id)
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
		return # Misplaced: it stays in the pocket glowing red, and makes no sound.
	Progression.card_filed_by_hand()
	_locked_in(binder, pocket)
	if binder.contents.is_page_complete(pocket / BinderLayout.POCKETS_PER_PAGE):
		brainstorm(binder)


## Brainstorm: a page just finished by hand pulls missing cards for this
## binder's other pages up out of the pile, at random, and they fly into
## their pockets. Pages they finish don't set it off again, so it never
## chains. Returns the cards sent.
func brainstorm(binder: Binder) -> Array[int]:
	var rank := Progression.rank("Brainstorm")
	if rank == 0:
		return []
	var missing := _missing_lying(binder)
	missing.shuffle()
	missing = missing.slice(0, BRAINSTORM_CARDS[rank - 1])
	for id in missing:
		var pocket := CardDatabase.get_card(id).collector_number - binder.binder.first
		var from := pile.card_pose(id)
		pile.pick_up(id)
		_fly_to_pocket(id, from, binder, pocket, func() -> void:
			FeedbackSounds.play(pile, binder.global_position, FeedbackSounds.Kind.CARD_LOCKED))
	return missing


## A card locked into its pocket, by hand or by Teleport: the chime, Chain
## Lightning if it's armed, and the card's achievement if it has one.
func _locked_in(binder: Binder, pocket: int) -> void:
	var page := pocket / BinderLayout.POCKETS_PER_PAGE
	Achievements.card_filed(CardDatabase.get_card(binder.contents.card_at(pocket)))
	if Progression.fire("Chain Lightning"):
		_strike_chain_lightning(binder, page)
	var sound := FeedbackSounds.Kind.CARD_LOCKED
	if binder.contents.is_complete():
		sound = FeedbackSounds.Kind.BINDER_COMPLETE
	elif binder.contents.is_page_complete(page):
		sound = FeedbackSounds.Kind.PAGE_COMPLETE
	FeedbackSounds.play(pile, binder.to_global(binder.pocket_position(pocket)), sound)


## Chain Lightning goes off: missing cards from this binder page that lie
## about (on the floor or a table) glow where they are, some or all of them
## by rank.
func _strike_chain_lightning(binder: Binder, page: int) -> Array[int]:
	var first := page * BinderLayout.POCKETS_PER_PAGE
	var missing: Array[int] = []
	var cards := CardDatabase.cards_in_set(binder.binder.set_code)
	for pocket in range(first, mini(first + BinderLayout.POCKETS_PER_PAGE, binder.contents.capacity())):
		var id := cards[binder.binder.first + pocket - 1].id
		if not binder.contents.is_locked(pocket) and pile.is_lying(id):
			missing.append(id)
	missing.shuffle()
	var count: int = CHAIN_LIGHTNING_CARDS[maxi(Progression.rank("Chain Lightning"), 1) - 1]
	if count > 0:
		missing = missing.slice(0, count)
	pile.glow(missing, chain_lightning_glow_seconds)
	return missing


## Serra's Blessing: Tithe is always on, at full strength, for the binder you
## carry, or else the last open binder you looked at, for as long as it
## stays open. The glow is topped up now and then, so it lingers a moment
## after you move on.
func _update_blessing(delta: float) -> void:
	if Progression.rank("Serra's Blessing") == 0:
		_blessed = null
		return
	if carried_binder != null:
		_blessed = carried_binder
	elif _aim == Aim.BINDER and _aim_binder.is_open():
		_blessed = _aim_binder
	elif _blessed != null and not _blessed.is_open():
		_blessed = null
	_blessing_refresh -= delta
	if _blessed == null or _blessing_refresh > 0.0:
		return
	_blessing_refresh = BLESSING_REFRESH_SECONDS
	pile.glow(_missing_lying(_blessed), BLESSING_REFRESH_SECONDS * 2.0)


## The cards a binder still needs that are lying about, on the floor or a
## table.
func _missing_lying(binder: Binder) -> Array[int]:
	var missing: Array[int] = []
	var cards := CardDatabase.cards_in_set(binder.binder.set_code)
	for pocket in binder.contents.capacity():
		var id := cards[binder.binder.first + pocket - 1].id
		if binder.contents.card_at(pocket) < 0 and pile.is_lying(id):
			missing.append(id)
	return missing


## Tithe: missing cards for the binder you're carrying or looking at, picked
## at random from wherever they lie, on the floor or a table, glow for a
## while. How many
## and how long go up with rank. Returns the cards lit.
func cast_tithe() -> Array[int]:
	var binder := carried_binder if carried_binder != null else (_aim_binder if _aim == Aim.BINDER else null)
	if binder == null or not Progression.can_cast("Tithe"):
		return []
	var missing := _missing_lying(binder)
	if missing.is_empty():
		return []
	var rank := Progression.rank("Tithe")
	missing.shuffle()
	if TITHE_CARDS[rank - 1] > 0:
		missing = missing.slice(0, TITHE_CARDS[rank - 1])
	Progression.cast("Tithe")
	pile.glow(missing, TITHE_SECONDS[rank - 1])
	return missing


## Abundance: holding a card, the unfiled cards that come next in its set,
## in collector order, rise from wherever they lie into your hand behind
## it, until your hand is full. Holding KTK #012 with room for two more
## brings up #013 and #014. Cards locked in, or nowhere to be had (in
## flight), are skipped. Returns the cards brought.
func cast_abundance() -> Array[int]:
	if not Progression.can_cast("Abundance") or held_card_id < 0 or not has_room() or _gliding():
		return []
	var top := CardDatabase.get_card(held_card_id)
	var cards := CardDatabase.cards_in_set(top.set_code)
	var brought: Array[int] = []
	var poses := []
	for number in range(top.collector_number + 1, cards.size() + 1):
		if hand_count() + brought.size() >= hand_size():
			break
		var id := cards[number - 1].id
		var binder := pile.binder_for(id)
		if binder != null and binder.contents.is_locked(number - binder.binder.first):
			continue
		var from = pile.take_from_anywhere(id)
		if from != null:
			brought.append(id)
			poses.append(from)
	if brought.is_empty():
		return []
	Progression.cast("Abundance")
	var old := behind.duplicate()
	behind.assign(brought + old)
	for i in brought.size():
		var id := brought[i]
		seen_cards[id] = true
		var from: Transform3D = poses[i]
		var card := _card_copy(id)
		var flight := minf(tutor_seconds + tutor_seconds_per_metre * from.origin.distance_to(_camera.global_position),
			tutor_seconds_max)
		_incoming += 1
		Glide.start(card, from, func() -> Transform3D: return _camera.global_transform * _fan_views[0].transform,
			glide_seconds(flight), tutor_lift).tween_callback(func() -> void:
				card.queue_free()
				_incoming -= 1
				_refresh_fan())
	_refresh_fan()
	return brought


## Teleport: the top card in hand flies to its own binder, wherever it is
## (buried, closed, on a shelf, across the room), and files itself; at rank
## II, so does every card in hand. A card with a wrong card sitting in its
## pocket stays in hand. Returns whether it was cast.
func cast_teleport() -> bool:
	if not Progression.can_cast("Teleport") or held_card_id < 0 or _gliding():
		return false
	var hand: Array[int] = [held_card_id]
	if Progression.rank("Teleport") >= 2:
		hand.append_array(behind)
	var sent: Array[int] = []
	for id in hand:
		var binder := pile.binder_for(id)
		if binder != null and binder.contents.card_at(CardDatabase.get_card(id).collector_number - binder.binder.first) < 0:
			sent.append(id)
	if sent.is_empty():
		return false
	Progression.cast("Teleport")
	var from := _held_view.global_transform
	for id in sent:
		var binder := pile.binder_for(id)
		var pocket := CardDatabase.get_card(id).collector_number - binder.binder.first
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


## Demonic Tutor: aimed at an empty pocket of an open binder with room in
## hand, its card rises from wherever it lies into your hand, on top. Filing
## it is up to you. Returns whether it was cast.
func cast_demonic_tutor() -> bool:
	if not Progression.can_cast("Demonic Tutor") or not has_room() or _gliding():
		return false
	if _aim != Aim.BINDER or not _aim_binder.is_open() or _aim_pocket < 0 \
			or _aim_binder.contents.card_at(_aim_pocket) >= 0:
		return false
	var binder := _aim_binder.binder
	var id := CardDatabase.cards_in_set(binder.set_code)[binder.first + _aim_pocket - 1].id
	var from = pile.take_from_anywhere(id)
	if from == null:
		return false
	Progression.cast("Demonic Tutor")
	var flight := minf(tutor_seconds + tutor_seconds_per_metre * from.origin.distance_to(_camera.global_position),
		tutor_seconds_max)
	_take_in_hand(id, from, flight, tutor_lift)
	return true


## The pile flip: aimed at the floor (or a table) with empty hands, the
## topmost cards there jump up, spin and fall back down, each landing face
## up or down at random. Unmask flips more of them, and more land face up.
## Returns the cards flipped.
func flip_pile() -> Array[int]:
	if not _hands_empty() or _aim not in [Aim.FLOOR, Aim.SURFACE, Aim.LOOSE_CARD]:
		return []
	var rank := Progression.rank("Unmask")
	var ids := pile.flip_cards(_aim_point, FLIP_COUNTS[rank])
	var consultation := Progression.rank("Demonic Consultation")
	for id in ids:
		var from := pile.card_pose(id)
		var binder := pile.binder_for(id)
		if consultation > 0 and binder != null and binder.is_open():
			# Demonic Consultation: it hangs in the air, ready to grab.
			var lying := pile.card_position(id)
			pile.pick_up(id)
			var hovering := HoveringCard.new()
			pile.add_child(hovering)
			hovering.hover(id, pile, pile.to_global(lying), _yaw_facing_player(pile.to_global(lying)), binder,
				CONSULTATION_SECONDS[consultation - 1])
			continue
		pile.pick_up(id)
		var card := TossedCard.new()
		pile.add_child(card)
		card.exclude = [(get_parent() as CollisionObject3D).get_rid()]
		card.land_face_up = 1 if randf() < FLIP_FACE_UP_CHANCE[rank] else 0
		var drift := Vector2.from_angle(randf() * TAU) * randf() * flip_drift_speed_max
		var velocity := Vector3(drift.x, randf_range(flip_up_speed_min, flip_up_speed_max), drift.y)
		var flips := randf_range(toss_flips_per_second_min, toss_flips_per_second_max) * (1 if randf() < 0.5 else -1)
		var spin := randf_range(-toss_spin_per_second_max, toss_spin_per_second_max)
		card.launch(id, pile, _card_material(id), from.translated(Vector3.UP * 0.01), velocity,
			Vector3(flips, 0.0, spin) * TAU)
	return ids


func _toggle_binder() -> void:
	if carried_binder != null or _aim != Aim.BINDER:
		return
	if _aim_binder.is_open():
		_aim_binder.close()
	elif _aim_binder.state == Binder.State.CLOSED:
		_aim_binder.open()


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
	var correct := shelf.shelve(_aim_space, binder)
	held_changed.emit(null, null)
	var to := binder.global_transform
	_glide = Glide.start(binder, from, func() -> Transform3D: return to, glide_seconds(binder_glide_seconds))
	if correct:
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


## How far you can reach now, with Spider Climb.
func current_reach() -> float:
	return spider_climb_reach if Progression.rank("Spider Climb") > 0 else reach


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
	_aim_binder = null
	_aim_pocket = -1
	_aim_loose_card = null
	_aim_shelf = null
	_aim_space = -1
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * current_reach()
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [(get_parent() as CollisionObject3D).get_rid()]
	# The pile's surface collider is only for binders to rest on; aim at the
	# cards through it. The block that stops you leaning over a table is
	# only for the player's body.
	query.collision_mask = ~(PileWorld.SURFACE_LAYER | preload("res://scripts/store/store_builder.gd").LEAN_STOP_LAYER)
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	_aim_point = hit.position
	var collider: Object = hit.collider
	if collider is Binder:
		_aim = Aim.BINDER
		_aim_binder = collider
		_aim_pocket = _aim_binder.pocket_at(hit.position)
	elif collider is LooseCard:
		_aim = Aim.LOOSE_CARD
		_aim_loose_card = collider
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
	var text := _binder_hint(_aim_binder) if _aim == Aim.BINDER else ""
	if text != _hint:
		_hint = text
		hint_changed.emit(text)
	var id := shown_card_id()
	var set_only := id < 0 and shown_set_card_id() >= 0
	if set_only:
		id = shown_set_card_id()
	var shown: CardData = CardDatabase.get_card(id) if id >= 0 else null
	if shown != _shown_card or set_only != _shown_set_only:
		_shown_card = shown
		_shown_set_only = set_only
		shown_card_changed.emit(shown, set_only)


## The card whose details to show: the one in hand, or else, with Remember
## the Fallen, one you're looking at that you've held before, lying about
## (on the floor or a table) or misplaced in a pocket. -1 for none.
func shown_card_id() -> int:
	if held_card_id >= 0:
		return held_card_id
	if not _hands_empty():
		return -1
	var id := -1
	var lying := _aim_lying_card()
	# Enlightened Tutor II reads every card lying about at a glance.
	if lying >= 0 and Progression.rank("Enlightened Tutor") >= 2:
		return lying
	if Progression.rank("Remember the Fallen") == 0:
		return -1
	if lying >= 0:
		id = lying
	elif _aim == Aim.BINDER and _aim_binder.is_open() and not _aim_binder.contents.is_locked(_aim_pocket):
		id = _aim_binder.contents.card_at(_aim_pocket)
	return id if seen_cards.has(id) else -1


## With Enlightened Tutor, a card lying about that you look at with empty
## hands shows its set, even one you've never held. -1 for none.
func shown_set_card_id() -> int:
	if not _hands_empty() or Progression.rank("Enlightened Tutor") == 0:
		return -1
	return _aim_lying_card()


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


## A pocket shows its number, and the card's name once its own card is locked
## in. Until then (empty, or holding the wrong card) the card is a mystery.
func _pocket_hint(binder: Binder, pocket: int) -> String:
	var set_data := CardDatabase.get_set(binder.binder.set_code)
	var number := "%s #%s" % [set_data.code, set_data.number_text(binder.binder.first + pocket)]
	if not binder.contents.is_locked(pocket):
		return number + ": ???"
	return "%s\n%s" % [number, CardDatabase.get_card(binder.contents.card_at(pocket)).name]


func _toss() -> void:
	var forward := -_camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var card := TossedCard.new()
	# The tossed card gets its own material so the next pick-up can change
	# the hand without changing the card in flight.
	var material := _card_material(held_card_id)
	pile.add_child(card)
	card.exclude = [(get_parent() as CollisionObject3D).get_rid()]
	var velocity := forward * randf_range(toss_forward_speed_min, toss_forward_speed_max) \
			+ Vector3.UP * randf_range(toss_up_speed_min, toss_up_speed_max)
	# Turns per second around the card's own axes: mostly end over end
	# (left-right axis), with a little roll (long axis) and flat spin (face
	# normal) so no two tosses tumble quite the same.
	var flips := randf_range(toss_flips_per_second_min, toss_flips_per_second_max) * (1 if randf() < 0.5 else -1)
	var roll := randf_range(-toss_roll_per_second_max, toss_roll_per_second_max)
	var spin := randf_range(-toss_spin_per_second_max, toss_spin_per_second_max)
	card.launch(held_card_id, pile, material, _held_view.global_transform, velocity, Vector3(flips, roll, spin) * TAU)


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


func _set_zoom_amount(amount: float) -> void:
	_zoom_amount = amount
	_pose_held_card()
	_show_fan()


## Places the held card between its low and up-close poses, with the tilt on
## top. Tilt only shows up close, so it's scaled by how far up the card is.
func _pose_held_card() -> void:
	if _gliding() and held_card_id >= 0:
		return # Still on its way to the hand.
	var zoomed_position := Vector3(0.0, 0.0, -zoomed_distance(_camera.fov, PileWorld.CARD_SIZE.y))
	_held_view.position = HELD_POSITION.lerp(zoomed_position, _zoom_amount)
	_held_view.rotation = HELD_ROTATION.lerp(ZOOMED_ROTATION, _zoom_amount) \
			+ Vector3(_tilt.x, _tilt.y, 0.0) * _zoom_amount


## Puts card `id` on top of the hand, the old top card going just behind it
## (see _hold for `from`, `seconds` and `lift`).
func _take_in_hand(id: int, from = null, seconds := -1.0, lift := 0.0) -> void:
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
		_fan_views[i].visible = i < behind.size() and _zoom_amount < 0.05 and _incoming == 0


## Puts card `id` on top of the hand in place of the top card (-1 for none;
## the cards behind stay). Given `from`, a global card
## pose, the card glides up to the hand from there, taking `seconds` (a
## normal pick-up's if negative; before Snap) and arcing `lift` metres up.
func _hold(id: int, from = null, seconds := -1.0, lift := 0.0) -> void:
	if _zoom_tween:
		_zoom_tween.kill()
	_zoomed = false
	_zoom_amount = 0.0
	_tilt = Vector2.ZERO
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
	held_changed.emit(CardDatabase.get_card(id), null)
