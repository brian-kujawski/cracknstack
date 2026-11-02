class_name ShopSave
extends RefCounted
## What goes into a save from the shop, and putting it back (plan:
## save-system-plan.md §4). Everything needed to put the shop back exactly
## as it was, and nothing that can be rebuilt from game data.
##
## What's saved is the copies (Collection: every physical card you own),
## in copy id order, each as its set code and collector number and its
## flags, never by card id: a card id is only a card's place in cards.json,
## which shifts with every import (card-copies-plan.md). Every per-copy
## value (where it lies, which pocket holds it) is by its place in that
## list. Loading makes the copies again, in the same order, from whatever
## card each is now, so a save survives data changes (§7.2): copies of
## cards that are gone are dropped, and binders for new sets go on the
## shelf.
##
## Things in motion are saved where they'd end up: a card on its way into a
## pocket is saved in it, and anything else in the air (tossed, flipped,
## hovering, being put down) is saved as falling, and a rare card on its
## way into its shadow box is saved in it, to land when the shop
## loads. A tossed binder is saved lying where it would come down. Any
## card the save doesn't place anywhere falls near the player.

## The copies as a save lists them: card ids and flags by copy id (as
## Collection.card_ids() and all_flags()) become a table of set codes and,
## per copy, its set's place in that table, its collector number and flags.
static func copy_table(card_ids: PackedInt32Array, flags: PackedByteArray) -> Dictionary:
	var codes := PackedStringArray()
	var index_of := {}
	var sets := PackedInt32Array()
	var numbers := PackedInt32Array()
	sets.resize(card_ids.size())
	numbers.resize(card_ids.size())
	for i in card_ids.size():
		var card := CardDatabase.get_card(card_ids[i])
		if not index_of.has(card.set_code):
			index_of[card.set_code] = codes.size()
			codes.append(card.set_code)
		sets[i] = index_of[card.set_code]
		numbers[i] = card.collector_number
	return {"sets": codes, "set": sets, "number": numbers, "flags": flags}


## Makes the copies a save lists (copy_table) again, in order, in an emptied
## Collection. Returns, for each saved copy, its copy id now, or -1 if its
## card is gone from the data.
static func make_copies(table: Dictionary) -> PackedInt32Array:
	Collection.reset()
	var codes: PackedStringArray = table.get("sets", PackedStringArray())
	var sets: PackedInt32Array = table.get("set", PackedInt32Array())
	var numbers: PackedInt32Array = table.get("number", PackedInt32Array())
	var flags: PackedByteArray = table.get("flags", PackedByteArray())
	var ids := PackedInt32Array()
	ids.resize(mini(sets.size(), numbers.size()))
	for i in ids.size():
		var card := CardDatabase.find_card(codes[sets[i]], numbers[i]) if sets[i] >= 0 and sets[i] < codes.size() else null
		ids[i] = Collection.add(card.id, flags[i] if i < flags.size() else 0) if card != null else -1
	return ids


## Everything in the shop worth saving: finish(snapshot()). `falling` is
## cards still waiting to land from the last load ([id, global point, yaw,
## face up]).
static func capture(pile: PileWorld, hands: Hands, player: Node, day: DayCycle, falling: Array = []) -> Dictionary:
	return finish(snapshot(pile, hands, player, day, falling))


## The shop as it is now, by copy id: quick, copies only (packed arrays copy
## on write), so it can be taken on the main thread between frames.
## finish() turns it into a save, and can run on a worker thread.
static func snapshot(pile: PileWorld, hands: Hands, player: Node, day: DayCycle, falling: Array = []) -> Dictionary:
	var progression := Progression.save_state()
	var binders := {}
	for binder in pile.binders:
		var entry := {"state": binder.state, "transform": binder.global_transform, "spread": binder.spread,
			"pockets": binder.contents.pocket_cards(), "locked": binder.contents.pocket_locks()}
		if binder.state == Binder.State.TOSSED:
			# In the air: saved lying where it would come down.
			entry.state = Binder.State.CLOSED
			entry.transform = binder.toss_rest_pose()
		if binder.state == Binder.State.SHELVED and binder.shelf_unit != null:
			entry["shelf"] = [String(binder.shelf_unit.name), binder.shelf_unit.spaces[binder.shelf_space].set_code]
		binders[binder.binder.set_code] = entry

	var displayed := PackedInt32Array()
	for cabinet in hands.cabinets:
		for id in cabinet.displayed:
			if id >= 0:
				displayed.append(id)
	var in_air := falling.duplicate(true)
	for child in pile.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is TossedCard:
			var face_up: bool = child.global_transform.basis.z.y > 0.0 if child.land_face_up < 0 else child.land_face_up == 1
			in_air.append([child.card_id, child.global_position,
				atan2(-child.global_transform.basis.y.x, -child.global_transform.basis.y.z), face_up])
		elif child is HoveringCard:
			in_air.append([child.card_id, child.global_position, child.rotation.y, true])
		elif child.has_meta("card_id") and child.has_meta("cabinet"):
			displayed.append(child.get_meta("card_id"))
			progression.mana += Progression.CARD_LOCKED
		elif child.has_meta("card_id") and child.has_meta("pocket"):
			# On its way into a pocket: saved in it, if it's still free.
			var id: int = child.get_meta("card_id")
			var target: Array = child.get_meta("pocket")
			var binder: Binder = target[0]
			var pocket: int = target[1]
			var entry: Dictionary = binders[binder.binder.set_code]
			var pockets: PackedInt32Array = entry.pockets
			if pockets[pocket] < 0:
				pockets[pocket] = id
				entry.pockets = pockets
				if binder.contents.belongs(id, pocket):
					var locked: PackedByteArray = entry.locked
					locked[pocket] = 1
					entry.locked = locked
					progression.mana += Progression.CARD_LOCKED
			else:
				in_air.append([id, child.global_position, binder.rotation.y, true])
		elif child.has_meta("card_id") and child.has_meta("falls_to"):
			var to: Array = child.get_meta("falls_to")
			in_air.append([child.get_meta("card_id"), to[0], to[1], true])

	var hand := PackedInt32Array([hands.held_card_id] if hands.held_card_id >= 0 else [])
	hand.append_array(PackedInt32Array(hands.behind))
	return {
		"copies": [Collection.card_ids(), Collection.all_flags()],
		"cards": pile.snapshot_cards(),
		"falling": in_air,
		"binders": binders,
		"cabinets": displayed,
		"hand": hand,
		"seen": PackedInt32Array(hands.seen_cards.keys()),
		"player": player.save_state(),
		"hour": day.hour if day != null else DayCycle.START_HOUR,
		"progression": progression,
	}


## Turns a snapshot() into a save: the copy table goes in, and every
## per-copy value is listed by copy id (a copy's place in the table).
static func finish(taken: Dictionary) -> Dictionary:
	var card_ids: PackedInt32Array = taken.copies[0]
	var count := card_ids.size()
	var to_index := func(id: int) -> int: return id if id >= 0 and id < count else -1

	var cards: Dictionary = taken.cards
	var states: PackedByteArray = cards.states
	var all_positions: PackedVector3Array = cards.positions
	var all_rotations: PackedFloat32Array = cards.rotations
	var all_face_up: PackedByteArray = cards.face_up
	var loose: Dictionary = cards.loose
	var where := PackedByteArray()
	var positions := PackedVector3Array()
	var rotations := PackedFloat32Array()
	var face_up := PackedByteArray()
	where.resize(count)
	positions.resize(count)
	rotations.resize(count)
	face_up.resize(count)
	for i in count:
		var id := i
		# A copy the pile hasn't taken in yet is held (in hand, in a pack).
		match states[id] if id < states.size() else PileWorld.State.HELD:
			PileWorld.State.ON_FLOOR:
				positions[i] = all_positions[id]
				rotations[i] = all_rotations[id]
				face_up[i] = all_face_up[id]
			PileWorld.State.ON_TABLE:
				var lying: Array = loose[id]
				where[i] = 1
				positions[i] = lying[0]
				rotations[i] = lying[1]
				face_up[i] = 1 if lying[2] else 0
			_:
				where[i] = 2

	var binders := {}
	for code in taken.binders:
		var entry: Dictionary = taken.binders[code].duplicate()
		var pockets := PackedInt32Array()
		for id in entry.pockets:
			pockets.append(to_index.call(id))
		entry.pockets = pockets
		binders[code] = entry
	var falling := []
	for entry in taken.falling:
		falling.append([to_index.call(entry[0]), entry[1], entry[2], entry[3]])
	var displayed := PackedInt32Array()
	for id in taken.get("cabinets", PackedInt32Array()):
		displayed.append(to_index.call(id))
	var hand := PackedInt32Array()
	for id in taken.hand:
		hand.append(to_index.call(id))
	var seen := PackedInt32Array()
	for id in taken.seen:
		seen.append(to_index.call(id))
	return {
		"copies": copy_table(card_ids, taken.copies[1]),
		"cards": {"where": where, "positions": positions, "rotations": rotations, "face_up": face_up},
		"falling": falling,
		"binders": binders,
		"cabinets": displayed,
		"hand": hand,
		"seen": seen,
		"player": taken.player,
		"hour": taken.hour,
		"progression": taken.progression,
	}


## Puts the shop back from a save made by capture(), in a freshly loaded
## shop whose store is built and whose pile is empty. Returns the cards
## still to land once physics is running ([id, global point, yaw, face up]),
## for land_falling().
static func restore(saved: Dictionary, pile: PileWorld, hands: Hands, player: Node, shelves: Array,
		floor_bounds: Rect2, floor_obstacles: Array[Rect2], random_seed: int) -> Array:
	var ids := make_copies(saved.get("copies", {}))
	Progression.restore_state(saved.get("progression", {}))
	pile.restore_cards(floor_bounds, floor_obstacles, saved.cards, ids, random_seed)
	var placed := PackedByteArray()
	placed.resize(Collection.count())
	for id in Collection.count():
		placed[id] = 1 if pile.is_lying(id) else 0
	var strays: Array[int] = []

	# Binders: each back where it was; ones for sets the save doesn't know,
	# or whose place is gone, go in their shelf space, or else on the floor.
	pile.make_binders()
	var units := {}
	for unit: ShelfUnit in shelves:
		units[String(unit.name)] = unit
	var saved_binders: Dictionary = saved.get("binders", {})
	var unplaced: Array[Binder] = []
	for binder in pile.binders:
		var entry: Dictionary = saved_binders.get(binder.binder.set_code, {})
		if entry.is_empty():
			unplaced.append(binder)
			continue
		var cards := PackedInt32Array()
		for index in entry.pockets:
			var id := ids[index] if index >= 0 and index < ids.size() else -1
			if id >= 0 and placed[id] == 1:
				id = -1
			if id >= 0:
				placed[id] = 1
			cards.append(id)
		strays.append_array(binder.contents.restore(cards, entry.locked))
		if not _place_binder(binder, entry, pile, hands, units):
			unplaced.append(binder)
	unplaced = ShelfUnit.shelve_all(unplaced, shelves)
	if not unplaced.is_empty():
		pile.scatter_binders(unplaced, random_seed)
	# A binder a pocket flight finished pays its bonus now (paid ones aren't
	# paid twice).
	for binder in pile.binders:
		if binder.contents.is_complete():
			Progression.earn_once("complete:" + binder.key(), Progression.binder_complete_bonus(binder.contents.capacity()))

	# Rare cards back in their shadow boxes (nothing brings rare cards yet,
	# so a save has none for now).
	for cabinet in hands.cabinets:
		cabinet.clear_display()
	for index in saved.get("cabinets", PackedInt32Array()):
		var id := ids[index] if index >= 0 and index < ids.size() else -1
		if id < 0 or placed[id] == 1:
			continue
		for cabinet in hands.cabinets:
			if cabinet.display(id, false):
				placed[id] = 1
				break

	var hand: Array[int] = []
	for index in saved.get("hand", PackedInt32Array()):
		var id := ids[index] if index >= 0 and index < ids.size() else -1
		if id >= 0 and placed[id] == 0 and hand.size() < hands.hand_size():
			placed[id] = 1
			hand.append(id)
	if hands.carried_binder == null:
		hands.restore_hand(hand)
	else:
		strays.append_array(hand)
	for index in saved.get("seen", PackedInt32Array()):
		var id := ids[index] if index >= 0 and index < ids.size() else -1
		if id >= 0:
			hands.seen_cards[id] = true

	player.restore_state(saved.get("player", {}))
	var falling := []
	for entry in saved.get("falling", []):
		var id := ids[entry[0]] if entry[0] >= 0 and entry[0] < ids.size() else -1
		if id >= 0 and placed[id] == 0:
			placed[id] = 1
			falling.append([id, entry[1], entry[2], entry[3]])
	# Anything still unplaced (a card a binder no longer has room for, or
	# that the save somehow lost) falls near the player.
	for id in Collection.count():
		if placed[id] == 0:
			strays.append(id)
	var near: Vector3 = player.global_position - player.global_basis.z * 0.6
	for id in strays:
		falling.append([id, near + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3)), randf() * TAU, true])
	return falling


## Sets the clock to the saved hour, unless it's stopped (then the setting
## decides).
static func restore_day(saved: Dictionary, day: DayCycle) -> void:
	if Settings.day_seconds() > 0.0 and saved.has("hour"):
		day.set_hour(saved.hour)


## Lands the cards restore() left falling, once physics can see the store.
static func land_falling(falling: Array, pile: PileWorld) -> void:
	for entry in falling:
		pile.land(entry[0], entry[1], entry[2], entry[3])


## Puts one binder back as saved. Returns false if it couldn't be (its shelf
## space is gone, or it would sit in a wall or a table leg now), so it gets
## dropped on the pile instead.
static func _place_binder(binder: Binder, entry: Dictionary, pile: PileWorld, hands: Hands, units: Dictionary) -> bool:
	match int(entry.state):
		Binder.State.SHELVED:
			var shelf: Array = entry.get("shelf", [])
			var unit: ShelfUnit = units.get(shelf[0]) if shelf.size() == 2 else null
			var space := unit.space_for(shelf[1]) if unit != null else -1
			if space < 0 or unit.shelved[space] != null:
				return false
			unit.shelve(space, binder, true)
			return true
		Binder.State.CARRIED:
			if hands.carried_binder != null:
				return false
			hands.restore_carried(binder)
			return true
	var at: Transform3D = entry.transform
	var footprint := Binder.OPEN_HALF_FOOTPRINT if entry.state == Binder.State.OPEN else Vector2(Binder.COVER.x, Binder.COVER.y) / 2
	var p := Vector2(at.origin.x, at.origin.z)
	var on_floor := at.origin.y < 0.3
	if on_floor and not PileGenerator.footprint_clear(p, footprint, at.basis.get_euler().y, pile.bounds, pile.obstacles):
		return false
	binder.place(pile, at, entry.spread if entry.state == Binder.State.OPEN else -1)
	return true
