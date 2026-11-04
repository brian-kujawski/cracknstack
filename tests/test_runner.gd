extends Node
## Headless checks for the data layer, the pile, binders and shelving. Run from the project root:
##   godot --headless res://tests/test_runner.tscn
## Add `-- --smoke` for just the SMOKE groups.
## Exits with code 1 if any check fails.

const SETTINGS_TEST_PATH := "user://test_settings.cfg"
const SAVES_TEST_DIR := "user://test_saves"
const RADIO_TEST_PATH := "user://test_radio.cfg"
## The groups run with `-- --smoke`, the quick batch CI runs on pull requests:
## the data layer, saves, one shop boot and the asset checks. Everything else
## waits for main, a PR labelled full-tests, or a run without the flag.
const SMOKE := [&"_test_database_loaded", &"_test_collector_numbers_are_contiguous", &"_test_shelf_order",
	&"_test_binders_per_set", &"_test_binder_layout", &"_test_card_sort", &"_test_binder_contents",
	&"_test_card_corners", &"_test_real_data_format", &"_test_credits", &"_test_controls", &"_test_settings",
	&"_test_achievements", &"_test_progression", &"_test_save_files", &"_test_shop_save", &"_test_rare_cards", &"_test_booster_packs", &"_test_card_copies", &"_test_set_locks", &"_test_laptop", &"_test_selling", &"_test_chapters", &"_test_card_values", &"_test_folder_names"]

var _failures := 0
var _checks := 0
var _smoke := "--smoke" in OS.get_cmdline_user_args()


func _ready() -> void:
	# The checks below are written against the placeholder collection, even
	# when real data has been imported locally, and against default settings,
	# saved somewhere other than yours.
	CardDatabase.load_file(CardDatabase.PLACEHOLDER_PATH)
	Settings.save_path = SETTINGS_TEST_PATH
	Settings.reset_all()
	Saves.save_dir = SAVES_TEST_DIR
	Radio.load_from(RADIO_TEST_PATH)
	# Most checks were written before sets locked (_test_set_locks turns it
	# back on).
	Progression.locks_sets = false
	_clear_test_saves()
	await _run(_test_database_loaded)
	await _run(_test_card_copies)
	await _run(_test_set_locks)
	await _run(_test_chapters)
	await _run(_test_card_values)
	await _run(_test_folder_names)
	await _run(_test_set_unlock_delivery)
	await _run(_test_collector_numbers_are_contiguous)
	await _run(_test_shelf_order)
	await _run(_test_binders_per_set)
	await _run(_test_binder_layout)
	await _run(_test_card_sort)
	await _run(_test_shelf_layout)
	await _run(_test_pile)
	await _run(_test_pile_clearing)
	await _run(_test_pile_aim)
	await _run(_test_pile_stacking)
	await _run(_test_pile_grid)
	await _run(_test_binder_spreads)
	await _run(_test_binder_contents)
	await _run(_test_binder_pockets)
	await _run(_test_binder_lettering)
	await _run(_test_leather_colour)
	await _run(_test_shelving)
	await _run(_test_loose_card)
	await _run(_test_card_corners)
	await _run(_test_real_data_format)
	await _run(_test_near_faces)
	await _run(_test_credits)
	await _run(_test_inspect_tilt)
	await _run(_test_glide)
	await _run(_test_controls)
	await _run(_test_settings)
	await _run(_test_settings_screen)
	await _run(_test_onscreen_text)
	await _run(_test_pause)
	await _run(_test_title_screen)
	await _run(_test_achievements)
	await _run(_test_credits_roll)
	await _run(_test_progression)
	await _run(_test_upgrade_menu)
	await _run(_test_radio)
	await _run(_test_sorcery_recharge)
	await _run(_test_step_one_upgrades)
	await _run(_test_demonic_tutor)
	await _run(_test_step_two_upgrades)
	await _run(_test_step_three_upgrades)
	await _run(_test_step_four_upgrades)
	await _run(_test_steps_five_to_seven)
	await _run(_test_day_cycle)
	await _run(_test_display_cabinets)
	await _run(_test_reading_corner)
	await _run(_test_crouch)
	await _run(_test_lean_over_table)
	await _run(_test_table_cards)
	await _run(_test_binder_toss)
	await _run(_test_save_files)
	await _run(_test_shop_save)
	await _run(_test_turn_over)
	await _run(_test_rare_cards)
	await _run(_test_wall_art)
	await _run(_test_shop_clock)
	await _run(_test_booster_packs)
	await _run(_test_laptop)
	await _run(_test_selling)
	CardDatabase.load_file(CardDatabase.PLACEHOLDER_PATH)
	_clear_test_saves()
	DirAccess.remove_absolute(SETTINGS_TEST_PATH)
	DirAccess.remove_absolute(RADIO_TEST_PATH)
	print("%d checks, %d failed%s" % [_checks, _failures, " (smoke batch)" if _smoke else ""])
	get_tree().quit(1 if _failures > 0 else 0)


func _run(group: Callable) -> void:
	if _smoke and group.get_method() not in SMOKE:
		return
	var started := Time.get_ticks_msec()
	var checks := _checks
	_one_of_each()
	await group.call()
	print("%s: %d checks in %d ms" % [group.get_method(), _checks - checks, Time.get_ticks_msec() - started])


## Most checks are written against one copy of every card, numbered like
## the cards (copy id == card id), as the game used to start: each group
## starts with that Collection.
func _one_of_each() -> void:
	Collection.reset()
	Collection.add_all(PackedInt32Array(range(CardDatabase.card_count())))


## A new shop as the game used to start, for checks written against it:
## one copy of every card scattered on the floor (copy id == card id) and
## every binder dropped on top, not on the shelf.
func _old_start(main: Node3D) -> void:
	var pile: PileWorld = main.get_node("Pile")
	for unit: ShelfUnit in main._shelves():
		for space in unit.spaces.size():
			if unit.shelved[space] != null:
				unit.unshelve(space)
	for binder in pile.binders:
		binder.get_parent().remove_child(binder)
		binder.shelf_unit = null
		binder.collision_mask = Binder.PHYSICS_MASK
	_one_of_each()
	pile.scatter(PackedInt32Array(range(Collection.count())), main.PILE_SEED)
	pile.scatter_binders(pile.binders, main.PILE_SEED)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func _test_database_loaded() -> void:
	_check(CardDatabase.set_count() == 150, "expected 150 placeholder sets, got %d" % CardDatabase.set_count())
	_check(CardDatabase.card_count() > 25000 and CardDatabase.card_count() < 35000,
		"expected ~30k placeholder cards, got %d" % CardDatabase.card_count())


## Copies (Collection): any number of physical cards of one card, each
## its own id, filed, found and saved as itself.
func _test_card_copies() -> void:
	Collection.reset()
	_check(Collection.count() == 0, "the collection starts empty")
	var card := CardDatabase.all_binders()[0]
	var first: CardData = CardDatabase.cards_in_set(card.set_code)[0]
	var a := Collection.add(first.id)
	var b := Collection.add(first.id, Collection.FOIL)
	var other := Collection.add(first.id + 1)
	_check(a == 0 and b == 1 and other == 2 and Collection.count() == 3, "copies are numbered in order")
	_check(Collection.card(a) == first and Collection.card(b) == first and Collection.card(other) != first, "each knows its card")
	_check(not Collection.is_foil(a) and Collection.is_foil(b), "and its own flags")
	_check(Collection.copies_of(first.id) == PackedInt32Array([a, b]) and Collection.copies_of(first.id + 2).is_empty(),
		"a card's copies, or none")
	_check(CardDatabase.find_card(first.set_code, first.collector_number) == first and CardDatabase.find_card(first.set_code, 9999) == null,
		"cards are found by set and number")

	# Either copy belongs in the card's pocket; once one's in, the other has
	# nowhere to go there.
	var contents := BinderContents.new(card)
	_check(contents.belongs(a, 0) and contents.belongs(b, 0), "every copy of a card belongs in its pocket")
	_check(contents.insert(0, b) == BinderContents.Result.LOCKED, "a copy locks in")
	_check(contents.insert(0, a) == BinderContents.Result.OCCUPIED, "the second copy finds its pocket taken")
	_check(contents.insert(5, a) == BinderContents.Result.WRONG_POCKET and contents.card_at(5) == -1,
		"and no other pocket takes it")

	# Found lying about: the nearest copy.
	var pile := PileWorld.new()
	add_child(pile)
	pile.setup(Rect2(0, 0, 4, 4), [] as Array[Rect2])
	pile.drop(a, Vector3(0.5, 0, 0.5), 0.0)
	pile.drop(b, Vector3(3.5, 0, 3.5), 0.0)
	_check(pile.lying_copy(first.id, Vector3(3, 0, 3)) == b and pile.lying_copy(first.id, Vector3(1, 0, 1)) == a, "the nearest copy lying about")
	pile.pick_up(a)
	_check(pile.lying_copy(first.id, Vector3(1, 0, 1)) == b and pile.copy_to_take(first.id, Vector3.ZERO) == b, "or the only one")
	_check(pile.lying_copy(first.id + 2, Vector3.ZERO) == -1, "none for a card with no copies")
	pile.free()

	# Saved as set code, number and flags; made again in the same order.
	var table := ShopSave.copy_table(Collection.card_ids(), Collection.all_flags())
	_check(table.sets == PackedStringArray([first.set_code]) and table.number == PackedInt32Array([1, 1, 2]),
		"a save lists copies by set code and number, never by card id")
	Collection.reset()
	var ids := ShopSave.make_copies(table)
	_check(ids == PackedInt32Array([0, 1, 2]) and Collection.card(1) == first and Collection.is_foil(1),
		"loading makes the same copies again")
	table.sets = PackedStringArray(["ZZZ"])
	_check(ShopSave.make_copies(table) == PackedInt32Array([-1, -1, -1]) and Collection.count() == 0,
		"copies of cards gone from the data are dropped")


## Sets lock: a locked set's binder waits out of sight on the shelf, out of
## reach, until the set is unlocked (for now, by the Card Shop's Unlock).
func _test_set_locks() -> void:
	Progression.reset()
	Progression.locks_sets = true
	var code: String = CardDatabase.sets_in_shelf_order()[0].code
	_check(not Progression.is_set_unlocked(code), "a new game's sets are locked")
	_check(Progression.unlock_set(code) and Progression.is_set_unlocked(code) and not Progression.unlock_set(code), "a set unlocks once")
	var kept := Progression.save_state()
	Progression.reset()
	_check(not Progression.is_set_unlocked(code), "a new game locks it again")
	Progression.restore_state(kept)
	_check(Progression.is_set_unlocked(code), "a save keeps what's unlocked")
	Progression.reset()
	Progression.locks_sets = false


## Selling cards into shipping boxes, the money, and the end of the day.
func _test_selling() -> void:
	_check(Progression.money_text(0) == "$0.00" and Progression.money_text(5) == "$0.05"
		and Progression.money_text(123456789) == "$1,234,567.89" and Progression.money_text(-250) == "-$2.50",
		"money reads like money")
	Progression.reset()
	_check(Progression.money == 0 and not Progression.spend_money(1), "a new game has no money, and can't spend any")
	Progression.earn_money(500)
	_check(Progression.spend_money(200) and Progression.money == 300 and not Progression.spend_money(301),
		"money is earned and spent, never below zero")
	_check(Progression.save_state().money == 300, "and saved")
	var code: String = LaptopScreen.shop_sets()[0].code
	var pack := Prices.pack_cents(code)
	_check(pack > 0 and pack % Prices.PACK_ROUNDING == 0 and Prices.product_cents("booster_box", code) == pack * PackContents.BOX_PACKS,
		"a pack costs a round price, a box %d of them" % PackContents.BOX_PACKS)
	_check(absf(pack / 100.0 - Prices.pack_worth(code) / Prices.MARGIN) <= Prices.PACK_ROUNDING / 200.0 + 0.001,
		"a pack costs its average worth over %.1f" % Prices.MARGIN)
	_check(Prices.product_cents("bulk_box", code) % Prices.BULK_ROUNDING == 0 and Prices.product_cents("bulk_box", code) > pack,
		"a bulk box costs whole dollars")
	var cheap := CardData.new()
	cheap.value = 0.0
	_check(Prices.sale_cents(cheap) == 1, "nothing sells for less than a cent")

	Progression.reset()
	Collection.reset()
	var main: Node3D = load(SceneFlow.SHOP_SCENE).instantiate()
	add_child(main)
	await get_tree().physics_frame
	var hands: Hands = main.get_node("Player/Hands")
	var pile: PileWorld = main.get_node("Pile")
	var station: ShippingStation = main._store.shipping_station
	_check(station != null and station.global_position.z > 7.0 and station.on_mat(station.global_position),
		"the shipping corner is just inside the door")

	# A new box from the crate, put down on the floor.
	var box := hands.take_new_shipping_box()
	hands._glide.custom_step(10.0)
	_check(hands.held_box == box and box.cards == 0 and not box.sealed and box.details().contains("0/%d" % ShippingBox.CAPACITY),
		"the crate hands over an empty shipping box")
	hands.press_rip()
	_check(hands.held_box == box and is_instance_valid(box) and not box.is_queued_for_deletion(), "Space doesn't open it like product")
	hands._aim = Hands.Aim.FLOOR
	hands._aim_point = Vector3(4.0, 0.0, 4.0)
	hands.put_down_box()
	hands._glide.custom_step(10.0)
	_check(hands.held_box == null and box.get_parent() == pile, "it goes down like any box")

	# A card the collection doesn't have yet asks first.
	var card := CardDatabase.get_card(_first_binder_cards()[0])
	var first := Collection.add(card.id)
	hands.restore_hand([first])
	var asked := []
	hands.sale_confirm_requested.connect(func(b: ShippingBox) -> void: asked.append(b))
	_check(hands.collection_needs(first), "a card with an empty pocket is still needed")
	_check(not hands.sell_held_card(box) and asked == [box] and hands.held_card_id == first and Progression.money == 0,
		"selling it asks first, and nothing's sold yet")
	var confirm: SellConfirm = main.get_node_or_null("SellConfirm")
	_check(confirm != null and confirm.text == SellConfirm.QUESTION, "the shop asks; the first time, it just asks")
	var again := SellConfirm.new(func() -> void: pass)
	_check(again.text == SellConfirm.QUESTION + SellConfirm.TURN_OFF, "after that, it says where to turn it off")
	again.free()
	_check(get_tree().paused and confirm.sell_button != null and confirm.keep_button != null, "the question stops the game")
	confirm.answer(true)
	hands._glide.custom_step(10.0)
	var cents := Prices.sale_cents(card)
	_check(not get_tree().paused and Collection.is_sold(first) and hands.held_card_id < 0 and Progression.money == cents,
		"Sell sells it: the card's gone and %s is paid at once" % Progression.money_text(cents))
	_check(box.cards == 1 and box.has_room(), "it drops into the box")

	# One the collection already has sells with no question.
	var filed := Collection.add(card.id)
	var binder := pile.binder_for(filed)
	binder.contents.insert(card.collector_number - binder.binder.first, filed)
	var spare := Collection.add(card.id)
	hands.restore_hand([spare])
	asked.clear()
	_check(not hands.collection_needs(spare) and hands.sell_held_card(box) and asked.is_empty(), "a duplicate sells straight away")
	hands._glide.custom_step(10.0)
	_check(Progression.money == 2 * cents and box.cards == 2, "and pays the same")
	# With the question turned off, a needed card sells too.
	Settings.change("confirm_new_sales", false)
	var other := CardDatabase.get_card(_first_binder_cards()[1])
	var needed := Collection.add(other.id)
	hands.restore_hand([needed])
	_check(hands.sell_held_card(box) and asked.is_empty(), "with the confirmation off, it doesn't ask")
	hands._glide.custom_step(10.0)
	Settings.change("confirm_new_sales", true)

	# Full, sealed.
	box.cards = ShippingBox.CAPACITY
	var more := Collection.add(card.id)
	hands.restore_hand([more])
	_check(not box.has_room() and not hands.sell_held_card(box) and hands.held_card_id == more, "a full box takes no more")
	hands.restore_hand([])
	var empty := hands.take_new_shipping_box()
	hands._glide.custom_step(10.0)
	_check(not empty.can_seal() and not empty.seal(), "an empty box can't be sealed")
	hands._aim = Hands.Aim.FLOOR
	hands._aim_point = station.global_position
	hands.put_down_box()
	hands._glide.custom_step(10.0)
	_check(box.seal() and box.sealed and not box.has_room() and box.details().begins_with("Shipping Box\nSealed"),
		"a box with cards in seals shut")

	# Saved: boxes keep their cards and seals, and sold cards are gone.
	var saved: Dictionary = main.capture_save()
	var entries: Array = saved.products.filter(func(e: Array) -> bool: return e[0] == "shipping")
	_check(entries.size() == 2 and entries.any(func(e: Array) -> bool: return e[1] == ShippingBox.CAPACITY and e[3]),
		"both shipping boxes are saved, with their cards and seal")
	var restored := PileWorld.new()
	add_child(restored)
	ShopSave.restore_products(saved.products, restored)
	var back := restored.get_children().filter(func(n: Node) -> bool: return n is ShippingBox)
	_check(back.size() == 2 and back.any(func(b: ShippingBox) -> bool: return b.sealed and b.cards == ShippingBox.CAPACITY),
		"and come back the same")
	restored.free()
	var ids := ShopSave.make_copies(saved.copies)
	_check(ids[first] == -1 and ids[spare] == -1 and ids[filed] >= 0 and ids[more] >= 0, "sold copies aren't made again")
	main.free()

	# The end of the day: sealed boxes on the mat go; the rest stay.
	Progression.reset()
	Collection.reset()
	main = load(SceneFlow.SHOP_SCENE).instantiate()
	add_child(main)
	await get_tree().physics_frame
	pile = main.get_node("Pile")
	station = main._store.shipping_station
	var make := func(cards: int, sealed: bool, at: Vector3) -> ShippingBox:
		var b := ShippingBox.new()
		b.build(cards, sealed)
		pile.add_child(b)
		b.global_position = at
		return b
	var on_mat: ShippingBox = make.call(10, true, station.global_position)
	var open_on_mat: ShippingBox = make.call(10, false, station.global_position + Vector3(0.3, 0, 0))
	var sealed_away: ShippingBox = make.call(10, true, Vector3(4.0, 0.0, 4.0))
	var day: int = main.day_number
	_check(main.start_new_day() == 1, "one box ships")
	_check(on_mat.is_queued_for_deletion() and not open_on_mat.is_queued_for_deletion() and not sealed_away.is_queued_for_deletion(),
		"only a sealed box on the OUTGOING mat is collected")
	_check(main.day_number == day + 1, "and it's the next day")
	var hint := [""]
	var door_hands: Hands = main.get_node("Player/Hands")
	door_hands.hint_changed.connect(func(text: String) -> void: hint[0] = text)
	door_hands._aim = Hands.Aim.DOOR
	door_hands._update_hint()
	_check(hint[0] == "E: End Day", "the door's hint is E: End Day, got " + hint[0])
	main.free()
	Progression.reset()


## A new game's shelf is bare; unlocking a set in the Card Shop delivers its
## binder and starter packs inside the door and puts up its plate.
func _test_chapters() -> void:
	var parsed := Chapters.parse("# a comment\n\nChapter 1: The start\nfra  # Reality Fracture\n\nChapter 2\nAAA\nbbb\nFRA\n")
	_check(parsed.size() == 2 and parsed[0].name == "Chapter 1: The start" and parsed[0].sets == PackedStringArray(["FRA"]),
		"a chapter is its Chapter line and the codes under it, upper-cased, comments dropped")
	_check(parsed[1].sets == PackedStringArray(["AAA", "BBB"]), "a set listed twice keeps its first place")
	Chapters.use_text("Chapter 1\nFRA\nChapter 2\nAAA\nBBB")
	_check(Chapters.chapter_of("FRA") == 1 and Chapters.chapter_of("bbb") == 2 and Chapters.chapter_of("ZZZ") == 0,
		"chapter_of counts from 1, 0 when a set's in none")
	_check(Chapters.opens_chapter("FRA") and Chapters.opens_chapter("AAA") and not Chapters.opens_chapter("BBB")
		and not Chapters.opens_chapter("ZZZ"), "only the first set of each chapter opens it")
	Chapters.reload()
	var chapters := Chapters.all()
	_check(not chapters.is_empty() and chapters[0].sets.size() >= 1 and chapters[0].sets[0] == "FRA",
		"data/chapters.txt starts Chapter 1 with Reality Fracture")


func _test_set_unlock_delivery() -> void:
	Progression.reset()
	Progression.locks_sets = true
	Collection.reset()
	var main: Node3D = load(SceneFlow.SHOP_SCENE).instantiate()
	add_child(main)
	await get_tree().physics_frame
	var pile: PileWorld = main.get_node("Pile")
	var hands: Hands = main.get_node("Player/Hands")
	var units: Array = main._shelves()
	var plates_up := func(shelves: Array) -> int:
		var count := 0
		for unit: ShelfUnit in shelves:
			for space in unit.spaces.size():
				if unit.nameplates.is_shown(space):
					count += 1
		return count
	_check(plates_up.call(units) == 0, "a new game's shelf has no plates")
	_check(pile.binders.all(func(b: Binder) -> bool: return b.state == Binder.State.SHELVED and not b.visible),
		"and every binder waits out of sight in its space")
	_check(PackContents.pick_set(RandomNumberGenerator.new()) == "", "nothing's unlocked, so there's nothing to make product of")

	var screen: LaptopScreen = main.laptop_screen
	var code: String = LaptopScreen.shop_sets()[0].code
	screen.open()
	var shop := screen.open_app("shop")
	_check(shop.find_child("Unlock", true, false) != null and shop.find_child("Order_pack", true, false) == null,
		"a locked set shows Unlock, not Order")
	var before := pile.get_child_count()
	screen.order_product("pack", code)
	_check(pile.get_child_count() == before, "a locked set can't be ordered")

	screen.unlock_set(code)
	_check(Progression.is_set_unlocked(code), "Unlock unlocks the set")
	var binder: Binder = pile.binders.filter(func(b: Binder) -> bool: return b.binder.set_code == code).front()
	_check(binder.visible and binder.state == Binder.State.CLOSED and binder.get_parent() == pile
		and binder.global_position.z > 6.0 and binder.global_position.z < 8.0, "its binder is delivered inside the door")
	var packs := pile.get_children().filter(func(n: Node) -> bool: return n is BoosterPack and n.set_code == code)
	_check(packs.size() == LaptopScreen.STARTER_PACKS, "with %d starter packs, got %d" % [LaptopScreen.STARTER_PACKS, packs.size()])
	var unit: ShelfUnit = units.filter(func(u: ShelfUnit) -> bool: return u.space_for(code) >= 0).front()
	var space := unit.space_for(code)
	_check(unit.nameplates.is_shown(space) and unit.shelved[space] == null and plates_up.call(units) == 1,
		"its plate goes up over its empty space, and only its")
	_check(shop.find_child("Order_pack", true, false) != null and screen.shop_status.text.begins_with("Unlocked: "),
		"the shop now sells it")
	screen.unlock_set(code)
	_check(pile.get_children().filter(func(n: Node) -> bool: return n is BoosterPack and n.set_code == code).size() == packs.size(),
		"unlocking again delivers nothing more")

	screen.close()

	# Ripping a pack of another (locked) set doesn't unlock it.
	var other: String = LaptopScreen.shop_sets()[1].code
	var pack := BoosterPack.new()
	pack.setup(other)
	pile.add_child(pack)
	hands.held_pack = pack
	hands.rip_pack()
	_check(not Progression.is_set_unlocked(other), "opening product no longer unlocks a set")

	# Saved and loaded: the plate stays up, locked binders stay hidden.
	var saved: Dictionary = main.capture_save()
	main.free()
	Saves._pending = saved
	main = load(SceneFlow.SHOP_SCENE).instantiate()
	add_child(main)
	units = main._shelves()
	pile = main.get_node("Pile")
	unit = units.filter(func(u: ShelfUnit) -> bool: return u.space_for(code) >= 0).front()
	_check(unit.nameplates.is_shown(unit.space_for(code)) and plates_up.call(units) == 1, "a save keeps the plate up")
	_check(pile.binders.all(func(b: Binder) -> bool: return b.visible == (b.binder.set_code == code)),
		"and only the unlocked set's binder is out")

	# The first set of a chapter comes with a sealed booster box instead.
	screen = main.laptop_screen
	screen.open()
	screen.open_app("shop")
	var opener: String = LaptopScreen.shop_sets()[1].code
	Chapters.use_text("Chapter 1\n%s\n%s" % [opener, LaptopScreen.shop_sets()[2].code])
	_check(LaptopScreen.starter_product(opener) == "a sealed booster box"
		and LaptopScreen.starter_product(LaptopScreen.shop_sets()[2].code) == "%d booster packs" % LaptopScreen.STARTER_PACKS,
		"the shop says what comes with each set")
	screen.unlock_set(opener)
	var boxes := pile.get_children().filter(func(n: Node) -> bool: return n is ProductBox and n.set_code == opener)
	_check(boxes.size() == 1 and boxes[0].kind == ProductBox.Kind.BOOSTER, "a chapter's first set comes with a booster box")
	_check(pile.get_children().filter(func(n: Node) -> bool: return n is BoosterPack and n.set_code == opener).is_empty(),
		"and no loose packs")
	_check(screen.shop_status.text.contains("a sealed booster box"), "and the shop says so")
	var second: String = LaptopScreen.shop_sets()[2].code
	screen.unlock_set(second)
	var second_packs := pile.get_children().filter(func(n: Node) -> bool: return n is BoosterPack and n.set_code == second)
	_check(second_packs.size() == LaptopScreen.STARTER_PACKS, "the chapter's next set brings packs")
	Chapters.reload()
	screen.close()
	main.free()
	get_tree().paused = false
	Collection.reset()
	Progression.reset()
	Progression.locks_sets = false


func _test_collector_numbers_are_contiguous() -> void:
	for set_data in CardDatabase.sets_in_shelf_order():
		var cards := CardDatabase.cards_in_set(set_data.code)
		var ok := cards.size() == set_data.card_count
		for i in cards.size():
			ok = ok and cards[i].collector_number == i + 1
		_check(ok, "%s collector numbers should run 1..%d with no gaps" % [set_data.code, set_data.card_count])


func _test_shelf_order() -> void:
	var sets := CardDatabase.sets_in_shelf_order()
	for i in range(1, sets.size()):
		_check(sets[i - 1].release_date <= sets[i].release_date,
			"shelf order broken between %s and %s" % [sets[i - 1].code, sets[i].code])
	for card in [CardDatabase.get_card(0), CardDatabase.cards_in_set(sets[-1].code)[-1]]:
		_check(CardDatabase.binder_for(card) != null, "card %d has no binder" % card.id)


func _test_binders_per_set() -> void:
	var sizes := []
	for count in [143, 216, 217, 269, 324, 325, 449, 700]:
		var set_data := SetData.new()
		set_data.code = "TST"
		set_data.name = "Test Set"
		set_data.card_count = count
		set_data.build_binder()
		_check(set_data.binder.first == 1 and set_data.binder.last == count, "one binder holds all %d cards" % count)
		sizes.append(BinderLayout.size_class(set_data.binder))
		if count == 269:
			_check(set_data.binder.label == "Test Set, 1–269", "binder label: " + set_data.binder.label)
			_check(set_data.binder_for(269) == set_data.binder and set_data.binder_for(270) == null,
				"binder_for finds the set's binder, null past its last card")
	_check(sizes == [0, 0, 1, 1, 1, 2, 2, 2], "small up to 216, standard up to 324, large beyond: %s" % [sizes])
	_check(BinderLayout.SIZE_THICKNESSES[0] < BinderLayout.SIZE_THICKNESSES[1]
		and BinderLayout.SIZE_THICKNESSES[1] < BinderLayout.SIZE_THICKNESSES[2], "bigger binders are thicker")


func _test_binder_layout() -> void:
	var binder := BinderRange.new()
	binder.first = 1
	binder.last = 360
	_check(BinderLayout.page_of(binder, 1) == 0 and BinderLayout.pocket_of(binder, 1) == 0, "card 1 is page 0 pocket 0")
	_check(BinderLayout.pocket_cell(BinderLayout.pocket_of(binder, 3)) == Vector2i(2, 0), "card 3 is top right")
	_check(BinderLayout.pocket_cell(BinderLayout.pocket_of(binder, 4)) == Vector2i(0, 1), "card 4 starts row 2")
	_check(BinderLayout.pocket_cell(BinderLayout.pocket_of(binder, 9)) == Vector2i(2, 2), "card 9 is bottom right")
	_check(BinderLayout.page_of(binder, 10) == 1 and BinderLayout.is_back_of_sheet(1), "card 10 is on the back of sheet 1")
	_check(BinderLayout.sheet_of_page(BinderLayout.page_of(binder, 19)) == 1, "card 19 is on the second sheet")
	_check(BinderLayout.page_count(binder) == 40, "360 cards fill 40 pages")

	binder.last = 449
	_check(BinderLayout.page_count(binder) == 50, "449 cards fill 50 pages, the last one partly")

	# The squashed round spine's normals face square off its surface, so its
	# shading and leather grain don't stretch on the thick binders.
	var spine_tool := SurfaceTool.new()
	spine_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var depth := Binder.SPINE_DEPTH
	var radius := 0.0325
	Binder._append_spine(spine_tool, depth, radius, 0.3, 0.0, 0.0)
	var spine_arrays := spine_tool.commit_to_arrays()
	var spine_verts: PackedVector3Array = spine_arrays[Mesh.ARRAY_VERTEX]
	var spine_normals: PackedVector3Array = spine_arrays[Mesh.ARRAY_NORMAL]
	var cx := -Binder.COVER.x / 2 + depth
	var worst := 1.0
	for i in spine_verts.size():
		var n := spine_normals[i].normalized()
		if absf(n.z) > 0.5:
			continue # the end caps
		var v := spine_verts[i]
		var expected := Vector3((v.x - cx) / (depth * depth), v.y / (radius * radius), 0).normalized()
		worst = minf(worst, n.dot(expected))
	_check(worst > 0.98, "a thick binder's spine normals face square off it (worst dot %.3f)" % worst)

	# A closed binder's rings stay inside its spine, at every size.
	for thickness in BinderLayout.SIZE_THICKNESSES:
		var details: ArrayMesh = Binder._closed_meshes_for(thickness)[1]
		var metal: PackedVector3Array = details.surface_get_arrays(1)[Mesh.ARRAY_VERTEX]
		var furthest := INF
		for v in metal:
			furthest = minf(furthest, v.x)
		_check(furthest >= -Binder.COVER.x / 2 + 0.001, "a %.1f cm binder's rings stay inside its spine (reach %.4f)" % [thickness * 100, furthest])


func _test_card_sort() -> void:
	var first_set := CardDatabase.sets_in_shelf_order()[0]
	var last_set := CardDatabase.sets_in_shelf_order()[-1]
	var a := CardDatabase.cards_in_set(first_set.code)[5]
	var b := CardDatabase.cards_in_set(first_set.code)[6]
	var c := CardDatabase.cards_in_set(last_set.code)[0]
	_check(CardSort.compare(a, b) and not CardSort.compare(b, a), "lower collector number sorts first")
	_check(CardSort.compare(b, c), "earlier set sorts before later set regardless of number")


func _test_shelf_layout() -> void:
	var binders := CardDatabase.all_binders()
	var few: Array[BinderRange] = []
	few.assign(binders.slice(0, 31))
	var bays: Array[Vector2] = [Vector2(0.0, 0.8), Vector2(0.812, 1.6)]
	var layout := ShelfLayout.plan(few, 2, bays)
	_check(layout.binders == few, "every binder gets a space, in shelf order")
	var fits := true
	var fill := [0.0, 0.0]
	for i in layout.binders.size():
		var left := layout.lefts[i]
		var right := left + layout.widths[i]
		fits = fits and layout.widths[i] >= BinderLayout.thickness(few[i]) + ShelfLayout.SPACE_GAP - 0.0001
		fits = fits and ((left >= bays[0].x and right <= bays[0].y) or (left >= bays[1].x and right <= bays[1].y))
		if i > 0:
			var same_shelf := layout.shelves[i] == layout.shelves[i - 1]
			fits = fits and layout.shelves[i] >= layout.shelves[i - 1]
			fits = fits and (not same_shelf or left >= layout.lefts[i - 1] + layout.widths[i - 1] - 0.0001)
		fill[layout.shelves[i]] += layout.widths[i]
	_check(fits, "spaces are at least as wide as their binder, in order, never overlapping or straddling a divider")
	_check(layout.shelves[0] == 0 and layout.shelves[-1] == 1 and absf(fill[0] - fill[1]) < 0.15,
		"the binders split evenly over both shelves (%.2f m and %.2f m)" % fill)

	var eight: Array[BinderRange] = []
	eight.assign(few.slice(0, 8))
	var cramped := ShelfLayout.plan(eight, 1, [Vector2(0.0, 0.5)] as Array[Vector2])
	_check(cramped.binders.size() < 8 and cramped.binders.size() > 0, "binders that don't fit are left out (with an error)")

	var store_script := preload("res://scripts/store/store_builder.gd")
	var fitted := ShelfUnit.fitted_width(binders)
	var most: float = store_script.BACK_SHELF.y - store_script.BACK_SHELF.x - 2 * ShelfUnit.SIDE_THICKNESS
	_check(fitted <= most, "every binder fits on the back wall (%.2f m of %.2f m)" % [fitted, most])
	var bay := fitted / ShelfUnit.BAYS
	var spans: Array[Vector2] = []
	for i in ShelfUnit.BAYS:
		spans.append(Vector2(bay * i + ShelfUnit.DIVIDER_THICKNESS / 2, bay * (i + 1) - ShelfUnit.DIVIDER_THICKNESS / 2))
	var full := ShelfLayout.plan(binders, ShelfUnit.SHELF_HEIGHTS.size(), spans)
	_check(full.binders.size() == binders.size(), "on a fitted shelf every binder gets a space (%d of %d)" % [full.binders.size(), binders.size()])
	# No bay runs empty: every bay's last space ends at its divider, and no
	# space is stretched by much more than a binder's width.
	var filled := true
	for i in full.binders.size():
		var end := full.lefts[i] + full.widths[i]
		var last_in_bay := i == full.binders.size() - 1 or full.shelves[i + 1] != full.shelves[i] \
			or full.lefts[i + 1] > end + ShelfUnit.DIVIDER_THICKNESS / 2
		filled = filled and (not last_in_bay or absf(end - spans[floori(full.lefts[i] / bay)].y) < 0.001)
		filled = filled and full.widths[i] - ShelfLayout.space_width(full.binders[i]) < 0.03
	_check(filled, "the fitted shelf is full: every bay's spaces reach its divider, spread by under 3 cm each")


func _test_pile() -> void:
	var pile := PileWorld.new()
	add_child(pile)
	var obstacle := Rect2(10, 5, 2, 2)
	var obstacles: Array[Rect2] = [obstacle]
	pile.build_one_of_each(Rect2(0, 0, 28, 14), obstacles, 7)
	var total := CardDatabase.card_count()
	_check(pile.card_count_on_floor() == total, "every card starts on the floor")

	var drawn := 0
	var in_obstacle := 0
	for child in pile.get_children():
		if child is MultiMeshInstance3D:
			drawn += child.multimesh.instance_count
	for id in total:
		var p := pile.card_position(id)
		if obstacle.has_point(Vector2(p.x, p.z)):
			in_obstacle += 1
	_check(drawn == total, "chunks draw every card exactly once (%d of %d)" % [drawn, total])
	_check(in_obstacle == 0, "no card lands inside an obstacle footprint (%d did)" % in_obstacle)

	# Picking: the top card at a card's centre is that card or one stacked above it.
	var probe := 1234
	var point := pile.card_position(probe)
	var top := pile.top_card_at(point)
	_check(top >= 0 and pile.card_position(top).y >= point.y, "top_card_at finds the highest card covering a point")

	# Pick up the top card: it leaves the floor and nothing around it moves.
	var gap := pile.card_position(top)
	var neighbours := {}
	for id in total:
		var p := pile.card_position(id)
		if id != top and Vector2(p.x, p.z).distance_to(Vector2(gap.x, gap.z)) < 0.1:
			neighbours[id] = p
	pile.pick_up(top)
	_check(not pile.is_on_floor(top) and pile.card_count_on_floor() == total - 1, "picked-up card leaves the floor")
	_check(pile.top_card_at(gap) != top, "picked-up card can't be picked again")
	pile._process(1.0)
	var unmoved := true
	for id in neighbours:
		unmoved = unmoved and pile.card_position(id) == neighbours[id]
	_check(unmoved, "neighbours stay put when a card is picked up (%d checked)" % neighbours.size())

	# Put it back down somewhere else: it lands on top.
	var drop_point := Vector3(3.0, 0.0, 3.0)
	pile.drop(top, drop_point, 0.3)
	_check(pile.is_on_floor(top) and pile.card_count_on_floor() == total, "dropped card is back on the floor")
	_check(pile.top_card_at(drop_point) == top, "dropped card lands on top of the stack")

	# Toss a card: it arcs forward, lands on the pile and is pickable again.
	pile.pick_up(top)
	var tossed := TossedCard.new()
	pile.add_child(tossed)
	var start := Transform3D(Basis(), Vector3(5.0, 1.3, 5.0))
	tossed.launch(top, pile, ShaderMaterial.new(), start, Vector3(1.6, 1.0, 0.0), Vector3(TAU, 0.2, 0.3))
	var steps := 0
	while is_instance_valid(tossed) and not tossed.is_queued_for_deletion() and steps < 600:
		tossed._physics_process(1.0 / 60.0)
		steps += 1
	var landed := pile.card_position(top)
	_check(pile.is_on_floor(top), "tossed card lands back on the floor (after %d steps)" % steps)
	_check(landed.x > 5.3 and landed.x < 7.5 and absf(landed.z - 5.0) < 0.05, "toss is a gentle lob forward (landed at x=%.2f)" % landed.x)
	pile.queue_free()


func _test_pile_aim() -> void:
	var pile := PileWorld.new()
	add_child(pile)
	var no_obstacles: Array[Rect2] = []
	pile.build_one_of_each(Rect2(0, 0, 28, 14), no_obstacles, 7)

	# Stack 40 cards in one spot and look at the top one from low down, as
	# when crouching in a big pile: the crosshair's ray reaches the floor well
	# past the stack, but the card you aim at is the one it meets first.
	var spot := Vector3(6.0, 0.0, 7.0)
	var stack: Array[int] = []
	for id in range(100, 140):
		pile.pick_up(id)
		pile.drop(id, spot, 0.0)
		stack.append(id)
	var top := stack[-1]
	var face := pile.card_position(top)
	var from := face + Vector3(0.0, 0.25, 0.7)
	var to := from + (face - from).normalized() * 3.0
	var aimed := pile.card_on_ray(from, to)
	_check(not aimed.is_empty() and aimed.id == top, "the card under the crosshair is the one you see, on top of the stack")
	_check(not aimed.is_empty() and Vector3(aimed.position).distance_to(face) < 0.001, "and the aim point is on its face")
	var floor_point := from + (to - from) * (from.y / (from.y - to.y))
	_check(pile.top_card_at(floor_point) != top, "not the card over where the ray reaches the floor")

	# Anywhere in the pile, the card hit is the first card face along the ray.
	var right := true
	var hits := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 20:
		var at := pile.card_position(rng.randi_range(0, pile._positions.size() - 1))
		var eye := Vector3(at.x + rng.randf_range(-1.0, 1.0), rng.randf_range(0.4, 1.6), at.z + rng.randf_range(-1.0, 1.0))
		var end := eye + (at - eye).normalized() * 3.0
		var expected := -1
		var nearest := INF
		for id in pile._positions.size():
			if not pile.is_on_floor(id):
				continue
			var y := pile.card_position(id).y
			var t := (y - eye.y) / (end.y - eye.y)
			if t >= 0.0 and t <= 1.0 and t < nearest and pile._covers(id, Vector2(lerpf(eye.x, end.x, t), lerpf(eye.z, end.z, t))):
				nearest = t
				expected = id
		var got := pile.card_on_ray(eye, end)
		right = right and (got.id if not got.is_empty() else -1) == expected
		hits += 1 if expected >= 0 else 0
	_check(right and hits > 0, "the aimed card is always the first card face the ray meets (%d rays hit cards)" % hits)
	_check(pile.card_on_ray(Vector3(6.0, 1.0, 7.0), Vector3(6.0, 1.0, 9.0)).is_empty(), "a ray above the pile meets no card")
	pile.queue_free()


func _test_pile_clearing() -> void:
	var pile := PileWorld.new()
	add_child(pile)
	var no_obstacles: Array[Rect2] = []
	pile.build_one_of_each(Rect2(0, 0, 28, 14), no_obstacles, 7)

	# Clearing a spot lowers the pile there, so whatever is put down next
	# lands on what's left, not on the cards that used to be there.
	var spot := pile.card_position(4321)
	var spot_2d := Vector2(spot.x, spot.z)
	var height_before := pile.height_at(spot_2d)
	var cleared := 0
	var id := pile.top_card_at(spot)
	while id >= 0 and cleared < 200:
		pile.pick_up(id)
		pile._process(1.0)
		cleared += 1
		id = pile.top_card_at(spot)
	# Recheck from the cards themselves: the highest card still on the floor
	# covering the spot's height cell, or the floor itself.
	var height_cell := pile._height_index(spot_2d)
	var expected := 0.0
	for card in pile._cards_near(pile._height_cell_center(height_cell)):
		if not pile.is_on_floor(card):
			continue
		if pile._covers(card, pile._height_cell_center(height_cell)):
			expected = maxf(expected, pile.card_position(card).y)
	_check(cleared > 0 and is_equal_approx(pile.height_at(spot_2d), expected),
		"a cleared spot drops to what's left (%.4f before, %.4f after %d pick-ups, expected %.4f)" % [
			height_before, pile.height_at(spot_2d), cleared, expected])

	pile.queue_free()


## Cards rest on what's really under them, and the dump is deep in the
## middle and thin at the edges.
func _test_pile_stacking() -> void:
	var pile := PileWorld.new()
	add_child(pile)
	var bounds := Rect2(0.05, 0.05, 11.9, 7.9)
	var no_obstacles: Array[Rect2] = []
	pile.build_one_of_each(bounds, no_obstacles, 11)
	var resting := 0
	var sampled := 0
	for k in 300:
		var id := k * 97
		var at := pile.card_position(id)
		var support := 0.0
		for cell in pile._footprint_cells(Vector2(at.x, at.z), pile._rotations[id]):
			var center := pile._height_cell_center(cell)
			for other in pile._cards_near(center):
				var oy := pile.card_position(other).y
				if other != id and oy < at.y and oy > support and pile._covers(other, center):
					support = oy
		sampled += 1
		if is_equal_approx(at.y, support + PileWorld.CARD_THICKNESS):
			resting += 1
	_check(resting == sampled, "every card rests one card's thickness above what's under it (%d of %d)" % [resting, sampled])

	var middle := Rect2(bounds.position + bounds.size / 4, bounds.size / 2)
	var inside := 0
	for id in CardDatabase.card_count():
		var at := pile.card_position(id)
		if middle.has_point(Vector2(at.x, at.z)):
			inside += 1
	var share := float(inside) / CardDatabase.card_count()
	_check(share > 0.5, "most cards land in the middle quarter of the floor (%.0f%%)" % (share * 100))
	pile.queue_free()


func _test_pile_grid() -> void:
	var pile := PileWorld.new()
	add_child(pile)
	var no_obstacles: Array[Rect2] = []
	pile.build_one_of_each(Rect2(0, 0, 28, 14), no_obstacles, 7)

	# Gap fill keeps the picking grid tidy: one entry per card on the floor.
	for k in 400:
		var top := pile.top_card_at(pile.card_position(k * 37))
		if top >= 0:
			pile.pick_up(top)
			pile._process(1.0)
	var grid_entries := 0
	for cell in pile._grid:
		grid_entries += cell.size()
	_check(grid_entries == pile.card_count_on_floor(),
		"picking grid has one entry per floor card (%d entries, %d cards)" % [grid_entries, pile.card_count_on_floor()])

	# A card put down lands exactly where its ghost showed it would.
	var id := pile.top_card_at(pile.card_position(5))
	var aim := pile.card_position(id)
	pile.pick_up(id)
	var shown := pile.drop_pose(aim, 0.4)
	pile.drop(id, aim, 0.4)
	_check(pile.card_position(id).is_equal_approx(shown.origin),
		"a dropped card lands at its drop pose (%s vs %s)" % [pile.card_position(id), shown.origin])
	pile.queue_free()


func _test_binder_spreads() -> void:
	var binder := BinderRange.new()
	binder.first = 1
	binder.last = 269 # Khans of Tarkir: 30 pages
	_check(BinderLayout.spread_count(binder) == 16, "30 pages make 16 spreads (cover + 15)")
	_check(BinderLayout.spread_pages(binder, 0) == Vector2i(-1, 0), "spread 0 is the inside cover and page 1")
	_check(BinderLayout.spread_pages(binder, 1) == Vector2i(1, 2), "spread 1 is the back of sheet 1 and the front of sheet 2")
	_check(BinderLayout.spread_pages(binder, 15) == Vector2i(29, -1), "the last spread ends on the back cover")
	var all_found := true
	for page in 30:
		var pages := BinderLayout.spread_pages(binder, BinderLayout.spread_of_page(page))
		all_found = all_found and (pages.x == page or pages.y == page)
	_check(all_found, "spread_of_page finds every page")


## The first binder of the first set, and its cards' ids in collector order.
func _first_binder_cards() -> Array[int]:
	var ids: Array[int] = []
	var binder := CardDatabase.all_binders()[0]
	for card in CardDatabase.cards_in_set(binder.set_code):
		if binder.contains(card.collector_number):
			ids.append(card.id)
	return ids


func _test_binder_contents() -> void:
	var binder := CardDatabase.all_binders()[0]
	var ids := _first_binder_cards()
	var contents := BinderContents.new(binder)
	_check(contents.capacity() == ids.size(), "a binder has one pocket per card in its range")
	_check(contents.insert(0, ids[0]) == BinderContents.Result.LOCKED, "a card in its own pocket locks in")
	_check(contents.card_at(0) == ids[0] and contents.is_locked(0), "and stays there")
	_check(contents.insert(0, ids[1]) == BinderContents.Result.OCCUPIED, "a full pocket refuses another card")
	_check(contents.insert(2, ids[1]) == BinderContents.Result.WRONG_POCKET and contents.card_at(2) == -1,
		"the wrong pocket refuses a card")
	var other_set := CardDatabase.cards_in_set(CardDatabase.sets_in_shelf_order()[1].code)[3]
	_check(contents.insert(3, other_set.id) == BinderContents.Result.WRONG_POCKET and contents.card_at(3) == -1,
		"so does a pocket of the same number in another set's binder")
	# A save puts every card back in its own pocket; anything else (an older
	# save's misplaced card, another set's card) comes back to go on the floor.
	var saved := PackedInt32Array()
	saved.resize(contents.capacity())
	saved.fill(-1)
	saved[0] = ids[0]
	saved[5] = ids[2]
	saved[6] = other_set.id
	var left := contents.restore(saved)
	_check(contents.locked_count == 2 and contents.card_at(0) == ids[0] and contents.card_at(2) == ids[2]
		and contents.card_at(5) == -1 and left == PackedInt32Array([other_set.id]),
		"restoring a save files each card in its own pocket and returns the rest")
	contents.restore(PackedInt32Array())
	contents.insert(0, ids[0])
	for i in range(1, 8):
		contents.insert(i, ids[i])
	_check(not contents.is_page_complete(0), "a page with an empty pocket isn't complete")
	contents.insert(8, ids[8])
	_check(contents.is_page_complete(0) and not contents.is_page_complete(1), "nine locked cards complete a page")
	_check(not contents.is_complete(), "one page doesn't complete the binder")
	for i in range(9, ids.size()):
		contents.insert(i, ids[i])
	_check(contents.is_complete() and contents.locked_count == ids.size(), "every card locked completes the binder")
	var last_page := (ids.size() - 1) / BinderLayout.POCKETS_PER_PAGE
	_check(contents.is_page_complete(last_page), "a short last page completes with only its numbered pockets")


func _test_binder_pockets() -> void:
	var range_data := CardDatabase.all_binders()[0]
	var ids := _first_binder_cards()
	var binder := Binder.new()
	binder.setup(range_data, Color.RED, null)
	add_child(binder)
	binder.put_down(self, Vector3(4.0, 0.75, 2.0), 0.6)
	_check(binder.pocket_at(binder.global_position) == -1, "a closed binder has no pockets to aim at")
	binder.open()
	_check(binder.is_open(), "a binder lying down opens")
	_check(binder.pocket_at(binder.to_global(binder.pocket_position(0))) == 0, "spread 0 shows pocket 0 on the right page")
	_check(binder.pocket_at(binder.to_global(Vector3(-Binder.COVER.x / 2, Binder.OPEN_HEIGHT, 0))) == -1,
		"the inside cover has no pockets")
	_check(not binder.flip(-1), "can't turn back past the front cover")
	binder.flip(1)
	# Spread 1: page 2 (pockets 9-17) on the left, page 3 (18-26) on the right.
	var left_top_left := binder.to_global(Vector3(-Binder.COVER.x / 2 - Binder.CELL.x, Binder.OPEN_HEIGHT, -Binder.CELL.y))
	var right_bottom_right := binder.to_global(Vector3(Binder.COVER.x / 2 + Binder.CELL.x, Binder.OPEN_HEIGHT, Binder.CELL.y))
	_check(binder.pocket_at(left_top_left) == 9, "left page's top-left pocket is #10 (got %d)" % binder.pocket_at(left_top_left))
	_check(binder.pocket_at(right_bottom_right) == 26, "right page's bottom-right pocket is #27 (got %d)" % binder.pocket_at(right_bottom_right))

	_check(binder.insert(9, ids[10]) == BinderContents.Result.WRONG_POCKET and binder.contents.card_at(9) == -1,
		"the wrong pocket refuses a card through the binder")
	for i in ids.size():
		binder.show_pocket(i)
		binder.insert(i, ids[i])
	_check(binder.contents.is_complete(), "filing every card through the binder completes it")
	binder.close()
	_check(binder.state == Binder.State.CLOSED, "a complete binder closes")
	binder.queue_free()


func _test_binder_lettering() -> void:
	var box := BinderLettering.COVER_TITLE.size
	var cap_range := BinderLettering.COVER_TITLE_CAP
	var names := ["Antiquities", "Adventures in the Forgotten Realms", "March of the Machine: The Aftermath",
		"Strixhaven: School of Mages", "Shadows over Innistrad", "Fourth Edition Foreign Black Border"]
	for set_data in CardDatabase.sets_in_shelf_order():
		names.append(set_data.name)
	var spine_box := Vector2(BinderLettering.SPINE_TITLE.y - BinderLettering.SPINE_TITLE.x,
		BinderLayout.SIZE_THICKNESSES[0] - 2 * BinderLettering.SPINE_MARGIN)
	var whole := true
	var fits := true
	for set_name: String in names:
		var text := set_name.to_upper()
		var on_cover := BinderLettering.fit(text, box, cap_range)
		var on_spine := BinderLettering.fit(text, spine_box, BinderLettering.SPINE_TITLE_CAP, 2)
		whole = whole and " ".join(on_cover.lines) == text and " ".join(on_spine.lines) == text
		fits = fits and _lettering_fits(on_cover, box) and _lettering_fits(on_spine, spine_box)
	_check(whole, "set names only ever break between words, in order")
	_check(fits, "every set name fits its cover and spine panels")
	var antiquities := BinderLettering.fit("ANTIQUITIES", box, cap_range)
	_check(antiquities.lines.size() == 1, "a one-word name stays on one line: %s" % [antiquities.lines])
	var strixhaven := BinderLettering.fit("STRIXHAVEN: SCHOOL OF MAGES", box, cap_range)
	_check(strixhaven.lines[0] == "STRIXHAVEN:", "a name with a colon breaks after it: %s" % [strixhaven.lines])
	var realms := BinderLettering.fit("ADVENTURES IN THE FORGOTTEN REALMS", box, cap_range)
	_check(realms.lines.size() > 1 and realms.cap > BinderLettering.fit("ADVENTURES IN THE FORGOTTEN REALMS", box, cap_range, 1).cap,
		"a long name takes more lines to be bigger: %s" % [realms.lines])
	var by_hand := BinderLettering.fit("ADVENTURES\nIN THE FORGOTTEN REALMS", box, cap_range)
	_check(by_hand.lines == PackedStringArray(["ADVENTURES", "IN THE FORGOTTEN REALMS"]), "a line break laid out by hand is kept")

	var set_data := CardDatabase.sets_in_shelf_order()[0]
	var masks := BinderLettering.masks(set_data, BinderLayout.SIZE_THICKNESSES[0])
	var cover: Image = masks[0].get_image()
	var spine: Image = masks[1].get_image()
	_check(spine.get_height() == ceili(BinderLayout.SIZE_THICKNESSES[0] * BinderLettering.DENSITY), "the spine mask spans the binder's thickness")
	cover.clear_mipmaps()
	var lit := 0
	for y in range(0, cover.get_height(), 2):
		for x in range(0, cover.get_width(), 2):
			lit += 1 if cover.get_pixel(x, y).r > 0.5 else 0
	_check(lit > 200, "the cover mask has lettering in it (%d px)" % lit)


## Whether fitted lettering stays inside its box.
func _lettering_fits(fitted: Dictionary, box: Vector2) -> bool:
	var widest := 0.0
	for line: String in fitted.lines:
		widest = maxf(widest, BinderLettering.line_width(line) * fitted.cap)
	var height: float = fitted.cap * (1.0 + (fitted.lines.size() - 1) * BinderLettering.LEADING)
	return widest <= box.x + 1e-6 and height <= box.y + 1e-6


func _test_leather_colour() -> void:
	var red := Binder.leather_colour(Color("#c94f4f"))
	var blue := Binder.leather_colour(Color("#4f6fc9"))
	var green := Binder.leather_colour(Color("#4fc96a"))
	_check(red.get_luminance() < 0.35 and blue.get_luminance() < 0.35 and green.get_luminance() < 0.35, "dyed leather is dark")
	_check(red.r > red.b and blue.b > blue.r and green.g > green.r, "dyed leather keeps the set's hue")
	_check(red.s < Color("#c94f4f").s + 0.2, "dyed leather isn't more vivid than the set colour")


func _test_shelving() -> void:
	var ranges := CardDatabase.all_binders()
	var few: Array[BinderRange] = []
	few.assign(ranges.slice(0, 24))
	var unit := ShelfUnit.new()
	unit.build(few, StandardMaterial3D.new(), 2.4)
	add_child(unit)
	unit.position = Vector3(3, 0, 1)
	unit.rotation.y = PI / 2

	var space_point := unit.to_global(unit.space_position(1) + Vector3(0, 0.1, ShelfUnit.DEPTH / 2))
	_check(unit.space_at(space_point) == 1, "aiming at the front of the top shelf's second space finds space 1")
	var last := unit.spaces.size() - 1
	var lower := unit.to_global(unit.space_position(last) + Vector3(0, 0.2, ShelfUnit.DEPTH / 2))
	_check(unit.shelf_of(last) == 1 and unit.space_at(lower) == last, "the lower shelf's last space")
	var under := unit.to_global(Vector3(0, ShelfUnit.leg_height() / 2, ShelfUnit.DEPTH / 2))
	_check(unit.space_at(under) == -1, "there are no spaces down among the legs")
	var spots := unit.leg_spots()
	var spaced := spots.size() >= 2
	for i in range(1, spots.size()):
		spaced = spaced and spots[i] > spots[i - 1] and absf((spots[i] - spots[i - 1]) - (spots[1] - spots[0])) < 0.05
	_check(spaced and spots[0] < -1.1 and spots[-1] > 1.1, "leg pairs stand under both ends and evenly along the span")
	var top := unit.top_rect()
	_check(is_equal_approx(top.position.y, -ShelfUnit.DEPTH / 2) and top.end.y > ShelfUnit.DEPTH / 2 and top.size.x > 2.4,
		"the top covers the whole unit, back to the wall")

	var right := Binder.new()
	right.setup(ranges[0], Color.RED, null)
	var wrong := Binder.new()
	wrong.setup(ranges[1], Color.BLUE, null)
	add_child(right)
	add_child(wrong)
	_check(not unit.shelve(0, wrong), "a binder in another binder's space doesn't lock")
	_check(wrong.state == Binder.State.SHELVED and unit.shelved[0] == wrong, "but it stands there anyway")
	unit.unshelve(0)
	_check(unit.shelve(0, right), "a binder in its own space locks in")
	var spine := right.to_global(Vector3(-Binder.COVER.x / 2, right.thickness / 2, 0))
	var spine_local := unit.to_local(spine)
	_check(spine_local.z > ShelfUnit.DEPTH / 2 and absf(spine_local.x - unit.space_position(0).x) < 0.001,
		"the binder stands spine out in its space")
	_check(not unit.is_section_complete(0), "an incomplete binder doesn't light its shelf")
	_check(not unit.nameplates.is_gold(0), "an incomplete binder leaves its nameplate black")
	var cover_glow: Color = right._cover_material.get_shader_parameter("glow")
	_check(cover_glow.r + cover_glow.g + cover_glow.b == 0.0, "an incomplete binder in its own space doesn't glow gold")

	# Fill every binder on the top shelf, shelve them all: the shelf lights up.
	var shelf_binders: Array[Binder] = [right]
	for space in range(1, unit.spaces.size()):
		if unit.shelf_of(space) != 0:
			continue
		var b := Binder.new()
		b.setup(unit.spaces[space], Color.WHITE, null)
		add_child(b)
		unit.shelve(space, b)
		shelf_binders.append(b)
	for b in shelf_binders:
		for card in CardDatabase.cards_in_set(b.binder.set_code):
			if b.binder.contains(card.collector_number):
				b.contents.insert(card.collector_number - b.binder.first, card.id)
	_check(unit.refresh_section(0), "a shelf of complete binders in their own spaces lights up")
	_check(unit.nameplates.is_gold(0) and unit.nameplates.is_gold(1), "complete binders in their own spaces turn their nameplates gold")
	unit.unshelve(0)
	_check(not unit.is_section_complete(0), "taking one down turns it off again")
	_check(not unit.nameplates.is_gold(0) and unit.nameplates.is_gold(1), "and turns its nameplate back to black")
	unit.queue_free()
	wrong.queue_free()
	for b in shelf_binders:
		if is_instance_valid(b):
			b.queue_free()


func _test_loose_card() -> void:
	var card := LooseCard.new()
	add_child(card)
	card.setup(10, Vector3(1, 0.75, 1), 0.5)
	_check(card.card_id == 10, "a loose card keeps its card")
	_check(card.card_pose().origin.is_equal_approx(LooseCard.pose_at(Vector3(1, 0.75, 1), 0.5).origin),
		"a loose card lies where its ghost showed it would")
	_check(card.collision_layer == Binder.PHYSICS_LAYER, "loose cards can be aimed at and rested on like binders")
	card.queue_free()


const FIXTURE_DIR := "user://test_real_data"
## A tiny atlas: 4 × 2 slots of 16 × 22 px on 64 px pages, so 10 cards need two pages,
## and 32 × 44 px near faces.
const FIXTURE_FACES := {"pages": ["faces/page_0.png", "faces/page_1.png"], "page_size": 64,
	"slot_size": [16, 22], "columns": 4, "rows": 2, "near": "near/{set}/{number}.dds", "near_size": [32, 44]}
const FIXTURE_CARDS := 10


## Writes a small data file shaped like tools/import_scryfall.py's output,
## with made-up cards: each face is a flat colour whose red channel is
## (card id + 1) × 20.
func _write_fixture(with_pages := true) -> String:
	DirAccess.make_dir_recursive_absolute(FIXTURE_DIR + "/faces")
	DirAccess.make_dir_recursive_absolute(FIXTURE_DIR + "/images/tst")
	DirAccess.make_dir_recursive_absolute(FIXTURE_DIR + "/near/tst")
	var rows := []
	for id in FIXTURE_CARDS:
		var face := Image.create(48, 66, false, Image.FORMAT_RGB8)
		face.fill(Color8((id + 1) * 20, 100, 50))
		face.save_png("%s/images/tst/%d.png" % [FIXTURE_DIR, id + 1])
		var near := Image.create(32, 44, false, Image.FORMAT_RGB8)
		near.fill(Color8((id + 1) * 20, 100, 50))
		near.generate_mipmaps()
		near.compress(Image.COMPRESS_S3TC)
		near.save_dds("%s/near/tst/%d.dds" % [FIXTURE_DIR, id + 1])
		rows.append(["TST", id + 1, "Test Card %d" % (id + 1), "rare", ["G"], "Creature — Bear", "images/tst/%d.png" % (id + 1)])
		# The first two carry prices (dollars, null for none); the rest are
		# written the way files from before prices were.
		if id == 0:
			rows.back().append_array([0.29, 1.5])
		elif id == 1:
			rows.back().append_array([1.16, null])
	for p in 2:
		var page := Image.create(64, 64, false, Image.FORMAT_RGB8)
		for slot in 8:
			var id := p * 8 + slot
			if id < FIXTURE_CARDS:
				page.fill_rect(Rect2i((slot % 4) * 16, (slot / 4) * 22, 16, 22), Color8((id + 1) * 20, 100, 50))
		var page_path := "%s/faces/page_%d.png" % [FIXTURE_DIR, p]
		if with_pages:
			page.save_png(page_path)
		elif FileAccess.file_exists(page_path):
			DirAccess.remove_absolute(page_path)
	var back := Image.create(48, 66, false, Image.FORMAT_RGB8)
	back.fill(Color8(90, 60, 30))
	back.save_png(FIXTURE_DIR + "/back.png")
	var data := {"format": 1, "source": "test fixture", "faces": FIXTURE_FACES, "back": "back.png", "cards": rows,
		"sets": [{"code": "TST", "name": "Test Set", "release_date": "2014-09-26", "accent_color": "#a8783c",
			"artists": ["Amy Artist", "Zed Painter"]}]}
	var path := FIXTURE_DIR + "/cards.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	return path


func _test_folder_names() -> void:
	_check(CardFileLoader.folder_name("CON") == "con_" and CardFileLoader.folder_name("LPT1") == "lpt1_",
		"a set code Windows reserves gets an underscore on disk, as the importer writes it")
	_check(CardFileLoader.folder_name("KTK") == "ktk", "any other code is just lower case")


func _test_card_values() -> void:
	var make := func(rarity: CardData.Rarity, price: float, type_line := "Creature — Bear") -> CardData:
		var card := CardData.new()
		card.rarity = rarity
		card.price = price
		card.type_line = type_line
		return card
	var C := CardData.Rarity.COMMON
	var R := CardData.Rarity.RARE
	var M := CardData.Rarity.MYTHIC
	# A set like Khans: commons at $0.06, rares at $0.29, a $19.77 fetchland.
	var cards := [make.call(C, 0.05), make.call(C, 0.06), make.call(C, 0.07), make.call(R, 0.25), make.call(R, 0.29),
		make.call(R, 19.77), make.call(M, 0.65), make.call(C, -1.0), make.call(C, 0.30, "Basic Land — Forest"),
		make.call(CardData.Rarity.UNCOMMON, -1.0)]
	CardValues.assign_set(cards)
	_check(is_equal_approx(cards[1].value, 0.10), "a median common is worth $0.10")
	_check(is_equal_approx(cards[4].value, 0.50) and is_equal_approx(cards[6].value, 2.50),
		"a median rare 5 commons, a median mythic 25")
	_check(absf(cards[5].value - 0.5 * sqrt(19.77 / 0.29)) < 1e-6, "a pricey rare: the square root of its lead")
	_check(is_equal_approx(cards[7].value, 0.10), "a card with no price is worth its rarity's median")
	_check(is_equal_approx(cards[8].value, 0.10), "basic lands are priced against each other, not the commons")
	_check(is_equal_approx(cards[9].value, 0.20), "a rarity with no prices gets its baseline")
	# An older set whose commons go for four times as much: every card x2.
	var old := [make.call(C, 0.24), make.call(R, 1.0)]
	CardValues.assign_set(old)
	_check(is_equal_approx(old[0].value, 0.20) and is_equal_approx(old[1].value, 1.0), "the era scale prices whole sets")
	var unpriced := [make.call(C, -1.0), make.call(M, -1.0)]
	CardValues.assign_set(unpriced)
	_check(is_equal_approx(unpriced[0].value, 0.10) and is_equal_approx(unpriced[1].value, 2.50),
		"a set with no prices (the placeholders) gets plain baselines")
	_check(CardDatabase.cards_in_set(CardDatabase.sets_in_shelf_order()[0].code).all(
		func(c: CardData) -> bool: return c.value > 0.0), "loaded cards all have a value")


func _test_card_corners() -> void:
	var alpha := CardData.new()
	alpha.set_code = "LEA"
	var beta := CardData.new()
	beta.set_code = "LEB"
	_check(alpha.has_alpha_corners() and not beta.has_alpha_corners(), "only Alpha has Alpha's corners")
	for alpha_corners in [false, true]:
		var radius := PileWorld.ALPHA_CORNER_RADIUS if alpha_corners else PileWorld.CORNER_RADIUS
		var arrays := PileWorld.card_mesh(alpha_corners).surface_get_arrays(0)
		var half := PileWorld.CARD_SIZE / 2
		var inside := true
		var covers := true
		var rounded := 0
		for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			var p := Vector2(absf(v.x), absf(v.z))
			inside = inside and p.x <= half.x + 1e-6 and p.y <= half.y + 1e-6
			var into_corner := p - (half - Vector2(radius, radius))
			if into_corner.x > 1e-6 and into_corner.y > 1e-6:
				rounded += 1
				covers = covers and into_corner.length() >= radius - 1e-6
		_check(inside, "the card mesh stays within the card's size")
		_check(rounded > 0 and covers, "the card mesh's corners are rounded and cover the true curve")
	var usual := PileWorld.card_mesh(false).surface_get_arrays(0)
	var corner_vertex: Vector3 = usual[Mesh.ARRAY_VERTEX][0]
	var alpha_vertex: Vector2 = usual[Mesh.ARRAY_TEX_UV2][0]
	_check(alpha_vertex.length() < Vector2(corner_vertex.x, corner_vertex.z).length(),
		"the floor mesh carries Alpha's deeper cut for the shader")
	_check(PileWorld.card_mesh(false).get_faces().size() / 3 <= 40, "a floor card stays cheap to draw")


func _test_real_data_format() -> void:
	var path := _write_fixture()
	_check(CardDatabase.load_file(path) == OK, "real-data file loads")
	_check(CardDatabase.is_real_data() and CardDatabase.card_count() == FIXTURE_CARDS + RareCards.count(),
		"real data replaces the placeholders (and the rare cards come too)")
	var atlas := CardDatabase.face_atlas
	_check(atlas != null and atlas.texture.get_layers() == 2, "the face atlas loads both pages")
	if atlas == null:
		return
	_check(atlas.slots_per_page() == 8 and atlas.slot_uv.is_equal_approx(Vector2(0.25, 22.0 / 64.0)), "atlas layout comes from the file")
	var card := CardDatabase.get_card(9)
	_check(card.face_index == 9 and card.image_large == FIXTURE_DIR + "/images/tst/10.png", "cards know their atlas slot and large image")
	_check(atlas.texture.get_width() == 64 and atlas.texture.get_height() == 64, "atlas pages keep their size")
	var large := CardView.large_face(card)
	_check(large != null and large.get_size() == Vector2(48, 66), "the large face loads for the held card")
	var priced := CardDatabase.get_card(0)
	_check(is_equal_approx(priced.price, 0.29) and is_equal_approx(priced.foil_price, 1.5)
		and is_equal_approx(CardDatabase.get_card(1).price, 1.16) and CardDatabase.get_card(1).foil_price < 0.0
		and card.price < 0.0, "prices load from the file, and a card without one has none")
	_check(card.value > 0.0 and priced.value < CardDatabase.get_card(1).value, "and cards get values from them")
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/held_card.gdshader")
	CardView.apply(material, 9)
	_check(material.get_shader_parameter("has_face") == true, "single-card materials switch to the real face")
	_check(CardDatabase.card_back != null and CardDatabase.card_back.get_size() == Vector2(48, 66), "the card back loads")
	_check(material.get_shader_parameter("has_back") == true, "single-card materials get the real card back")
	_check(card.image_near == FIXTURE_DIR + "/near/tst/10.dds", "cards know their near face")
	_check(CardDatabase.near_paths.size() == FIXTURE_CARDS and CardDatabase.near_paths[9] == card.image_near
		and CardDatabase.near_size == Vector2i(32, 44), "the database lists near faces by face index")
	var binder_material := ShaderMaterial.new()
	binder_material.shader = preload("res://shaders/binder_card.gdshader")
	CardView.apply(binder_material, 9)
	var pocket_face: Texture2D = binder_material.get_shader_parameter("face_texture")
	_check(pocket_face != null and pocket_face.get_size() == Vector2(32, 44), "binder and table cards show the near face")
	var held_face: Texture2D = material.get_shader_parameter("face_texture")
	_check(held_face.get_size() == Vector2(48, 66), "the held card keeps the large image")
	var low := FaceAtlas.load_pages(CardDatabase._faces, true)
	_check(low.texture.get_width() == 32 and low.slot_height() == 11 and atlas.slot_height() == 22,
		"low card detail loads the far faces at half size")

	# One set, one binder: one labelled shelf space, the rest blank.
	var layout := ShelfLayout.plan(CardDatabase.all_binders(), 2, [Vector2(0.0, 7.9)] as Array[Vector2])
	_check(layout.binders.size() == 1 and layout.binders[0] == CardDatabase.all_binders()[0], "one set gets one labelled shelf space")

	# The pile hands each card's atlas slot to the floor shader (in the
	# instance colour's alpha; the headless renderer keeps no buffers to check).
	var pile := PileWorld.new()
	add_child(pile)
	var no_obstacles: Array[Rect2] = []
	pile.build_one_of_each(Rect2(0, 0, 4, 4), no_obstacles, 3)
	_check(pile.card_count_on_floor() == FIXTURE_CARDS + RareCards.count(), "the whole real set is on the floor, with the rare cards")
	var faces_ok := true
	for id in FIXTURE_CARDS:
		faces_ok = faces_ok and pile._faces[id] == id
	_check(faces_ok, "floor cards carry their face atlas slot")
	_check(pile._material.get_shader_parameter("has_back") == true, "face-down floor cards show the real card back")
	_check(pile.near_faces != null and pile._material.get_shader_parameter("near_on") == true, "the floor gets a pool of near faces")
	_test_near_request(pile)
	pile.free()

	# A missing page falls back to placeholder faces rather than failing.
	path = _write_fixture(false)
	_check(CardDatabase.load_file(path) == OK and CardDatabase.face_atlas == null, "missing atlas pages fall back to placeholder faces")
	_check(CardDatabase.get_card(0).face_index == -1, "and cards stop pointing into the atlas")
	_write_fixture()


## Which floor cards PileWorld asks near faces for: face up, not buried, the
## nearest first.
func _test_near_request(pile: PileWorld) -> void:
	var near := NearFaces.new(CardDatabase.near_paths, CardDatabase.near_size, 4)
	pile.near_faces = near
	var target := 3
	var top := pile._positions[target]
	pile._face_up[target] = 1
	pile.request_near_faces(top + Vector3(0, 0.3, 0), 0.5)
	_check(near._wanted.has(target) == (top.y >= pile.height_at(Vector2(top.x, top.z)) - PileWorld.NEAR_BURIED),
		"a card right under the eye wants its near face unless it's buried")
	pile.request_near_faces(top + Vector3(0, 0.3, 0), 0.001)
	_check(near._wanted.is_empty(), "nothing wants a near face when every card is far enough away")
	pile._face_up[target] = 0
	pile._heights.fill(0.0) # nothing counts as buried
	pile.request_near_faces(top + Vector3(0, 0.3, 0), 10.0)
	_check(not near._wanted.has(target) and near._wanted.size() == 4, "face-down cards want none; the rest fill the pool")


func _test_near_faces() -> void:
	_write_fixture()
	CardDatabase.load_file(FIXTURE_DIR + "/cards.json")
	var near := NearFaces.new(CardDatabase.near_paths, CardDatabase.near_size, 2)
	_check(near.pool.get_layers() == 2 and near.pool.get_width() == 32 and near.pool.get_height() == 44, "the pool holds its capacity of near faces")
	near.request(PackedInt32Array([4, 7, 1]), PackedInt32Array([7]))
	_check(near._wanted.size() == 2 and near._wanted.has(4) and near._wanted.has(7), "only as many cards as the pool holds are wanted, nearest first")
	_wait_for_near(near, 2)
	_check(near.has_face(4) and near.has_face(7) and not near.has_face(1), "wanted near faces load")
	var lookup := near._lookup_image.get_pixel(7, 0)
	_check(lookup.r >= 0.0 and lookup.b == 1.0 and near._lookup_image.get_pixel(4, 0).b == 0.0,
		"the lookup gives each face its layer, and marks the one that arrived late")
	_check(near._lookup_image.get_pixel(1, 0).r == -1.0, "cards without a near face read -1")
	_check(near.late_count == 1 and near.arrived_count == 2, "late arrivals are counted")
	near.request(PackedInt32Array([1, 4]), PackedInt32Array())
	_wait_for_near(near, 3)
	_check(near.has_face(1) and near.has_face(4) and not near.has_face(7), "a card no longer wanted gives its layer up")
	_check(near._lookup_image.get_pixel(7, 0).r == -1.0, "and goes back to its far face")
	var gone := NearFaces.new(PackedStringArray(["user://no_such_face.dds"]), Vector2i(32, 44), 1)
	gone.request(PackedInt32Array([0]), PackedInt32Array())
	for i in 200:
		if gone.loading_count() == 0:
			break
		gone.update(0.01)
		OS.delay_msec(5)
	_check(not gone.has_face(0), "a missing near face just leaves the far face")
	_check(NearFaces.pool_capacity(1080, false) == 1024 and NearFaces.pool_capacity(2160, false) == 2048
		and NearFaces.pool_capacity(2160, true) == 256, "the pool is sized for the screen and card detail")


## Updates `near` until it has shown `count` faces in all (or gives up).
func _wait_for_near(near: NearFaces, count: int) -> void:
	for i in 200:
		if near.arrived_count >= count and near.loading_count() == 0:
			return
		near.update(0.01)
		OS.delay_msec(5)


func _test_credits() -> void:
	var text := Credits.text()
	_check(Credits.DISCLAIMER in text, "credits carry the Fan Content disclaimer")
	_check("Scryfall" in text and "Test Set art by Amy Artist, Zed Painter." in text, "real-data credits name Scryfall and the artists")
	_check(Credits.artists() == PackedStringArray(["Amy Artist", "Zed Painter"]), "the roll names each artist once: %s" % [Credits.artists()])
	var kinds := Credits.roll().map(func(block: Array) -> String: return block[0])
	_check(kinds[0] == "title" and kinds.back() == "end" and "names" in kinds, "the roll runs from the title to the closing line, with the artists in columns")
	CardDatabase.get_set(CardDatabase.sets_in_shelf_order()[0].code).artists.append("amy artist")
	CardDatabase.get_set(CardDatabase.sets_in_shelf_order()[0].code).artists.append("Amy Artist")
	_check(Credits.artists() == PackedStringArray(["Amy Artist", "amy artist", "Zed Painter"]) or Credits.artists() == PackedStringArray(["amy artist", "Amy Artist", "Zed Painter"]),
		"artists repeated across sets are named once, sorted ignoring case: %s" % [Credits.artists()])
	CardDatabase.load_file(CardDatabase.PLACEHOLDER_PATH)
	_check(Credits.DISCLAIMER in Credits.text() and not "Scryfall" in Credits.text(), "placeholder credits still carry the disclaimer")
	var names := PackedStringArray()
	for i in 200:
		names.append("Artist %03d" % i)
	var roll := CreditsRoll.new()
	roll._add_block("names", names)
	var blocks := roll._strip.get_children().filter(func(child: Node) -> bool: return child is HBoxContainer)
	_check(blocks.size() == 3 and blocks[0].get_child_count() == CreditsRoll.NAME_COLUMNS, "a long artist list is cut into blocks of columns")
	_check(blocks[0].get_child(1).text.begins_with("Artist 001\nArtist 004"), "names read left to right, then down")
	roll.free()


func _test_inspect_tilt() -> void:
	var limit := deg_to_rad(15.0)
	var tilt := Hands.inspect_tilt(Vector2.ZERO, Vector2(40, -20), 0.0025, limit)
	_check(is_equal_approx(tilt.y, 0.1) and is_equal_approx(tilt.x, -0.05), "tilt should follow the mouse 1:1: %s" % tilt)
	tilt = Hands.inspect_tilt(tilt, Vector2(10000, 10000), 0.0025, limit)
	_check(is_equal_approx(tilt.x, limit) and is_equal_approx(tilt.y, limit), "tilt should clamp to the limit: %s" % tilt)
	tilt = Hands.inspect_tilt(tilt, Vector2(-40, 0), 0.0025, limit)
	_check(is_equal_approx(tilt.y, limit - 0.1), "moving back from the limit should tilt back at once: %s" % tilt)
	# Up close, the card fills the same share of the screen at any field of view.
	var near := 0.02 # the player camera's near plane
	for fov in [60.0, 75.0, 100.0]:
		var distance := Hands.zoomed_distance(fov, 0.088)
		var fill := 0.088 / (2.0 * distance * tan(deg_to_rad(fov) / 2.0))
		_check(is_equal_approx(fill, Hands.ZOOMED_SCREEN_FILL), "card up close should fill %s of the height at fov %s: %s" % [Hands.ZOOMED_SCREEN_FILL, fov, fill])
		var tilted_corner := distance - 0.044 * sin(limit)
		_check(tilted_corner > near, "a tilted card up close should clear the near plane at fov %s: %s" % [fov, tilted_corner])


## R turns the card up close over and T sideways; lowering it undoes both.
func _test_turn_over() -> void:
	var face_up := Hands.held_basis(Vector3.ZERO, 0.0)
	var back := Hands.held_basis(Vector3.ZERO, 1.0)
	_check(face_up.z.is_equal_approx(Vector3.BACK) and back.z.is_equal_approx(Vector3.FORWARD), "turned over, the face points away: %s" % back.z)
	_check(back.y.is_equal_approx(Vector3.UP), "turning over keeps the card upright: %s" % back.y)
	var tipped := Vector3(0.2, 0.0, 0.0)
	_check(signf(Hands.held_basis(tipped, 1.0).y.z) == signf(Hands.held_basis(tipped, 0.0).y.z), "the mouse tips the top the same way on either side")
	# Sideways, the card's top edge points right: a clockwise quarter turn,
	# on either side.
	_check(Hands.held_basis(Vector3.ZERO, 0.0, 1.0).y.is_equal_approx(Vector3.RIGHT), "T turns the card clockwise")
	_check(Hands.held_basis(Vector3.ZERO, 1.0, 1.0).y.is_equal_approx(Vector3.RIGHT), "T turns the back clockwise too")

	Saves.begin_new_game()
	var main: Node3D = load(SceneFlow.SHOP_SCENE).instantiate()
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_old_start(main)
	var pile: PileWorld = main.get_node("Pile")
	var hands: Hands = main.get_node("Player/Hands")
	var id := _first_binder_cards()[0]
	pile.pick_up(id)
	hands.restore_hand([id] as Array[int])
	hands._set_zoomed(true)
	await get_tree().create_timer(hands.zoom_seconds + 0.1).timeout
	hands.turn_over(true)
	hands.turn_sideways(true)
	await get_tree().create_timer(hands.turn_over_seconds + 0.1).timeout
	_check(hands._sideways and is_equal_approx(hands._sideways_amount, 1.0), "T turns the card up close sideways")
	_check(hands._held_view.basis.y.x > 0.9, "its top edge points right: %s" % hands._held_view.basis.y)
	_check(hands._turned_over and is_equal_approx(hands._turn_amount, 1.0), "R turns the card up close over")
	_check(hands._held_view.basis.z.z < -0.9, "its back faces you: %s" % hands._held_view.basis.z)
	hands._set_zoomed(false)
	await get_tree().create_timer(hands.zoom_seconds + 0.1).timeout
	_check(not hands._turned_over and is_zero_approx(hands._turn_amount), "lowering the card turns it face up again")
	_check(not hands._sideways and is_zero_approx(hands._sideways_amount), "lowering the card turns it upright again")
	_check(hands._held_view.basis.z.z > 0.5, "the lowered card faces you: %s" % hands._held_view.basis.z)
	hands._set_zoomed(true)
	hands.turn_over(true, 0.0)
	hands.turn_sideways(true, 0.0)
	hands._release_top()
	_check(not hands._turned_over and is_zero_approx(hands._turn_amount) and not hands._sideways and is_zero_approx(hands._sideways_amount),
		"a card leaving the hand clears both turns")

	# Empty-handed, F on a card in an open binder brings it up close; F again
	# sends it home. It never leaves its pocket.
	var binder := pile.binders[0]
	binder.place(pile, Transform3D(Basis(), Vector3(2.0, 0.2, 2.0)), 0)
	var pocketed := _first_binder_cards()[1]
	pile.pick_up(pocketed)
	binder.insert(1, pocketed)
	hands._aim = Hands.Aim.BINDER
	hands._aim_binder = binder
	hands._aim_pocket = 0
	_check(not hands.view_aimed(), "an empty pocket has nothing to look at")
	hands._aim_pocket = 1
	_check(hands.view_aimed() and hands._viewed_id == pocketed and hands.shown_card_id() == pocketed, "F brings a pocketed card up close")
	_check(not binder._pocket_view(1).visible, "its pocket shows empty meanwhile")
	await _finish_glide(hands)
	_check(hands._held_view.basis.z.z > 0.9 and hands._held_view.position.is_equal_approx(Vector3(0, 0, -Hands.zoomed_distance(hands._camera.fov, PileWorld.CARD_SIZE.y))),
		"it's up close, square to you: %s" % hands._held_view.position)
	hands.turn_over(true, 0.0)
	hands.turn_sideways(true, 0.0)
	_check(hands._held_view.basis.z.z < -0.9, "R works on it too")
	hands._end_viewing()
	await _finish_glide(hands)
	_check(hands._viewed_id < 0 and not hands._held_view.visible and binder._pocket_view(1).visible, "F again puts it back in its pocket: %s %s %s" % [hands._viewed_id, hands._held_view.visible, binder._pocket_view(1).visible])
	_check(binder.contents.card_at(1) == pocketed and binder.contents.is_locked(1), "still locked in")
	_check(is_zero_approx(hands._turn_amount) and is_zero_approx(hands._sideways_amount), "face up and upright again")

	# The same for a rare card in its shadow box, aimed at through the glass.
	var cabinet: DisplayCabinet = main.get_node("Store").cabinets[0]
	var rare := CardDatabase.rare_cards()[0]
	pile.pick_up(rare.id)
	cabinet.display(rare.id, false)
	var box := cabinet.slot_pose(0)
	_check(cabinet.slot_on_ray(box.origin + box.basis.z * 1.0, box.origin - box.basis.z * 0.1) == 0, "a ray into a shadow box finds it")
	_check(cabinet.slot_on_ray(box.origin + box.basis.z * 1.0 + box.basis.x * 0.5, box.origin - box.basis.z * 0.1 + box.basis.x * 0.5) != 0, "and not from beside it")
	hands._aim = Hands.Aim.CABINET
	hands._aim_cabinet = cabinet
	hands._aim_slot = 1
	_check(not hands.view_aimed(), "an empty shadow box has nothing to look at")
	hands._aim_slot = 0
	_check(hands.view_aimed() and hands._viewed_id == rare.id and not cabinet._views[0].visible, "F brings a displayed rare card up close")
	await _finish_glide(hands)
	hands._end_viewing()
	await _finish_glide(hands)
	_check(hands._viewed_id < 0 and cabinet._views[0].visible and cabinet.displayed[0] == rare.id, "and back into its box")
	main.free()


func _test_glide() -> void:
	var up := Glide.flat_card(Vector3.ZERO, Basis.IDENTITY)
	_check(up.basis.z.is_equal_approx(Vector3.UP), "a face-up card's face should point up: %s" % up.basis.z)
	_check(up.basis.y.is_equal_approx(Vector3.FORWARD), "a flat card's top edge should point along -z: %s" % up.basis.y)
	var down := Glide.flat_card(Vector3.ZERO, Basis.IDENTITY, false)
	_check(down.basis.z.is_equal_approx(Vector3.DOWN), "a face-down card's face should point down: %s" % down.basis.z)
	_check(down.basis.y.is_equal_approx(Vector3.FORWARD), "a face-down card's top edge should still point along -z: %s" % down.basis.y)
	var from := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var to := Transform3D(Basis.IDENTITY, Vector3(1, 0, 0))
	_check(Glide.pose(from, to, 0.5, 0.1).origin.is_equal_approx(Vector3(0.5, 0.1, 0)), "a put-down should arc up by its lift at the midpoint")
	_check(Glide.pose(from, to, 1.0, 0.1).origin.is_equal_approx(to.origin), "a glide should end exactly at its target")


func _test_controls() -> void:
	Controls.reset_all()
	for entry in Controls.ACTIONS:
		_check(not Controls.events(entry[0]).is_empty(), "%s has a default binding" % entry[0])
	_check(Controls.label(Controls.INTERACT) == "E", "interact shows as E, got " + Controls.label(Controls.INTERACT))
	_check(Controls.label(Controls.FLIP_CARD) == "R", "turning a card over shows as R, got " + Controls.label(Controls.FLIP_CARD))
	_check(Controls.label(Controls.TURN_SIDEWAYS) == "T", "turning a card sideways shows as T, got " + Controls.label(Controls.TURN_SIDEWAYS))
	_check(Controls.label(Controls.USE_HAND) == "click", "use hand shows as click")
	_check(Controls.pair_label(Controls.FLIP_NEXT, Controls.FLIP_PREVIOUS) == "scroll", "page turning shows as scroll")

	var g := InputEventKey.new()
	g.physical_keycode = KEY_G
	Controls.rebind(Controls.INTERACT, g)
	_check(Controls.label(Controls.INTERACT) == "G", "a rebind changes the hint, got " + Controls.label(Controls.INTERACT))
	var press := InputEventKey.new()
	press.physical_keycode = KEY_G
	press.pressed = true
	_check(press.is_action_pressed(Controls.INTERACT), "the rebound key triggers the action")
	_check(Controls.actions_using(g) == [Controls.INTERACT], "actions_using finds the rebind")

	var path := "user://test_controls.cfg"
	Controls.save(path)
	Controls.reset_all()
	_check(Controls.label(Controls.INTERACT) == "E", "reset_all restores defaults")
	Controls.load_rebinds(path)
	_check(Controls.label(Controls.INTERACT) == "G", "rebinds survive a save and load")
	_check(Controls.label(Controls.INSPECT) == "F", "unchanged actions keep their defaults after a load")
	Controls.reset(Controls.INTERACT)
	_check(Controls.label(Controls.INTERACT) == "E", "reset puts one action back")
	DirAccess.remove_absolute(path)


func _test_settings() -> void:
	Settings.reset_all()
	_check(Settings.value("mouse_sensitivity") == 1.0 and is_equal_approx(Settings.look_sensitivity(), 0.0025),
		"mouse look defaults to its old speed")
	_check(Settings.value("field_of_view") == 75.0 and not Settings.value("crouch_toggle") and not Settings.value("invert_y"),
		"field of view, crouch and look default to what the game did before Settings")
	_check(Settings.value("quality") == 2 and Settings.matching_quality() == 2, "quality defaults to High")
	for key in Settings.DEFAULTS:
		var tabs := Settings.TABS.values().filter(func(keys: Array) -> bool: return key in keys)
		_check(tabs.size() == 1, "%s belongs to exactly one tab" % key)

	var effects := AudioServer.get_bus_index(Settings.EFFECTS_BUS)
	_check(effects > 0 and AudioServer.get_bus_index(Settings.AMBIENCE_BUS) > 0 and AudioServer.get_bus_index(Settings.MUSIC_BUS) > 0,
		"the Effects, Ambience and Music buses exist")
	Settings.change("effects_volume", 0.5)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(effects), linear_to_db(0.25)), "half volume is a quarter of the power")
	Settings.change("effects_volume", 0.0)
	_check(AudioServer.is_bus_mute(effects), "0% mutes the bus")
	_check(FeedbackSounds.stream(FeedbackSounds.Kind.CARD_LOCKED) != null, "feedback sounds still build")
	_check(AudioServer.get_bus_effect_count(effects) == 1 and AudioServer.get_bus_effect(effects, 0) is AudioEffectHardLimiter,
		"the Effects bus ends in a limiter, so a burst of sounds can't clip")
	FeedbackSounds.reset()
	var card := FeedbackSounds.Kind.CARD_LOCKED
	var burst: Array = []
	for i in 12:
		burst.append(FeedbackSounds.schedule(100.0, card))
	_check(burst.all(func(slot: Array) -> bool: return slot[0] >= 0.0), "no chime is scheduled in the past")
	var spaced := true
	var climbing := true
	for i in range(1, burst.size()):
		spaced = spaced and is_equal_approx(burst[i][0] - burst[i - 1][0], FeedbackSounds.SPACING)
		climbing = climbing and burst[i][1] >= burst[i - 1][1]
	_check(spaced, "chimes asked for on the same frame start one SPACING apart, not all at once")
	_check(climbing and burst[1][1] > burst[0][1], "a run of card chimes climbs the scale")
	_check(is_equal_approx(burst[0][1], pow(2.0, FeedbackSounds.RUN_SCALE[0] / 12.0))
		and is_equal_approx(burst[11][1], pow(2.0, FeedbackSounds.RUN_SCALE[-1] / 12.0)),
		"the run starts at the bottom of the scale and stays on its top step")
	var big: Array = FeedbackSounds.schedule(100.0, FeedbackSounds.Kind.PAGE_COMPLETE)
	_check(big[1] == 1.0 and big[0] > burst[11][0], "a page chime waits its turn at its own pitch")
	var later: float = 100.0 + big[0] + FeedbackSounds.RUN_RESET + 0.5
	var fresh: Array = FeedbackSounds.schedule(later, card)
	_check(fresh[0] == 0.0 and is_equal_approx(fresh[1], burst[0][1]), "after a pause the next chime plays at once, back at the bottom")
	var next: Array = FeedbackSounds.schedule(later + 0.5, card)
	_check(next[0] == 0.0 and next[1] > fresh[1], "unhurried filing keeps climbing within the run")
	FeedbackSounds.reset()

	Settings.change("quality", 0)
	_check(Settings.value("render_scale") == 2 and Settings.value("shadows") == 0 and Settings.value("anti_aliasing") == 0
		and Settings.value("card_detail") == Settings.CARD_DETAIL_LOW, "Low sets the four quality rows")
	_check(is_equal_approx(get_tree().root.scaling_3d_scale, 0.75), "render scale applies to the window")
	Settings.change("anti_aliasing", 3)
	_check(Settings.value("quality") == Settings.CUSTOM_QUALITY and get_tree().root.msaa_3d == Viewport.MSAA_4X,
		"changing a quality row by hand makes it Custom")
	Settings.change("quality", 2)
	_check(Settings.matching_quality() == 2 and get_tree().root.msaa_3d == Viewport.MSAA_2X, "picking High again sets it back")

	Settings.change("day_length", 4)
	Settings.change("stopped_at", 3)
	_check(Settings.day_seconds() == 0.0 and Settings.stopped_hour() == 0.0, "Stopped at Night stops the clock at midnight")
	var day := DayCycle.new()
	add_child(day)
	day.setup(Environment.new(), [] as Array[Light3D], null, null)
	_check(day.hour == 0.0, "a stopped day starts at its hour")
	day._process(60.0)
	_check(day.hour == 0.0, "a stopped clock doesn't move")
	Settings.change("stopped_at", 1)
	_check(day.hour == 12.0, "changing Stopped at moves the clock there")
	Settings.change("day_length", 2)
	day._process(75.0)
	_check(is_equal_approx(day.hour, 13.0), "30-minute days run half as fast, from where the clock stood")
	day.free()

	Settings.change("mouse_sensitivity", 1.5)
	Settings.change("interface_size", 1.25)
	Settings.save()
	Settings.reset_all()
	_check(Settings.value("mouse_sensitivity") == 1.0, "reset_all restores defaults")
	Settings.load_settings()
	_check(Settings.value("mouse_sensitivity") == 1.5 and Settings.value("interface_size") == 1.25 and Settings.value("day_length") == 2,
		"settings survive a save and load")
	_check(is_equal_approx(get_tree().root.content_scale_factor, 1.25), "interface size scales the UI")
	Settings.reset_tab("Controls")
	_check(Settings.value("mouse_sensitivity") == 1.0 and Settings.value("interface_size") == 1.25, "Reset puts back only its own tab")

	var broken := ConfigFile.new()
	broken.set_value("settings", "field_of_view", "wide")
	broken.set_value("settings", "brightness", 1)
	broken.set_value("settings", "not_a_setting", 3)
	broken.save(SETTINGS_TEST_PATH)
	Settings.load_settings()
	_check(Settings.value("field_of_view") == 75.0 and Settings.value("brightness") == 1.0 and Settings.value("brightness") is float,
		"a bad saved value keeps its default, and whole numbers load as decimals")
	Settings.reset_all()


func _test_settings_screen() -> void:
	Settings.reset_all()
	Progression.reset()
	var screen := SettingsScreen.new()
	add_child(screen)
	_check(screen.tab_buttons.keys() == ["Audio", "Controls", "Gameplay", "Graphics"], "four tabs, in order")
	_check(screen.open_tab == "Audio" and screen.pages["Audio"].visible and not screen.pages["Graphics"].visible, "it opens on Audio")
	var all_buttons: Array = screen.tab_buttons.values() + [screen.reset_button]
	_check(all_buttons.all(func(button: Button) -> bool: return button.focus_mode == Control.FOCUS_NONE)
		and screen.controls.values().all(func(control: Control) -> bool: return control.focus_mode == Control.FOCUS_NONE),
		"the settings page is mouse-only")
	for tab in Settings.TABS:
		for key in Settings.TABS[tab]:
			_check(screen.controls.has(key) and screen.pages[tab].is_ancestor_of(screen.controls[key]), "%s has a row on %s" % [key, tab])
	var slider: HSlider = screen.controls["master_volume"]
	_check(not slider.scrollable, "the wheel scrolls the page, not a slider")
	slider.value = 0.5
	_check(Settings.value("master_volume") == 0.5, "dragging a slider changes its setting")
	_check(slider.get_parent().get_child(2).text == "50%", "the slider shows its value")
	var crouch: OptionButton = screen.controls["crouch_toggle"]
	crouch.item_selected.emit(1)
	_check(Settings.value("crouch_toggle") == true, "a two-way dropdown sets a true/false setting")
	var stopped: OptionButton = screen.controls["stopped_at"]
	_check(stopped.disabled, "Stopped at is greyed out while the clock runs")
	(screen.controls["day_length"] as OptionButton).item_selected.emit(4)
	_check(not stopped.disabled, "Stopped at opens up when the clock is stopped")
	_check((screen.controls["frame_limit"] as OptionButton).disabled, "the frame limit is greyed out with vsync on")
	(screen.controls["shadows"] as OptionButton).item_selected.emit(0)
	_check((screen.controls["quality"] as OptionButton).selected == Settings.CUSTOM_QUALITY, "the Quality dropdown follows to Custom")

	_check(screen.key_labels["Walk"].text == "WASD", "Walk shows as WASD, got " + screen.key_labels["Walk"].text)
	_check(screen.key_labels["Crouch"].text == "Ctrl", "Crouch shows as Ctrl, got " + screen.key_labels["Crouch"].text)
	_check(screen.key_labels["Turn pages"].text == "Scroll" and screen.key_labels["Pick up, put down, file, shelve"].text == "Click",
		"the wheel and the mouse buttons read as words")
	_check(screen.key_labels.has("Sorcery 1") and not screen.key_labels.has("Tithe") and screen.key_labels["Sorcery 1"].text == "1",
		"an unlearned sorcery is listed without its name")
	Progression.earn(200)
	for step in 3:
		Progression.buy(0, step)
	_check(SettingsScreen.sorcery_name(0) == "Tithe" and SettingsScreen.sorcery_name(1) == "Sorcery 2", "a learned sorcery shows its name")
	Progression.reset()

	screen.tab_buttons["Controls"].pressed.emit()
	_check(screen.open_tab == "Controls" and screen.reset_button.text == "Reset Controls", "a tab opens its page and names its Reset")
	_check(screen.tab_buttons.keys().filter(func(tab: String) -> bool: return screen.tab_buttons[tab].button_pressed) == ["Controls"],
		"only the open tab is lit")
	(screen.controls["mouse_sensitivity"] as HSlider).value = 2.0
	screen.reset_button.pressed.emit()
	var question := screen.get_node("ResetQuestion")
	_check(question != null and Settings.value("mouse_sensitivity") == 2.0, "Reset asks first")
	question.buttons["Reset"].pressed.emit()
	_check(Settings.value("mouse_sensitivity") == 1.0 and not Settings.value("crouch_toggle") and Settings.value("master_volume") == 0.5,
		"Reset Controls resets only the Controls tab")
	_check(is_equal_approx((screen.controls["mouse_sensitivity"] as HSlider).value, 1.0), "the page redraws after a reset")
	screen.close()
	var saved := ConfigFile.new()
	_check(saved.load(SETTINGS_TEST_PATH) == OK and saved.get_value("settings", "master_volume", 1.0) == 0.5, "closing the page saves")
	var again := SettingsScreen.new()
	add_child(again)
	_check(again.open_tab == "Controls", "the page reopens on the last tab used")
	again.free()
	Settings.reset_all()


func _test_onscreen_text() -> void:
	var khans := SetData.new()
	khans.code = "KTK"
	khans.card_count = 269
	_check(khans.number_text(4) == "004" and khans.number_text(269) == "269", "collector numbers are zero-padded to three digits")
	khans.card_count = 1200
	_check(khans.number_text(4) == "0004", "a set past 999 pads to four digits")

	var range_data := CardDatabase.all_binders()[0]
	var set_data := CardDatabase.get_set(range_data.set_code)
	var main := preload("res://scripts/main.gd")
	var ids := _first_binder_cards()
	var card := CardDatabase.get_card(ids[3])
	_check(main.card_details(card) == "%s\n%s\n%s #004/%s\n%s · %s" % [card.name, set_data.name, set_data.code,
		set_data.number_text(set_data.card_count), CardData.Rarity.keys()[card.rarity].capitalize(),
		Progression.money_text(Prices.sale_cents(card))],
		"held card details: name, set, padded number of total, rarity; got " + main.card_details(card))

	var binder := Binder.new()
	binder.setup(range_data, Color.RED, null)
	var other := Binder.new()
	other.setup(CardDatabase.all_binders()[1], Color.BLUE, null)
	binder.contents.insert(0, ids[0])
	binder.contents.insert(1, ids[2]) # The wrong card: doesn't count.
	other.contents.insert(0, _card_for(CardDatabase.all_binders()[1], 0))
	var binders: Array[Binder] = [binder, other]
	_check(main.cards_organized(binders) == 2, "Cards Organized counts locked cards across every binder")

	var hands := Hands.new()
	var capacity := binder.contents.capacity()
	var filled := "Cards Filled: 1/%d (%d%%)" % [capacity, floori(100.0 / capacity)]
	_check(hands._binder_hint(binder) == filled + "\nE: Open Binder", "closed binder hint, got " + hands._binder_hint(binder))
	binder.state = Binder.State.OPEN
	binder.spread = 1
	var pages := BinderLayout.page_count(range_data)
	_check(hands._binder_hint(binder) == "%s\nPages 2–3 of %d\nE: Close Binder" % [filled, pages],
		"open binder hint, got " + hands._binder_hint(binder))
	binder.spread = 0
	_check(hands._binder_hint(binder).contains("\nPage 1 of %d\n" % pages), "the first spread shows one page")
	hands._aim_pocket = 2
	_check(hands._binder_hint(binder) == "%s #003: ???\n%s\nPage 1 of %d\nE: Close Binder" % [set_data.code, filled, pages],
		"the pocket line sits on top, above the binder's lines; got " + hands._binder_hint(binder))
	hands._aim_pocket = -1
	_check(hands._pocket_hint(binder, 0) == "%s #001\n%s" % [set_data.code, CardDatabase.get_card(ids[0]).name],
		"a locked pocket names its card")
	_check(hands._pocket_hint(binder, 1) == set_data.code + " #002: ???", "a pocket with the wrong card stays a mystery")
	_check(hands._pocket_hint(binder, 2) == set_data.code + " #003: ???", "an empty pocket is a mystery")
	hands.free()
	binder.free()
	other.free()


func _card_for(range_data: BinderRange, pocket: int) -> int:
	for card in CardDatabase.cards_in_set(range_data.set_code):
		if card.collector_number == range_data.first + pocket:
			return card.id
	return -1


func _test_pause() -> void:
	var menu := PauseMenu.new()
	add_child(menu)
	_check(not menu.is_paused() and not get_tree().paused, "the game starts unpaused")
	var esc := InputEventAction.new()
	esc.action = Controls.PAUSE
	esc.pressed = true
	menu._unhandled_input(esc)
	_check(menu.is_paused() and menu.visible and get_tree().paused, "Esc pauses and shows the pause screen")
	_check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "pausing frees the mouse")
	menu._unhandled_input(esc)
	_check(not menu.is_paused() and not get_tree().paused, "Esc again goes back in")
	menu.pause()
	_check(menu.buttons.keys() == ["Resume", "Save/Load", "Achievements", "Settings", "Exit Game"],
		"the pause menu's buttons, in order: %s" % [menu.buttons.keys()])
	_check(not menu.buttons["Save/Load"].disabled, "Save/Load is on the pause menu")
	menu.buttons["Save/Load"].pressed.emit()
	var slots_pages := menu.find_children("*", "SaveSlotsScreen", false, false)
	_check(slots_pages.size() == 1 and slots_pages[0].rows.size() == Saves.SLOTS.size()
		and not slots_pages[0].rows[Saves.AUTOSAVE].save.visible and slots_pages[0].rows["slot1"].save.visible,
		"Save/Load lists the autosave and three slots, with Save on the slots only")
	for found in slots_pages:
		found.free()
	var all_buttons: Array = menu.buttons.values() + menu.exit_buttons.values() + menu.save_buttons.values()
	_check(all_buttons.all(func(button: Button) -> bool: return button.focus_mode == Control.FOCUS_NONE),
		"the pause menu is mouse-only: no button takes keyboard focus")
	menu.buttons["Resume"].pressed.emit()
	_check(not menu.is_paused() and not get_tree().paused, "Resume goes back in")
	menu.pause()
	for page in ["Achievements", "Settings"]:
		menu.buttons[page].pressed.emit()
		var screens := menu.find_children("*", "MenuScreen", false, false)
		_check(screens.size() == 1 and screens[0].name == page, "%s opens its page from the pause menu" % page)
		if screens.is_empty():
			continue
		screens[0]._unhandled_input(esc)
		_check(screens[0].is_queued_for_deletion() and menu.is_paused() and get_tree().paused,
			"Esc closes the %s page and the game stays paused" % page)
		screens[0].free()
	menu.buttons["Exit Game"].pressed.emit()
	_check(menu.is_asking_to_exit() and menu.exit_buttons.keys() == ["Quit to Menu", "Quit to Desktop", "Back"],
		"Exit Game offers Quit to Menu, Quit to Desktop or Back")
	var shown := menu.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree())
	_check(shown.is_empty(), "with no text above the buttons")
	menu.exit_buttons["Back"].pressed.emit()
	_check(not menu.is_asking_to_exit() and menu.is_paused(), "Back returns to the pause menu")
	var saves := [0]
	var count_save := func() -> void: saves[0] += 1
	SceneFlow.saving.connect(count_save)
	for quit in ["Quit to Menu", "Quit to Desktop"]:
		for answer in ["Save And Quit", "Quit Without Saving"]:
			menu.buttons["Exit Game"].pressed.emit()
			menu.exit_buttons[quit].pressed.emit()
			var questions := menu.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.is_visible_in_tree())
			_check(menu.is_asking_to_save() and not menu.is_asking_to_exit() and questions.size() == 1 and questions[0].text == "Save before quitting?"
				and menu.save_buttons.keys() == ["Save And Quit", "Quit Without Saving"], "%s asks: Save before quitting?" % quit)
			_check(menu._quit_to == (SceneFlow.to_main_menu if quit == "Quit to Menu" else SceneFlow.quit), "%s heads for the right place" % quit)
			var went := [false]
			menu._quit_to = func() -> void: went[0] = true
			saves[0] = 0
			menu.save_buttons[answer].pressed.emit()
			_check(went[0] and saves[0] == (1 if answer == "Save And Quit" else 0),
				"%s, %s: %s" % [quit, answer, "saves, then quits" if answer == "Save And Quit" else "quits without saving"])
			menu._show_menu()
	SceneFlow.saving.disconnect(count_save)
	menu.buttons["Exit Game"].pressed.emit()
	menu.exit_buttons["Quit to Desktop"].pressed.emit()
	menu._unhandled_input(esc)
	_check(menu.is_asking_to_exit() and not menu.is_asking_to_save(), "Esc steps back from the save question to the exit question")
	menu._unhandled_input(esc)
	_check(not menu.is_asking_to_exit() and menu.is_paused(), "Esc again goes back to the pause menu, without resuming")
	menu._unhandled_input(esc)
	_check(not menu.is_paused() and not get_tree().paused, "and Esc again resumes")
	_check(not SceneFlow.take_menu_request(), "nothing asks the title to skip to its menu by default")
	SceneFlow._menu_requested = true
	_check(SceneFlow.take_menu_request() and not SceneFlow.take_menu_request(), "the way back to the menu is taken once")
	var environment := Environment.new()
	var day := DayCycle.new()
	day.setup(environment, [] as Array[Light3D], null, null)
	menu.day_cycle = day
	var by_text := {}
	for found: Button in menu.find_children("*", "Button", true, false):
		by_text[found.text] = found
	_check(by_text.has("Set Noon") == OS.is_debug_build() and by_text.has("Set Midnight") == OS.is_debug_build(), "time-of-day buttons appear only in developer builds")
	if OS.is_debug_build():
		menu.pause()
		by_text["Set Midnight"].pressed.emit()
		_check(day.hour == 0.0 and is_equal_approx(environment.ambient_light_energy, DayCycle.NIGHT_AMBIENT_ENERGY), "Set Midnight jumps to midnight while paused")
		by_text["Set Noon"].pressed.emit()
		_check(day.hour == 12.0 and environment.ambient_light_energy > DayCycle.NIGHT_AMBIENT_ENERGY, "Set Noon jumps to noon")
		menu.resume()
	day.free()
	menu.free()


func _test_title_screen() -> void:
	_check(SceneFlow.should_skip_title(PackedStringArray(["--benchmark"])), "the benchmark skips the title")
	_check(SceneFlow.should_skip_title(PackedStringArray(["--skip-title"])) == OS.is_debug_build(), "--skip-title skips it in developer builds only")
	_check(not SceneFlow.should_skip_title(PackedStringArray()), "a normal launch shows the title")
	var profile := "user://test_profile.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile))
	SceneFlow.load_profile(profile)
	var title: Control = load(SceneFlow.TITLE_SCENE).instantiate()
	add_child(title)
	var labels := title.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	_check("PICKUP" in labels and "PRESS ANY KEY TO START" in labels,
		"the title shows the name and PRESS ANY KEY TO START")
	_check(not labels.any(func(t: String) -> bool: return "Wizards" in t or "Fan Content" in t),
		"and nothing that gives away what the game is")
	_check(title.buttons["Credits"].disabled,
		"Credits is greyed out until a game has been started")
	var pages := SceneFlow.intro_pages()
	_check(pages.size() == SceneFlow.PROLOGUE.size() + 1 and pages[-1] == Credits.DISCLAIMER,
		"New Game's intro plays the prologue, then the disclaimer")
	var legacy := ConfigFile.new()
	legacy.set_value("game", "started", true)
	legacy.save(profile)
	SceneFlow.load_profile(profile)
	_check(SceneFlow.has_started(), "a game started before saves existed still counts as started")
	title.free()
	title = load(SceneFlow.TITLE_SCENE).instantiate()
	add_child(title)
	_check(not title.buttons["Credits"].disabled, "after that, Credits is on the menu")
	_check(title.buttons.keys() == ["Continue", "New Game", "Load Game", "Achievements", "Settings", "Credits", "Exit"],
		"the main menu's buttons, in order: %s" % [title.buttons.keys()])
	for label in ["Continue", "Load Game"]:
		_check(title.buttons[label].disabled, "%s is greyed out until there are saves" % label)
	_check(not title.buttons["New Game"].is_visible_in_tree(), "the menu is hidden behind the title at first")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(30, 10)
	_check(not title.is_start_press(motion), "moving the mouse doesn't leave the title")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	_check(not title.is_start_press(release), "nor does letting go of a mouse button")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	_check(title.is_start_press(key), "any key leaves the title")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	_check(title.is_start_press(click), "and so does any mouse button")
	title._input(motion)
	_check(title.state == title.State.TITLE, "the title waits through mouse movement")
	title._input(key)
	_check(title.state == title.State.MENU and title.buttons["New Game"].is_visible_in_tree(), "a key press brings up the menu")
	var focusable: Array = title.buttons.values().filter(func(button: Button) -> bool: return button.focus_mode != Control.FOCUS_NONE)
	_check(focusable.is_empty() and title.get_viewport().gui_get_focus_owner() == null,
		"the menu is mouse-only: no button takes keyboard focus")
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	_check(title.get_viewport().gui_get_focus_owner() == null, "and the arrow keys highlight nothing")
	for page in ["Achievements", "Settings", "Credits"]:
		title.buttons[page].pressed.emit()
		var screens := title.find_children("*", "CreditsRoll" if page == "Credits" else "MenuScreen", false, false)
		_check(screens.size() == 1 and (page == "Credits" or screens[0].name == page), "%s opens its page" % page)
		if screens.is_empty():
			continue
		if page == "Credits":
			var text := screens[0].find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
			_check(text.any(func(t: String) -> bool: return Credits.DISCLAIMER in t), "Credits rolls the credits")
		var esc := InputEventAction.new()
		esc.action = Controls.PAUSE
		esc.pressed = true
		screens[0]._unhandled_input(esc)
		_check(screens[0].is_queued_for_deletion(), "Esc closes the %s page" % page)
		screens[0].free()
	title.free()
	SceneFlow._menu_requested = true
	title = load(SceneFlow.TITLE_SCENE).instantiate()
	add_child(title)
	_check(title.state == title.State.MENU and title.buttons["New Game"].is_visible_in_tree(),
		"coming back from the shop, the title opens straight on its menu")
	title.free()
	get_viewport().gui_release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile))
	SceneFlow.load_profile(SceneFlow.PROFILE_PATH)


func _test_achievements() -> void:
	var path := "user://test_achievements.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Achievements.load_from(path)
	var nodes := {}
	for colour in Progression.COLOURS.size():
		for step in Progression.COLOURS[colour].steps:
			nodes[step[0]] = colour
	_check(Achievements.count() == nodes.size() + RareCards.count() + 1 + WallArt.count(),
		"one achievement per card the upgrade tree is named after, per rare card, one for all rare cards, and one per wall art frame: %d" % Achievements.count())
	var matches := true
	for index in nodes.size():
		matches = matches and nodes.get(Achievements.card_name(index), -1) == Achievements.colour(index)
	_check(matches, "each achievement sits in its card's colour")
	var tithe := Achievements.index_of("Tithe")
	_check(not Achievements.is_unlocked(tithe) and Achievements.title(tithe) == "???" and Achievements.description(tithe) == "This achievement is locked.",
		"a locked achievement shows ??? and This achievement is locked.")
	_check(Achievements.icon(tithe).resource_path.ends_with("achievement%03d_locked.png" % (tithe + 1)), "and its locked icon")
	for index in Achievements.count():
		for unlocked in [true, false]:
			matches = matches and Achievements.icon_path(index + 1, unlocked) == Achievements.ICON_PATH % [index + 1, "" if unlocked else "_locked"]
	_check(matches, "every achievement has both placeholder icons")
	_check(Achievements.icon_path(999, true).ends_with("achievement001.png") and Achievements.icon_path(999, false).ends_with("achievement001_locked.png"),
		"a missing icon falls back to 001's")
	var heard: Array[int] = []
	var listen := func(index: int) -> void: heard.append(index)
	Achievements.unlocked.connect(listen)
	var card := CardDatabase.get_card(0)
	Achievements.card_filed(card)
	_check(heard.is_empty(), "filing a card no upgrade is named after unlocks nothing")
	var real_name := card.name
	card.name = "Tithe"
	Achievements.card_filed(card)
	Achievements.card_filed(card)
	card.name = real_name
	var set_name := CardDatabase.get_set(card.set_code).name
	_check(heard == [tithe], "filing Tithe unlocks its achievement, once")
	_check(Achievements.is_unlocked(tithe) and Achievements.title(tithe) == "Tithe" and Achievements.description(tithe) == "Filed Tithe from %s." % set_name,
		"an unlocked achievement shows its name and what it was for: " + Achievements.description(tithe))
	_check(Achievements.icon(tithe).resource_path.ends_with("achievement%03d.png" % (tithe + 1)), "and its full icon")
	var screen := AchievementsScreen.make()
	add_child(screen)
	var tiles := screen.find_children("Achievement*", "VBoxContainer", true, false)
	_check(tiles.size() == Achievements.count(), "the Achievements page has a tile for each")
	var tile: Node = screen.find_child("Achievement%03d" % (tithe + 1), true, false)
	var locked_tile: Node = screen.find_child("Achievement%03d" % (Achievements.index_of("Snap") + 1), true, false)
	_check(tile != null and tile.get_node("Title").text == "Tithe" and tile.get_node("Icon").texture == Achievements.icon(tithe),
		"an unlocked tile shows the name and full icon")
	_check(locked_tile != null and locked_tile.get_node("Title").text == "???" and locked_tile.get_node("Text").text == "This achievement is locked.",
		"a locked tile shows ??? and the locked line")
	screen.free()
	Progression.reset()
	_check(Achievements.is_unlocked(tithe), "New Game doesn't clear achievements")
	Achievements.load_from(path)
	_check(Achievements.is_unlocked(tithe) and Achievements.description(tithe) == "Filed Tithe from %s." % set_name, "unlocked achievements are saved and load back")
	Achievements.unlocked.disconnect(listen)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Achievements.load_from(Achievements.SAVE_PATH)


func _test_credits_roll() -> void:
	var closed := [false]
	var roll := CreditsRoll.new()
	roll.closed.connect(func() -> void: closed[0] = true)
	add_child(roll)
	roll.set_process(false)
	_check(roll._strip.position.y >= roll.size.y - 1.0 and roll.size.y > 0.0, "the credits start below the screen")
	await get_tree().process_frame
	await get_tree().process_frame
	var start: float = roll._strip.position.y
	roll.advance(1.0)
	var slow: float = start - roll._strip.position.y
	roll.advance(1.0, true)
	var fast: float = start - slow - roll._strip.position.y
	_check(is_equal_approx(slow, CreditsRoll.SPEED) and is_equal_approx(fast, CreditsRoll.SPEED * CreditsRoll.FAST),
		"they scroll steadily, %d times faster while a key is held: %.1f, %.1f" % [CreditsRoll.FAST, slow, fast])
	for i in 2000:
		if roll.is_holding():
			break
		roll.advance(0.5)
	var bottom: float = roll._strip.position.y + roll._strip.size.y
	_check(roll.is_holding() and not closed[0] and bottom <= 0.5,
		"the credits scroll until every line has left the screen: bottom at %.1f" % bottom)
	roll.advance(CreditsRoll.HOLD + 0.1)
	_check(closed[0] and roll.is_queued_for_deletion(), "and after a moment the credits close")
	await get_tree().process_frame
	roll = CreditsRoll.new()
	closed[0] = false
	roll.closed.connect(func() -> void: closed[0] = true)
	add_child(roll)
	var esc := InputEventAction.new()
	esc.action = Controls.PAUSE
	esc.pressed = true
	roll._unhandled_input(esc)
	_check(closed[0], "Esc leaves the credits")
	await get_tree().process_frame
	_check(not SceneFlow.take_credits_request(), "nothing asks for the credits by default")
	SceneFlow._credits_requested = true
	var title: Control = load(SceneFlow.TITLE_SCENE).instantiate()
	add_child(title)
	_check(title.state == title.State.MENU and title.find_child("CreditsRoll", false, false) != null,
		"after the ending, the credits roll over the main menu")
	title.free()
	var empty: Array[Binder] = []
	_check(not preload("res://scripts/main.gd").is_finished(empty, []), "an empty store isn't a finished game")
	get_viewport().gui_release_focus()


func _test_progression() -> void:
	Progression.reset()
	Progression.allow_debt = false
	var range_data := CardDatabase.all_binders()[0]
	var ids := _first_binder_cards()
	var binder := Binder.new()
	binder.setup(range_data, Color.RED, null)
	add_child(binder)
	binder.put_down(self, Vector3(4.0, 0.75, 2.0), 0.0)
	binder.open()
	binder.insert(1, ids[2])
	_check(Progression.mana == 0, "a card refused by the wrong pocket earns nothing")
	binder.insert(0, ids[0])
	_check(Progression.mana == 1, "a card locked in earns 1 Mana")
	for i in range(1, ids.size()):
		binder.show_pocket(i)
		binder.insert(i, ids[i])
	var bonus := Progression.binder_complete_bonus(ids.size())
	_check(bonus == ceili(ids.size() / 10.0), "finishing a binder pays 10% of its cards, rounded up")
	_check(Progression.mana == ids.size() + bonus, "every card plus the binder bonus, got %d" % Progression.mana)

	var unit := ShelfUnit.new()
	# Its shelf has other binders on it, so shelving this one doesn't light it.
	var few: Array[BinderRange] = []
	few.assign(CardDatabase.all_binders().slice(0, 6))
	unit.build(few, StandardMaterial3D.new(), 2.4)
	add_child(unit)
	var before := Progression.mana
	var empty := Binder.new()
	empty.setup(few[1], Color.BLUE, null)
	add_child(empty)
	unit.shelve(1, empty)
	_check(Progression.mana == before, "an incomplete binder in its own space pays nothing")
	unit.unshelve(1)
	empty.queue_free()
	unit.shelve(0, binder)
	_check(Progression.mana == before + Progression.BINDER_SHELVED, "a binder in its own space pays the shelf bonus")
	unit.unshelve(0)
	unit.shelve(0, binder)
	_check(Progression.mana == before + Progression.BINDER_SHELVED, "putting it back doesn't pay again")

	Progression.reset()
	_check(Progression.mana == 0 and Progression.bought_count(0) == 0, "reset starts a new game")
	_check(not Progression.can_buy(0, 0), "an unlock you can't afford can't be bought")
	Progression.earn(25)
	_check(not Progression.can_buy(0, 1), "a colour's unlocks are bought in order")
	_check(Progression.buy(0, 0) and Progression.mana == 5, "buying spends its price")
	_check(Progression.is_bought(0, 0) and not Progression.buy(0, 0), "an unlock is bought once")
	_check(Progression.rank("Remember the Fallen") == 1 and Progression.rank("Tithe") == 0, "rank tracks what's owned")
	Progression.allow_debt = true
	_check(Progression.buy(0, 1) and Progression.buy(0, 2) and Progression.mana == 5 - 40 - 90,
		"debug builds can buy into negative Mana, got %d" % Progression.mana)
	_check(Progression.rank("Enlightened Tutor") == 1 and Progression.rank("Tithe") == 1, "ranks follow the row")
	_check(Progression.step_name(0, 3) == "Enlightened Tutor II" and Progression.step_name(0, 6) == "Serra's Blessing",
		"unlocks read with their rank numeral, or none for single buys")
	var total := 0
	for colour in Progression.COLOURS.size():
		_check(Progression.COLOURS[colour].steps.size() == 7, "every colour is a row of seven")
		for step in 7:
			total += Progression.price(step)
	_check(total == 18250, "the whole tree costs 18,250 Mana")
	Progression.reset()
	Progression.allow_debt = OS.is_debug_build()
	unit.free() # The shelved binder goes with it.


func _test_radio() -> void:
	_check(Radio.title_from("07_rainy_tuesday.ogg") == "Rainy Tuesday" and Radio.title_from("lofi_night.mp3") == "Lofi Night",
		"a song's title comes from its file name, without its number")
	_check(Radio.unlocked_at(0.0, 10) == 3 and Radio.unlocked_at(1.0, 10) == 10 and Radio.unlocked_at(0.5, 10) == 7,
		"three songs from the start, the rest spread evenly over the game")
	_check(Radio.unlocked_at(0.99, 2) == 2 and Radio.unlocked_at(0.0, 0) == 0, "fewer songs than the free ones are all there")
	var empty := "user://test_radio_songs"
	DirAccess.make_dir_recursive_absolute(empty)
	_check(Radio.find_songs(empty).size() == Radio.PLACEHOLDERS.size() and Radio.find_songs(empty)[0].path == "",
		"with no songs in the folder, the placeholder tunes stand in")
	FileAccess.open(empty.path_join("02_second.ogg.import"), FileAccess.WRITE).store_string("")
	FileAccess.open(empty.path_join("01_first_song.ogg"), FileAccess.WRITE).store_string("")
	FileAccess.open(empty.path_join("notes.txt"), FileAccess.WRITE).store_string("")
	var found := Radio.find_songs(empty)
	_check(found.size() == 2 and found[0].title == "First Song" and found[1].path.ends_with("02_second.ogg"),
		"real songs replace the placeholders, in number order, also as an exported game lists them")
	for file in DirAccess.get_files_at(empty):
		DirAccess.remove_absolute(empty.path_join(file))
	DirAccess.remove_absolute(empty)

	var unlocked: Array[int] = []
	Radio.song_unlocked.connect(func(index: int) -> void: unlocked.append(index))
	Radio.playing = false
	Radio.enter_shop(0.5)
	_check(Radio.unlocked_count == 4 and unlocked.is_empty(), "a loaded game has the songs its progress earned, without announcing them")
	Radio.set_progress(0.9)
	_check(Radio.unlocked_count == 5 and unlocked == [4], "a song unlocking during play is announced")
	Radio.enter_shop(0.0)
	_check(Radio.unlocked_count == 3 and Radio.current == -1, "a new game starts with the free songs")
	Radio.play_song(4)
	_check(Radio.current == -1, "a locked song can't be played")
	Radio.play_song(0)
	_check(Radio.current == 0 and Radio.playing, "an unlocked song plays")
	Radio.next()
	Radio.next()
	Radio.next()
	_check(Radio.current == 0, "Next goes round the unlocked songs")
	Radio.previous()
	_check(Radio.current == 2, "Previous at the start of a song goes back one, round the list")
	Radio.toggle_playing()
	_check(not Radio.playing, "Pause stops the radio")
	Radio.toggle_playing()
	_check(Radio.playing and Radio.current == 2, "Play carries on with the same song")
	Radio.set_volume(0.4)
	Radio.set_repeat(true)
	Radio.volume = 1.0
	Radio.repeat = false
	Radio.load_from(RADIO_TEST_PATH)
	_check(is_equal_approx(Radio.volume, 0.4) and Radio.repeat and Radio.playing, "volume, repeat and playing are remembered")

	var menu := RadioMenu.new()
	add_child(menu)
	_check(menu.song_buttons.size() == Radio.songs.size(), "the menu lists every song")
	_check(menu.song_buttons[3].disabled and menu.song_buttons[3].text.ends_with("???")
		and menu.song_buttons[2].text.contains(Radio.songs[2].title), "locked songs show as ???, unlocked ones by title")
	_check(menu.title_label.text == Radio.songs[2].title and menu.play_button.text == "Pause" and menu.repeat_button.text == "Repeat: On",
		"the menu shows what's playing, Pause and repeat")
	menu.song_buttons[1].pressed.emit()
	_check(Radio.current == 1 and menu.title_label.text == Radio.songs[1].title, "clicking a song plays it")
	_check(Controls.label(Controls.RADIO) == "Q", "the radio is on Q")
	var q := InputEventAction.new()
	q.action = Controls.RADIO
	q.pressed = true
	menu._unhandled_input(q)
	_check(menu.is_open() and get_tree().paused, "Q opens the radio and stops the game")
	menu._unhandled_input(q)
	_check(not menu.is_open() and not get_tree().paused, "Q closes it again")
	menu.free()
	Radio.leave_shop()
	Radio.set_repeat(false)
	_check(RadioMenu.clock(83.4) == "1:23", "song times show as minutes and seconds")


func _test_upgrade_menu() -> void:
	Progression.reset()
	Progression.allow_debt = false
	var menu := UpgradeMenu.new()
	add_child(menu)
	var buttons: Array = menu.find_children("*", "Button", true, false)
	_check(buttons.size() == 35, "the menu has a button for each of the 35 unlocks, got %d" % buttons.size())
	_check((buttons[0] as Button).tooltip_text == "Remember the name and number of every card you've held.",
		"hovering an unlock says what it does")
	for button in buttons:
		_check((button as Button).tooltip_text.length() <= 90 and (button as Button).tooltip_text.ends_with("."),
			"every unlock has a one-line description: " + (button as Button).tooltip_text)
	var tab := InputEventAction.new()
	tab.action = Controls.UPGRADES
	tab.pressed = true
	menu._unhandled_input(tab)
	_check(menu.is_open() and get_tree().paused, "Tab opens the upgrade menu and stops the game")
	var first: Button = buttons[0]
	_check(first.text == "Remember the Fallen\n20 Mana" and first.disabled, "an unaffordable unlock shows its price, greyed out")
	Progression.earn(20)
	_check(not first.disabled and (buttons[1] as Button).disabled, "once affordable, only the colour's next unlock lights up")
	first.pressed.emit()
	_check(Progression.is_bought(0, 0) and first.text == "Remember the Fallen\nOwned", "clicking buys it")
	var esc := InputEventAction.new()
	esc.action = Controls.PAUSE
	esc.pressed = true
	menu._unhandled_input(esc)
	_check(not menu.is_open() and not get_tree().paused, "Esc closes the menu")
	menu.open()
	menu._unhandled_input(tab)
	_check(not menu.is_open() and not get_tree().paused, "Tab closes it too")
	menu.free()
	Progression.reset()
	Progression.allow_debt = OS.is_debug_build()


## Buys a colour's unlocks up to and including `step`, on credit.
func _buy_through(colour: int, step: int) -> void:
	Progression.allow_debt = true
	while Progression.bought_count(colour) <= step:
		Progression.buy(colour, Progression.bought_count(colour))


func _test_sorcery_recharge() -> void:
	Progression.reset()
	_check(not Progression.can_cast("Demonic Tutor") and not Progression.cast("Demonic Tutor"),
		"a sorcery can't be cast before it's learned")
	_buy_through(2, 0)
	_check(Progression.can_cast("Demonic Tutor"), "a learned sorcery starts ready")
	_check(Progression.cast("Demonic Tutor") and not Progression.can_cast("Demonic Tutor"), "casting starts its recharge")
	_check(is_equal_approx(Progression.recharge_left("Demonic Tutor"), 60.0), "Demonic Tutor I recharges in 60 s")
	Progression.tick(10.0)
	Progression.card_filed_by_hand()
	_check(is_equal_approx(Progression.recharge_left("Demonic Tutor"), 50.0 - Progression.FILING_SPEEDUP),
		"filing a card by hand speeds the recharge")
	for i in 100:
		Progression.card_filed_by_hand()
	_check(is_equal_approx(Progression.recharge_left("Demonic Tutor"), 60.0 * Progression.MIN_RECHARGE_SHARE - 10.0),
		"but never below the minimum, got %.1f" % Progression.recharge_left("Demonic Tutor"))
	Progression.tick(20.0)
	_check(Progression.can_cast("Demonic Tutor") and Progression.recharge_left("Demonic Tutor") == 0.0,
		"it's ready again once the time is up")
	_buy_through(2, 2)
	Progression.cast("Demonic Tutor")
	_check(is_equal_approx(Progression.recharge_left("Demonic Tutor"), 40.0), "Demonic Tutor II recharges in 40 s")
	var main := preload("res://scripts/main.gd")
	_check(main.sorcery_lines() == PackedStringArray(["3: Demonic Tutor (40 s)"]),
		"the corner shows each learned sorcery's key and recharge, got %s" % main.sorcery_lines())
	Progression.reset()
	_check(main.sorcery_lines().is_empty(), "no sorceries learned, no lines")
	Progression.allow_debt = OS.is_debug_build()


func _test_step_one_upgrades() -> void:
	Progression.reset()
	var hands := Hands.new()
	_check(is_equal_approx(hands.glide_seconds(0.24), 0.24) and is_equal_approx(hands.current_reach(), 2.6),
		"without upgrades: glides and reach as they are")
	var player: CharacterBody3D = load("res://scenes/player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(player)
	player.global_position = Vector3(80, 0, 80)
	_check(is_equal_approx(player.move_speed(), player.walk_speed), "walking at the base speed")

	# Remember the Fallen: a card you've held, seen again on the floor.
	var ids := _first_binder_cards()
	hands.seen_cards[ids[5]] = true
	hands._aim = Hands.Aim.FLOOR
	hands._aim_floor_card = ids[5]
	_check(hands.shown_card_id() == -1, "without Remember the Fallen, a floor card is a mystery")

	_buy_through(0, 0) # Remember the Fallen
	_buy_through(1, 0) # Snap I
	_buy_through(3, 0) # Fervor
	_buy_through(4, 0) # Spider Climb
	_check(hands.shown_card_id() == ids[5], "Remember the Fallen names a floor card you've held")
	hands._aim_floor_card = ids[6]
	_check(hands.shown_card_id() == -1, "but not one you've never held")
	_check(is_equal_approx(hands.glide_seconds(0.24), 0.16), "Snap I: glides 50% faster")
	_check(is_equal_approx(hands.current_reach(), 3.4), "Spider Climb: reach 3.4 m")
	_check(is_equal_approx(player.move_speed(), player.walk_speed * 1.5), "Fervor: walk 50% faster")
	player.set_crouched(true)
	_check(is_equal_approx(player.move_speed(), player.crouch_speed * 1.5), "and crouch-walk 50% faster")
	_buy_through(1, 2) # Snap II
	_check(is_equal_approx(hands.glide_seconds(0.24), 0.12), "Snap II: glides twice as fast")
	player.free()
	hands.free()
	Progression.reset()
	Progression.allow_debt = OS.is_debug_build()


func _test_demonic_tutor() -> void:
	Progression.reset()
	var pile := PileWorld.new()
	add_child(pile)
	pile.build_one_of_each(Rect2(0, 0, 12, 8), [] as Array[Rect2], 3)
	var binder := Binder.new()
	binder.setup(CardDatabase.all_binders()[0], Color.RED, pile)
	pile.add_child(binder)
	pile.binders.append(binder)
	binder.put_down(pile, Vector3(4.0, 0.75, 2.0), 0.0)
	binder.open()
	var ids := _first_binder_cards()

	var hands := Hands.new()
	var camera := Camera3D.new()
	var holder := Node3D.new()
	holder.add_child(camera)
	holder.add_child(hands)
	camera.name = "Camera3D"
	add_child(holder)
	hands.pile = pile
	hands._aim = Hands.Aim.BINDER
	hands._aim_binder = binder
	hands._aim_pocket = 2
	_check(not hands.cast_demonic_tutor(), "Demonic Tutor does nothing before it's learned")
	_buy_through(2, 0)
	_check(hands.cast_demonic_tutor() and hands.held_card_id == ids[2] and not pile.is_on_floor(ids[2]),
		"Demonic Tutor brings the aimed pocket's card up off the floor into your hand")
	_check(not Progression.can_cast("Demonic Tutor"), "and starts recharging")
	hands._glide.custom_step(10.0)
	hands._hold(-1)
	Progression.reset()
	_buy_through(2, 0)
	pile.pick_up(ids[1])
	binder.insert(1, ids[1])
	hands._aim_pocket = 1
	_check(not hands.cast_demonic_tutor(), "a pocket that isn't empty can't be tutored for")
	var loose := LooseCard.new()
	pile.add_child(loose)
	loose.setup(ids[3], Vector3(1, 0.75, 1), 0.0)
	pile.pick_up(ids[3])
	hands._aim_pocket = 3
	_check(hands.cast_demonic_tutor() and hands.held_card_id == ids[3] and loose.is_queued_for_deletion(),
		"a card lying on a table comes too")
	hands._glide.custom_step(10.0)
	hands._hold(-1)
	Progression.reset()
	_buy_through(2, 0)
	hands._aim_pocket = 4
	pile.pick_up(ids[4]) # Somewhere it can't be had, like mid-toss.
	_check(not hands.cast_demonic_tutor() and Progression.can_cast("Demonic Tutor"),
		"no card to fetch, no cast spent")
	holder.free()
	pile.free()
	Progression.reset()
	Progression.allow_debt = OS.is_debug_build()


func _test_step_two_upgrades() -> void:
	Progression.reset()
	var pile := PileWorld.new()
	add_child(pile)
	pile.build_one_of_each(Rect2(0, 0, 12, 8), [] as Array[Rect2], 5)
	var binder := Binder.new()
	binder.setup(CardDatabase.all_binders()[0], Color.RED, pile)
	pile.add_child(binder)
	pile.binders.append(binder)
	binder.put_down(pile, Vector3(4.0, 0.75, 2.0), 0.0)
	binder.open()
	var ids := _first_binder_cards()
	var hands := Hands.new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	var holder := CharacterBody3D.new() # Stands in for the player.
	holder.add_child(camera)
	holder.add_child(hands)
	holder.process_mode = Node.PROCESS_MODE_DISABLED # Aim is set by hand below.
	add_child(holder)
	hands.pile = pile
	var main := preload("res://scripts/main.gd")

	# Enlightened Tutor: the set of a floor card you've never held.
	hands._aim = Hands.Aim.FLOOR
	hands._aim_floor_card = ids[20]
	_check(hands.shown_set_card_id() == -1, "without Enlightened Tutor a floor card shows nothing")
	_buy_through(0, 1)
	_check(hands.shown_set_card_id() == ids[20], "Enlightened Tutor shows a floor card's set")
	var set_data := CardDatabase.get_set(CardDatabase.get_card(ids[20]).set_code)
	_check(main.set_details(CardDatabase.get_card(ids[20])) == "%s\n%s #???" % [set_data.name, set_data.code],
		"just the set, the number unknown: got " + main.set_details(CardDatabase.get_card(ids[20])))

	# Pile flip, then Unmask.
	var point := pile.card_position(ids[30])
	hands._aim_point = point
	var flipped := hands.flip_pile()
	_check(flipped.size() == 4, "a pile flip tosses 4 cards, got %d" % flipped.size())
	_check(flipped.all(func(id: int) -> bool: return not pile.is_on_floor(id)), "flipped cards leave the pile")
	_land_tossed(pile)
	_check(flipped.all(func(id: int) -> bool: return pile.is_on_floor(id)), "and land back on it")
	_buy_through(2, 3) # Unmask II
	flipped = hands.flip_pile()
	_check(flipped.size() == 16, "Unmask II flips 16, got %d" % flipped.size())
	_land_tossed(pile)
	_check(flipped.all(func(id: int) -> bool: return pile._face_up[id] == 1), "and every one lands face up")
	Progression.reset()
	_buy_through(2, 1)
	_check(hands.flip_pile().size() == 8, "Unmask I flips 8")
	_land_tossed(pile)

	# Harmonize: hold 3, wheel cycles the top.
	_check(hands.hand_size() == 1, "one card at a time to start")
	_buy_through(4, 1)
	_check(hands.hand_size() == 3, "Harmonize I holds 3")
	for i in 3:
		pile.pick_up(ids[40 + i])
		hands._take_in_hand(ids[40 + i])
	_check(hands.held_card_id == ids[42] and hands.behind == [ids[41], ids[40]] and not hands.has_room(),
		"each card picked up goes on top, and then the hand is full")
	hands.cycle_hand(1)
	_check(hands.held_card_id == ids[41] and hands.behind == [ids[40], ids[42]], "the wheel brings the next card up")
	hands.cycle_hand(-1)
	_check(hands.held_card_id == ids[42], "and back")
	hands._release_top()
	_check(hands.held_card_id == ids[41] and hands.hand_count() == 2, "when the top card goes, the next comes up")

	# Teleport: the top card files itself, wherever its binder is.
	_buy_through(1, 1)
	binder.close()
	var mana := Progression.mana
	_check(hands.cast_teleport() and hands.held_card_id == ids[40], "Teleport sends the top card off")
	await get_tree().create_timer(1.5).timeout
	_check(binder.contents.is_locked(41), "and it files itself, even in a closed binder")
	_check(Progression.mana == mana + Progression.CARD_LOCKED, "earning its Mana")
	_check(not hands.cast_teleport(), "then it recharges")

	# Chain Lightning: the next lock-in lights a missing card from its page.
	binder.open()
	binder.show_pocket(40)
	_buy_through(3, 1)
	_check(Progression.arm("Chain Lightning") and Progression.is_armed("Chain Lightning"), "Chain Lightning arms")
	_check(main.sorcery_lines().has("4: Chain Lightning (armed)"), "and says so in the corner: %s" % main.sorcery_lines())
	hands._file(binder, 40, ids[40])
	var page_cards := range(36, 45).map(func(i: int) -> int: return ids[i]).filter(func(id: int) -> bool: return pile.is_glowing(id))
	_check(page_cards.size() == 1 and not Progression.is_armed("Chain Lightning"),
		"the lock-in sets it off: 1 missing card from the page glows, got %d" % page_cards.size())
	pile._process(hands.chain_lightning_glow_seconds + 1.0)
	_check(not pile.is_glowing(page_cards[0]), "the glow fades")

	holder.free()
	pile.free()
	Progression.reset()
	Progression.allow_debt = OS.is_debug_build()


func _test_step_three_upgrades() -> void:
	Progression.reset()
	var pile := PileWorld.new()
	add_child(pile)
	pile.build_one_of_each(Rect2(0, 0, 12, 8), [] as Array[Rect2], 9)
	var binder := Binder.new()
	binder.setup(CardDatabase.all_binders()[0], Color.RED, pile)
	pile.add_child(binder)
	pile.binders.append(binder)
	binder.put_down(pile, Vector3(4.0, 0.75, 2.0), 0.0)
	binder.open()
	var ids := _first_binder_cards()
	var hands := Hands.new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	var holder := CharacterBody3D.new()
	holder.add_child(camera)
	holder.add_child(hands)
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(holder)
	hands.pile = pile

	# Tithe: missing cards for the binder you look at glow.
	hands._aim = Hands.Aim.BINDER
	hands._aim_binder = binder
	hands._aim_pocket = -1
	_check(hands.cast_tithe().is_empty(), "Tithe does nothing before it's learned")
	_buy_through(0, 2)
	var lit := hands.cast_tithe()
	_check(lit.size() == 5 and lit.all(func(id: int) -> bool: return pile.is_glowing(id) and ids.has(id)),
		"Tithe I lights 5 of the binder's missing cards, got %d" % lit.size())
	_check(not Progression.can_cast("Tithe"), "and recharges")
	pile._process(5.5)
	_check(not lit.any(func(id: int) -> bool: return pile.is_glowing(id)), "the glow lasts 5 s")

	# Without Shunt, a click on the wrong pocket does nothing: the card stays
	# in hand. Its own pocket takes it.
	pile.pick_up(ids[5])
	hands._take_in_hand(ids[5])
	binder.show_pocket(5)
	hands._aim_pocket = 7
	_check(hands._try_file_held_card() and hands.held_card_id == ids[5] and binder.contents.card_at(7) == -1
		and not hands._gliding(), "a click on the wrong pocket leaves the card in hand")
	hands._aim_pocket = 5
	_check(hands._try_file_held_card(), "a click on its own pocket files it")
	hands._glide.custom_step(10.0)
	_check(binder.contents.is_locked(5) and hands.held_card_id == -1, "and it locks in")

	# Shunt: click anywhere on the right open pages.
	_buy_through(3, 2)
	pile.pick_up(ids[4])
	hands._take_in_hand(ids[4])
	binder.show_pocket(4)
	_check(hands.shunt_pocket(binder) == 4, "Shunt finds the held card's own pocket on the open pages")
	hands._aim_pocket = 7 # The wrong pocket, on the same page.
	_check(hands._try_file_held_card(), "a click on the wrong pocket files it")
	hands._glide.custom_step(10.0)
	_check(binder.contents.is_locked(4) and binder.contents.card_at(7) == -1, "into its own pocket")
	pile.pick_up(ids[40])
	hands._take_in_hand(ids[40])
	_check(hands.shunt_pocket(binder) == -1, "but not when its page isn't open")
	hands._release_top()
	pile.drop(ids[40], Vector3(2, 0, 2), 0.0)

	# Abundance: the next unfiled cards come to hand behind the top one.
	_buy_through(4, 2) # Harmonize I and Abundance I
	pile.pick_up(ids[10])
	hands._take_in_hand(ids[10])
	binder.insert(11, ids[11]) # Already filed: skipped.
	var brought := hands.cast_abundance()
	_check(brought == [ids[12], ids[13]] and hands.behind == brought and hands.hand_count() == 3,
		"Abundance brings the next unfiled cards, in order, until the hand is full; got %s" % [brought])
	_check(not pile.is_on_floor(ids[12]) and not Progression.can_cast("Abundance"), "out of the pile, and recharges")
	await get_tree().create_timer(1.5).timeout
	_check(hands._incoming == 0, "the cards arrive")

	holder.free()
	pile.free()
	Progression.reset()
	Progression.allow_debt = OS.is_debug_build()


func _test_step_four_upgrades() -> void:
	Progression.reset()
	var pile := PileWorld.new()
	add_child(pile)
	pile.build_one_of_each(Rect2(0, 0, 12, 8), [] as Array[Rect2], 11)
	var binder := Binder.new()
	binder.setup(CardDatabase.all_binders()[0], Color.RED, pile)
	pile.add_child(binder)
	pile.binders.append(binder)
	binder.put_down(pile, Vector3(4.0, 0.75, 2.0), 0.0)
	binder.open()
	var ids := _first_binder_cards()
	var hands := Hands.new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	var holder := CharacterBody3D.new()
	holder.add_child(camera)
	holder.add_child(hands)
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(holder)
	hands.pile = pile

	# Enlightened Tutor II: a floor card you've never held, read in full.
	hands._aim = Hands.Aim.FLOOR
	hands._aim_floor_card = ids[50]
	_buy_through(0, 1)
	_check(hands.shown_card_id() == -1 and hands.shown_set_card_id() == ids[50], "Enlightened Tutor I shows only the set")
	_buy_through(0, 3)
	_check(hands.shown_card_id() == ids[50], "Enlightened Tutor II shows the whole card")

	# Brainstorm: finishing a page by hand sends a missing card home.
	binder.show_pocket(0)
	for i in 8:
		pile.pick_up(ids[i])
		binder.insert(i, ids[i])
	pile.pick_up(ids[8])
	_check(hands.brainstorm(binder).is_empty(), "no Brainstorm before it's learned")
	_buy_through(1, 3)
	var locked := binder.contents.locked_count
	hands._file(binder, 8, ids[8]) # The last card of page 1, by hand.
	await get_tree().create_timer(1.5).timeout
	_check(binder.contents.locked_count == locked + 2,
		"the page's last card and 1 Brainstormed card lock in, got %d" % (binder.contents.locked_count - locked))
	var count_before := binder.contents.locked_count
	_check(hands.brainstorm(binder).size() == 1, "Brainstorm I sends 1 card")
	await get_tree().create_timer(1.5).timeout
	_check(binder.contents.locked_count == count_before + 1, "which files itself")

	holder.free()
	pile.free()
	Progression.reset()
	Progression.allow_debt = OS.is_debug_build()


func _test_steps_five_to_seven() -> void:
	Progression.reset()
	var pile := PileWorld.new()
	add_child(pile)
	pile.build_one_of_each(Rect2(0, 0, 12, 8), [] as Array[Rect2], 13)
	var binder := Binder.new()
	binder.setup(CardDatabase.all_binders()[0], Color.RED, pile)
	pile.add_child(binder)
	pile.binders.append(binder)
	binder.put_down(pile, Vector3(4.0, 0.75, 2.0), 0.0)
	binder.open()
	var ids := _first_binder_cards()
	var hands := Hands.new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	var holder := CharacterBody3D.new()
	holder.add_child(camera)
	holder.add_child(hands)
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(holder)
	hands.pile = pile

	# Teleport II: the whole hand.
	_buy_through(4, 1) # Harmonize I
	_buy_through(1, 4) # Teleport II
	for i in 3:
		pile.pick_up(ids[60 + i])
		hands._take_in_hand(ids[60 + i])
	_check(hands.cast_teleport() and hands.hand_count() == 0, "Teleport II sends the whole hand")
	await get_tree().create_timer(1.5).timeout
	_check(binder.contents.is_locked(60) and binder.contents.is_locked(61) and binder.contents.is_locked(62),
		"and every card files itself")

	# Shunt II and III.
	_buy_through(3, 4) # Shunt II
	binder.show_pocket(0)
	pile.pick_up(ids[70])
	hands._take_in_hand(ids[70])
	hands._aim = Hands.Aim.BINDER
	hands._aim_binder = binder
	hands._aim_pocket = 2
	_check(hands.shunt_pocket(binder) == 70, "Shunt II files onto the right binder open at the wrong pages")
	_check(hands._try_file_held_card(), "a click files it")
	hands._glide.custom_step(10.0)
	_check(binder.contents.is_locked(70), "into its own pocket, turning to its page")
	binder.close()
	pile.pick_up(ids[71])
	hands._take_in_hand(ids[71])
	_check(hands.shunt_pocket(binder) == -1, "Shunt II needs the binder open")
	_buy_through(3, 6) # Shunt III
	_check(hands.shunt_pocket(binder) == 71 and hands._try_file_held_card(), "Shunt III files into a closed binder")
	hands._glide.custom_step(10.0)
	_check(binder.contents.is_locked(71), "through the cover")
	binder.open()

	# Demonic Consultation: flipped cards for an open binder hover.
	_buy_through(2, 4) # Demonic Consultation I
	var point := Vector3(6.0, 0.0, 6.0)
	for i in 2: # Two of the binder's cards on top of the pile there.
		pile.pick_up(ids[80 + i])
		pile.drop(ids[80 + i], point, 0.0)
	hands._aim = Hands.Aim.FLOOR
	hands._aim_point = point
	var flipped := hands.flip_pile()
	var hovering := pile.get_children().filter(func(c: Node) -> bool: return c is HoveringCard)
	var hovered_ids := hovering.map(func(c: HoveringCard) -> int: return c.card_id)
	_check(hovered_ids.has(ids[80]) and hovered_ids.has(ids[81]) and hovered_ids.all(func(id: int) -> bool: return ids.has(id)),
		"flipped cards whose binder is open hover; got %s" % [hovered_ids])
	var card: HoveringCard = hovering[0]
	_check(is_equal_approx(card.seconds_left, 5.0), "for 5 s")
	_check(pile.take_from_anywhere(card.card_id) != null, "a hovering card can be grabbed")
	binder.close()
	for c in hovering:
		if not c.is_queued_for_deletion():
			c._process(0.1)
	_check(hovered_ids.slice(1).all(func(id: int) -> bool: return pile.is_on_floor(id)), "closing the binder drops the rest")
	_land_tossed(pile)

	# Serra's Blessing: Tithe always on for the open binder you look at.
	binder.open()
	hands._aim = Hands.Aim.BINDER
	hands._aim_binder = binder
	_buy_through(0, 6)
	hands._update_blessing(0.0)
	var glowing := ids.filter(func(id: int) -> bool: return pile.is_glowing(id))
	var on_floor := ids.filter(func(id: int) -> bool: return pile.is_on_floor(id))
	_check(glowing.size() == on_floor.size() and not glowing.is_empty(),
		"Serra's Blessing lights every missing card (%d of %d)" % [glowing.size(), on_floor.size()])
	hands._aim = Hands.Aim.NONE
	hands._update_blessing(1.0)
	_check(hands._blessed == binder, "and keeps on after you look away")
	binder.close()
	hands._update_blessing(1.0)
	_check(hands._blessed == null, "until the binder is closed")

	holder.free()
	pile.free()
	Progression.reset()
	Progression.allow_debt = OS.is_debug_build()


## Cards lying on a table work just like cards on the floor: tosses and
## flips land on it, magic finds them, and their details follow the same
## rules.
func _test_table_cards() -> void:
	Progression.reset()
	var pile := PileWorld.new()
	add_child(pile)
	pile.build_one_of_each(Rect2(0, 0, 12, 8), [] as Array[Rect2], 11)
	var store := preload("res://scripts/store/store_builder.gd")
	var center: Vector2 = store.TABLE_CENTERS[0]
	var top_y: float = store.TABLE_SIZE.y
	var table_size := Vector2(store.TABLE_SIZE.x, store.TABLE_SIZE.z)
	pile.surfaces = [Rect2(center - table_size / 2, table_size)] as Array[Rect2]
	var table := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(store.TABLE_SIZE.x, 0.05, store.TABLE_SIZE.z)
	shape.shape = box
	table.add_child(shape)
	pile.add_child(table)
	table.position = Vector3(center.x, top_y - 0.025, center.y)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ids := _first_binder_cards()

	# A toss over the table lands on it, not on the floor under it.
	pile.pick_up(ids[0])
	var tossed := TossedCard.new()
	pile.add_child(tossed)
	tossed.launch(ids[0], pile, ShaderMaterial.new(), Transform3D(Basis(), Vector3(center.x - 0.4, top_y + 0.3, center.y)),
		Vector3(0.6, 0.5, 0.0), Vector3(TAU, 0.0, 0.0))
	var steps := 0
	while not tossed.is_queued_for_deletion() and steps < 600:
		tossed._physics_process(1.0 / 60.0)
		steps += 1
	var on_table := pile.loose_card(ids[0])
	_check(on_table != null and pile.is_lying(ids[0]) and not pile.is_on_floor(ids[0])
		and absf(on_table.position.y - top_y) < 0.01, "a card tossed over a table lands on it")

	# Landing at the edge it's nudged onto the felt, and it can land face down.
	pile.pick_up(ids[1])
	pile.land(ids[1], Vector3(center.x + store.TABLE_SIZE.x / 2 - 0.005, top_y, center.y), 0.0, false)
	var edge := pile.loose_card(ids[1])
	_check(edge != null and edge.position.x + PileWorld.CARD_SIZE.x / 2 <= center.x + store.TABLE_SIZE.x / 2,
		"a card landing on a table's edge is kept on the table")
	_check(not pile.is_face_up(ids[1]) and not edge.face_up, "and lies face down if it landed that way")
	_check(edge.card_pose().basis.is_equal_approx(Glide.flat_card(Vector3.ZERO, Basis(), false).basis),
		"picking it up starts from its face-down pose")

	# A card falling past the table's edge goes to the floor.
	pile.pick_up(ids[2])
	pile.land(ids[2], Vector3(center.x + 1.0, 0.0, center.y), 0.0)
	_check(pile.is_on_floor(ids[2]) and pile.loose_card(ids[2]) == null, "off the table, it lands on the pile")

	# Magic finds table cards like floor cards.
	var binder := Binder.new()
	binder.setup(CardDatabase.all_binders()[0], Color.RED, pile)
	pile.add_child(binder)
	pile.binders.append(binder)
	binder.put_down(pile, Vector3(2.0, 0.75, 2.0), 0.0)
	binder.open()
	var hands := Hands.new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	var holder := CharacterBody3D.new()
	holder.add_child(camera)
	holder.add_child(hands)
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(holder)
	hands.pile = pile
	hands._aim = Hands.Aim.BINDER
	hands._aim_binder = binder
	hands._aim_pocket = -1
	_buy_through(0, 5) # Tithe III: every missing card
	var lit := hands.cast_tithe()
	_check(lit.has(ids[0]) and lit.has(ids[1]) and pile.is_glowing(ids[0]), "Tithe finds cards lying on a table")
	pile.pick_up(ids[0])
	_check(not pile.is_glowing(ids[0]) and on_table.is_queued_for_deletion() and not pile.is_lying(ids[0]),
		"picking one up stops its glow and takes it off the table")

	# Details: a card you set down on a table is a mystery again without
	# Remember the Fallen, as on the floor.
	Progression.reset()
	hands.seen_cards[ids[1]] = true
	hands._aim = Hands.Aim.LOOSE_CARD
	hands._aim_loose_card = edge
	_check(hands.shown_card_id() == -1, "without Remember the Fallen, a table card you've held is a mystery")
	_buy_through(0, 0)
	_check(hands.shown_card_id() == ids[1], "with it, it's named")
	hands.seen_cards.erase(ids[1])
	_buy_through(0, 1)
	_check(hands.shown_card_id() == -1 and hands.shown_set_card_id() == ids[1],
		"Enlightened Tutor shows a table card's set")

	# A pile flip aimed at the table flips the cards there, not the floor under it.
	for i in range(3, 6):
		pile.pick_up(ids[i])
		pile.land(ids[i], Vector3(center.x + 0.02 * i, top_y, center.y + 0.3), 0.0)
	hands._aim = Hands.Aim.SURFACE
	hands._aim_point = Vector3(center.x + 0.08, top_y, center.y + 0.3)
	var flipped := hands.flip_pile()
	_check(flipped.size() == 3 and flipped.all(func(id: int) -> bool: return ids.slice(3, 6).has(id)),
		"a pile flip on a table flips the cards lying there, got %s" % [flipped])
	_land_tossed(pile)
	_check(flipped.all(func(id: int) -> bool: return pile.loose_card(id) != null),
		"and they land back on the table")

	holder.free()
	pile.free()
	Progression.reset()
	Progression.allow_debt = OS.is_debug_build()


## A tossed binder flies through other binders without moving them, lands
## on top of whatever it comes down on, cover up or face down as it turned,
## and is a binder lying there like any other.
func _test_binder_toss() -> void:
	# The binders are tossed over clear floor, so how the cards happen to
	# lie can't change where they land: no cards there, and none from piles
	# earlier checks left behind.
	for child in get_children():
		if child is PileWorld:
			child.free()
	var pile := PileWorld.new()
	add_child(pile)
	pile.build_one_of_each(Rect2(0, 0, 12, 8), [] as Array[Rect2], 11)
	var clear := Rect2(3.5, 3.0, 3.0, 2.0)
	for id in CardDatabase.card_count():
		var at := pile.card_position(id)
		if pile.is_on_floor(id) and clear.has_point(Vector2(at.x, at.z)):
			pile.pick_up(id)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	pile.add_child(floor_body)
	var made: Array[Binder] = []
	for i in 2:
		var binder := Binder.new()
		binder.setup(CardDatabase.all_binders()[i], Color.RED, pile)
		pile.add_child(binder)
		pile.binders.append(binder)
		made.append(binder)
	var lying := made[0]
	var tossed := made[1]
	lying.put_down(pile, Vector3(5.0, 0.0, 4.0), 0.0)
	for i in 30:
		await get_tree().physics_frame
	lying.sleeping = true
	var was := lying.global_transform

	# Thrown from right where it lies: out through it, not into it.
	tossed.toss(pile, Transform3D(Basis(), Vector3(4.95, lying.global_position.y + 0.005, 4.0)),
		Vector3(4.0, 1.0, 0.0), Vector3.ZERO)
	_check(tossed.state == Binder.State.TOSSED and tossed.collision_layer == 0, "a tossed binder can't be hit or aimed at in the air")
	var steps := await _fly_binder(tossed)
	_check(tossed.state == Binder.State.CLOSED and not tossed.freeze, "a tossed binder comes down closed and back in physics (%d steps)" % steps)
	_check(lying.global_transform.origin.distance_to(was.origin) < 0.002, "a binder in the way isn't knocked about")
	_check(absf(tossed.global_basis.y.y) > 0.95, "it lands lying down, not on its edge")
	_check(tossed.global_position.x > 5.3, "it lands past the binder it went through (x=%.2f)" % tossed.global_position.x)

	# Coming down on the other binder, it lands on top of it, face down
	# here, the way it was turned.
	var top := lying.global_position.y + lying.thickness
	tossed.toss(pile, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(5.0, top + 0.4, 4.0)), Vector3(0, 0.3, 0), Vector3.ZERO)
	var rest := tossed.toss_rest_pose()
	_check(rest.basis.y.y < -0.99 and absf(rest.origin.y - tossed.thickness - top) < 0.02,
		"in the air, a save keeps it face down on top of the other binder")
	await _fly_binder(tossed)
	_check(tossed.global_basis.y.y < -0.99, "a binder face down as it comes down lands on its back")
	var bottom := tossed.global_position.y - tossed.thickness
	_check(absf(bottom - top) < 0.01, "on top of the binder under it (%.3f vs %.3f)" % [bottom, top])
	_check(lying.global_transform.origin.distance_to(was.origin) < 0.005, "without moving it")
	tossed.open()
	_check(tossed.is_open() and tossed.global_basis.y.y > 0.99, "and it opens the right way up")

	# Hands: right-click with a binder in hand throws it.
	tossed.close()
	var hands := Hands.new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	var holder := CharacterBody3D.new()
	holder.add_child(camera)
	holder.add_child(hands)
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(holder)
	holder.global_position = Vector3(3.0, 1.0, 4.0)
	camera.rotation.y = -PI / 2  # Facing +x.
	hands.pile = pile
	hands._carry(tossed)
	hands._glide.custom_step(10.0)
	hands.toss_binder()
	_check(hands.carried_binder == null and tossed.state == Binder.State.TOSSED and tossed.get_parent() == pile,
		"right-click throws the carried binder")
	await _fly_binder(tossed)
	_check(tossed.state == Binder.State.CLOSED and tossed.global_position.x > 3.2, "it lands in front of you")
	holder.free()
	pile.free()


## Steps a tossed binder until it's down and settled. Returns the steps.
func _fly_binder(binder: Binder) -> int:
	var steps := 0
	while binder.state == Binder.State.TOSSED and steps < 600:
		await get_tree().physics_frame
		steps += 1
	for i in 5:
		await get_tree().physics_frame
	return steps


## Runs every tossed card in the pile until it lands.
func _land_tossed(pile: PileWorld) -> void:
	for child in pile.get_children():
		if child is TossedCard:
			var steps := 0
			while not child.is_queued_for_deletion() and steps < 600:
				child._physics_process(1.0 / 60.0)
				steps += 1
func _test_reading_corner() -> void:
	var store_script := preload("res://scripts/store/store_builder.gd")
	var store: Node3D = store_script.new()
	add_child(store)
	var pieces: Array[Rect2] = []
	for name in ["Armchair", "SideTable", "FloorLamp"]:
		var piece: Node3D = store.get_node(name)
		_check(piece.is_in_group(ReadingCorner.FURNITURE), "the %s is furniture" % name)
		var at := Vector2(piece.position.x, piece.position.z)
		var footprint: Rect2 = store.obstacles.filter(func(r: Rect2) -> bool: return r.has_point(at)).front()
		pieces.append(footprint)
	var tables: Array[Rect2] = []
	for center in store_script.TABLE_CENTERS:
		var size := Vector2(store_script.TABLE_SIZE.x, store_script.TABLE_SIZE.z)
		tables.append(Rect2(center - size / 2, size))
	var room: Rect2 = store.floor_bounds()
	var clear := pieces.all(func(r: Rect2) -> bool:
		return room.encloses(r) and r.position.x < 0.5 and not tables.any(func(t: Rect2) -> bool: return t.intersects(r)))
	_check(clear, "the reading corner stands against the left-hand wall, clear of the walls and work tables")
	_check(not pieces[1].intersects(pieces[2]) and not pieces[0].intersects(pieces[1]), "the chair, table and lamp don't overlap")
	var chair: Node3D = store.get_node("Armchair")
	_check(chair.global_basis.z.x > 0.5 and chair.global_basis.z.z < 0.0, "the chair faces the room, angled toward the back tables")
	var radio: ShopRadio = store.radio
	_check(is_equal_approx(radio.global_position.y, ReadingCorner.TABLE_HEIGHT) and pieces[1].has_point(Vector2(radio.global_position.x, radio.global_position.z)),
		"the radio sits on the side table")
	_check(radio.global_basis.z.x > 0.5, "facing out into the room")
	var mesh := ReadingCorner.rounded_box(Vector3(0.4, 0.2, 0.3), 0.05)
	var bounds := mesh.get_aabb()
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var corner := vertices.size() > 0
	for v in vertices:
		if Vector3(absf(v.x), absf(v.y), absf(v.z)).distance_to(Vector3(0.15, 0.05, 0.1)) > 0.0501 and absf(v.x) > 0.15 and absf(v.y) > 0.05 and absf(v.z) > 0.1:
			corner = false
	_check(bounds.size.is_equal_approx(Vector3(0.4, 0.2, 0.3)) and corner, "a rounded box keeps its size and rounds its corners")
	store.free()

	# In the shop, clicking the radio opens the Radio menu; the rest of the corner does nothing.
	var main: Node3D = load(SceneFlow.SHOP_SCENE).instantiate()
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hands: Hands = main.get_node("Player/Hands")
	var camera: Camera3D = main.get_node("Player/Camera3D")
	var shop_radio: ShopRadio = main.get_node("Store").radio
	var target := shop_radio.global_position + Vector3.UP * ShopRadio.SIZE.y / 2
	camera.global_transform = Transform3D(Basis(), target + shop_radio.global_basis.z * 1.2 + Vector3.UP * 0.4).looking_at(target)
	hands._update_aim()
	_check(hands._aim == Hands.Aim.RADIO, "aiming at the radio")
	var menu: RadioMenu = main.find_children("*", "RadioMenu", false, false).front()
	hands._use_hand()
	_check(menu.is_open() and get_tree().paused, "clicking it opens the Radio menu")
	menu.close()
	_check(not get_tree().paused, "and it closes again")
	var seat: Node3D = main.get_node("Store/Armchair")
	var cushion := seat.global_position + Vector3.UP * ReadingCorner.SEAT_HEIGHT
	camera.global_transform = Transform3D(Basis(), cushion + seat.global_basis.z * 1.2 + Vector3.UP * 0.8).looking_at(cushion)
	hands._update_aim()
	_check(hands._aim == Hands.Aim.NONE, "the armchair's seat isn't somewhere to put things down")
	main.free()


func _test_display_cabinets() -> void:
	var store_script := preload("res://scripts/store/store_builder.gd")
	var store: Node3D = store_script.new()
	add_child(store)
	var slots: Array[Marker3D] = store.display_slots
	_check(slots.size() == 36, "36 shadow boxes across the display cabinets (%d)" % slots.size())
	var wall: float = store_script.WIDTH
	for slot in slots:
		var at := slot.global_position
		# From the door (facing -z), the right-hand wall is x = WIDTH.
		if at.x < wall - DisplayCabinet.DEPTH or at.x > wall or at.y < DisplayCabinet.BASE_HEIGHT or at.y > DisplayCabinet.CASE_TOP:
			_check(false, "slot %s inside a cabinet on the right-hand wall (%s)" % [slot.name, at])
			break
		if not slot.global_basis.z.is_equal_approx(Vector3.LEFT):
			_check(false, "slot %s faces into the room" % slot.name)
			break
	# Slots read left to right facing the wall: towards the door, along +z.
	_check(slots[0].global_position.z < slots[1].global_position.z, "slots run left to right")
	# Each case fills its left half (1-9, three by three) before its right half (10-18).
	_check(is_equal_approx(slots[3].global_position.z, slots[0].global_position.z)
		and slots[3].global_position.y < slots[0].global_position.y, "rare card 4 hangs under 1")
	_check(is_equal_approx(slots[9].global_position.y, slots[0].global_position.y)
		and slots[9].global_position.z > slots[2].global_position.z, "rare card 10 starts the right half's top row")
	_check(is_equal_approx(slots[17].global_position.y, slots[8].global_position.y)
		and slots[17].global_position.z > slots[16].global_position.z, "rare card 18 ends the right half's bottom row")
	_check(slots[0].global_position.y > slots[DisplayCabinet.HALF_COLUMNS].global_position.y, "top row first")
	_check(slots[DisplayCabinet.SLOTS].global_position.z > slots[DisplayCabinet.SLOTS - 1].global_position.z, "back cabinet first")
	# Nothing on the floor lands in a cabinet.
	for z in store_script.CABINET_ZS:
		var blocked := false
		for rect in store.obstacles:
			if rect.has_point(Vector2(wall - 0.05, z + DisplayCabinet.WIDTH / 2 - 0.02)) and rect.has_point(Vector2(wall - DisplayCabinet.DEPTH + 0.02, z - DisplayCabinet.WIDTH / 2)):
				blocked = true
		_check(blocked, "the floor under the cabinet at z %.1f is kept clear" % z)
	store.free()


func _test_day_cycle() -> void:
	var noon := DayCycle.daylight_at(12.5)
	var midnight := DayCycle.daylight_at(0.0)
	var dusk := DayCycle.daylight_at(19.0)
	_check(noon.a > 0.9 and midnight.a == 0.0, "full daylight at noon, none at midnight")
	_check(dusk.r > dusk.b and dusk.a > 0.0 and dusk.a < noon.a, "dusk is warm and dimmer than noon")
	_check(DayCycle.daylight_at(24.0) == midnight and DayCycle.daylight_at(36.0) == DayCycle.daylight_at(12.0), "the day wraps round")
	var environment := Environment.new()
	var day := DayCycle.new()
	day.setup(environment, [] as Array[Light3D], null, null)
	day.hour = 12.0
	day.apply()
	var day_ambient := environment.ambient_light_energy
	day.hour = 23.0
	day.apply()
	_check(environment.ambient_light_energy < day_ambient and environment.ambient_light_energy > 0.0, "nights are dimmer but not black")
	day.free()
	_check(Settings.day_seconds() == 900.0, "a day lasts 15 minutes by default")


func _test_crouch() -> void:
	var player: CharacterBody3D = load("res://scenes/player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED # Driven by hand below.
	add_child(player)
	player.global_position = Vector3(50, 0, 50)
	var shape: CapsuleShape3D = player.get_node("CollisionShape3D").shape
	_check(is_equal_approx(shape.height, player.stand_body_height), "the body starts standing height")
	Settings.change("crouch_toggle", true)
	Settings.change("field_of_view", 90.0)
	_check(player.crouch_toggle and player.get_node("Camera3D").fov == 90.0, "the player follows the crouch and field of view settings")
	player.look(Vector2(0, -10))
	var up: float = player.get_node("Camera3D").rotation.x
	Settings.change("invert_y", true)
	player.look(Vector2(0, -10))
	_check(up > 0.0 and is_zero_approx(player.get_node("Camera3D").rotation.x), "Invert Y turns the same mouse move the other way")
	Settings.reset_all()
	_check(not player.crouch_toggle and player.get_node("Camera3D").fov == 75.0, "and back to the defaults")
	player.set_crouched(true)
	_check(player.is_crouched() and is_equal_approx(shape.height, player.crouch_body_height), "crouching shrinks the body")
	_check(player.crouch_body_height < preload("res://scripts/store/store_builder.gd").TABLE_SIZE.y - 0.1, "a crouched body fits under a table top")

	# A table top just over the crouched head.
	var top := StaticBody3D.new()
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	box.shape.size = Vector3(1.3, 0.04, 1.3)
	top.add_child(box)
	add_child(top)
	top.global_position = Vector3(50, preload("res://scripts/store/store_builder.gd").TABLE_SIZE.y - 0.02, 50)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not player.can_stand(), "no room to stand under a table")
	player.set_crouched(false)
	_check(player.is_crouched(), "you stay crouched under a table")
	top.free()
	await get_tree().physics_frame
	_check(player.can_stand(), "room to stand once clear")
	player.set_crouched(false)
	_check(not player.is_crouched() and is_equal_approx(shape.height, player.stand_body_height), "standing up restores the body")
	player.free()


func _test_lean_over_table() -> void:
	var store_script := preload("res://scripts/store/store_builder.gd")
	var store: Node3D = store_script.new()
	add_child(store)
	var player: CharacterBody3D = load("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	# Driven by hand below; disabling the node would take it out of physics.
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var center: Vector2 = store_script.TABLE_CENTERS[0]
	var half: float = store_script.TABLE_SIZE.z / 2
	var radius: float = (player.get_node("CollisionShape3D").shape as CapsuleShape3D).radius
	player.global_position = Vector3(center.x, 0, center.y + half + 0.6)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(is_zero_approx(player.lean()), "not leaning away from a table")
	_check(player.collision_layer & Binder.PHYSICS_MASK == 0, "binders don't collide with the player")

	# Walk straight at the table's middle until something stops you.
	for i in 120:
		player.velocity = Vector3(0, 0, -2.0)
		player.move_and_slide()
		await get_tree().physics_frame
	var outside := player.global_position.z - center.y - half
	_check(outside < radius - store_script.TABLE_LEAN + 0.02, "standing, you step in over the table top (%.2f m outside its edge)" % outside)
	_check(outside > radius - store_script.TABLE_LEAN - 0.02, "but no further than a lean")
	_check(player.lean() > 0.95, "leaning all the way in")
	_check(player.can_stand(), "room to stand leaning over a table")

	# Crouched, you still get under it, and can't stand up in the middle.
	player.set_crouched(true)
	for i in 120:
		player.velocity = Vector3(0, 0, -2.0)
		player.move_and_slide()
		if player.global_position.z < center.y:
			break
		await get_tree().physics_frame
	_check(player.global_position.z < center.y, "crouched, you get under the table")
	_check(not player.can_stand(), "no room to stand under the middle of a table")

	# Aiming down at the table from over it hits the table top.
	var hands: Node = player.get_node("Hands")
	player.set_crouched(false)
	player.global_position = Vector3(center.x, 0, center.y + half + radius - store_script.TABLE_LEAN)
	var camera: Camera3D = player.get_node("Camera3D")
	camera.position.y = player.stand_eye_height
	camera.rotation.x = -PI / 2 + 0.05
	await get_tree().physics_frame
	hands._update_aim()
	_check(hands._aim == hands.Aim.SURFACE and absf(hands._aim_point.y - store_script.TABLE_SIZE.y) < 0.01, "you aim at the table top, not what stops the lean")
	player.free()
	store.free()


func _clear_test_saves() -> void:
	for slot in Saves.SLOTS:
		for suffix in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.path(slot) + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVES_TEST_DIR))


func _test_save_files() -> void:
	_clear_test_saves()
	var path := Saves.path("slot1")
	_check(SaveGame.status(path) == SaveGame.Status.EMPTY and not Saves.any_save() and Saves.newest_loadable() == "",
		"with no saves, every slot is empty and there's nothing to continue")
	var shop := {"numbers": PackedInt32Array([3, -1, 7]), "pose": Transform3D(Basis(Vector3.UP, 0.4), Vector3(1, 2, 3)),
		"nested": {"spots": PackedVector3Array([Vector3(0.5, 0.0, 1.0)])}}
	var summary := {"saved_at": 1000.0, "play_time": 3720.0, "organized": 41, "total": 100, "finished": false}
	_check(SaveGame.write(path, summary, shop) == OK and SaveGame.status(path) == SaveGame.Status.OK, "a save writes and reads back")
	var loaded := SaveGame.read(path)
	_check(not loaded.is_empty() and loaded.shop == shop and loaded.summary == summary,
		"everything comes back as it went in, packed arrays and transforms too")
	_check(SaveGame.read_summary(path).get("play_time") == 3720.0 and SaveGame.read_summary(path).get("version") == SaveGame.SAVE_VERSION,
		"the Load list reads the summary and header alone")
	_check(not FileAccess.file_exists(path + ".tmp"), "the temporary file is gone once the save is in place")
	_check(Saves.any_save() and Saves.newest_loadable() == "slot1" and SceneFlow.has_started(),
		"a save means there's a game to continue, and Credits unlocks")
	_check(Saves.describe("slot1").ends_with(" · 1 h 2 min · 41%"), "a slot shows when, how long played and how far along: %s" % Saves.describe("slot1"))
	_check(Saves.describe("slot2") == "Empty", "an empty slot says so")

	summary.saved_at = 2000.0
	SaveGame.write(Saves.path(Saves.AUTOSAVE), summary, shop)
	_check(Saves.newest_loadable() == Saves.AUTOSAVE, "Continue picks the newest save")
	SaveGame.write(path, {"saved_at": 3000.0}, {"second": true})
	_check(FileAccess.file_exists(path + ".bak") and SaveGame.read(path).shop == {"second": true},
		"writing over a save keeps the old one as a backup")
	var garbage := FileAccess.open(path, FileAccess.WRITE)
	garbage.store_string("not a save")
	garbage.close()
	_check(SaveGame.status(path) == SaveGame.Status.OK and SaveGame.read(path).shop == shop,
		"a save that won't read falls back to its backup")

	# A save from another version is listed but can't be loaded.
	var old := FileAccess.open_compressed(Saves.path("slot3"), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	var header := SaveGame.header()
	header.version = SaveGame.SAVE_VERSION - 1
	old.store_var(header)
	old.store_var({"saved_at": 9000.0})
	old.store_var({})
	old.close()
	_check(Saves.status("slot3") == SaveGame.Status.OLD_VERSION and SaveGame.read(Saves.path("slot3")).is_empty(),
		"a save from an older version can't be loaded")
	_check(Saves.describe("slot3") == "From an older version" and Saves.newest_loadable() == Saves.AUTOSAVE,
		"it says so, and Continue skips it even though it's newest")
	var page := SaveSlotsScreen.new()
	add_child(page)
	_check(page.rows["slot3"].load.disabled and not page.rows["slot1"].load.disabled and page.rows["slot2"].load.disabled
		and not page.rows["slot1"].has("save"), "Load Game greys out what can't be loaded, and offers no Save")
	page.free()
	_clear_test_saves()
	_check(not Saves.any_save(), "and the test saves are cleared away")


## A shop saved and loaded is the same shop: every card, binder, the hand,
## Mana and cooldowns, where you stand. Then the same save loaded after the
## card data changed.
func _test_shop_save() -> void:
	Progression.reset()
	Saves.begin_new_game()
	var main: Node3D = load(SceneFlow.SHOP_SCENE).instantiate()
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var pile: PileWorld = main.get_node("Pile")
	var hands: Hands = main.get_node("Player/Hands")
	var player: CharacterBody3D = main.get_node("Player")
	_check(Saves.shop == main, "the shop registers itself to be saved")
	# A new game: nothing on the floor, every binder empty on the shelf.
	_check(Collection.count() == 0 and pile.card_count_on_floor() == 0, "a new game starts with no cards at all")
	_check(pile.binders.size() == CardDatabase.set_count() and pile.binders.all(func(b: Binder) -> bool:
		return b.state == Binder.State.SHELVED and b.shelf_unit.spaces[b.shelf_space] == b.binder and b.contents.card_at(0) < 0),
		"and every binder stands empty in its own shelf space")
	_check(not main.is_finished(pile.binders, main._shelves()), "empty binders on the shelf aren't a finished game")
	_check(main.pockets(pile.binders) == CardDatabase.card_count() - RareCards.count(), "Cards Organized counts every binder pocket")
	_old_start(main)
	var ids := _first_binder_cards()
	var binder := pile.binders[0]
	# Some cards locked in, one in hand, one on a table, one in the air.
	binder.place(pile, Transform3D(Basis(Vector3.UP, 0.3), Vector3(2.0, 0.2, 2.0)), 0)
	for i in 5:
		pile.pick_up(ids[i])
		binder.insert(i, ids[i])
	pile.pick_up(ids[9])
	hands.restore_hand([ids[9]] as Array[int])
	pile.pick_up(ids[10])
	pile.lay_loose(ids[10], Vector3(4.0, 0.75, 3.0), 0.5, false)
	pile.pick_up(ids[11])
	var tossed := TossedCard.new()
	pile.add_child(tossed)
	tossed.launch(ids[11], pile, ShaderMaterial.new(), Transform3D(Basis(), Vector3(6.0, 1.2, 4.0)), Vector3.ZERO, Vector3.ZERO)
	var shelf: ShelfUnit = main._shelves()[0]
	var shelved := pile.binders[1]
	shelf.shelve(shelf.space_for(shelved.binder.set_code), shelved)
	Progression.allow_debt = true
	Progression.buy(4, 0)
	Progression.buy(4, 1)
	Progression.allow_debt = false
	Progression.earn(500)
	player.global_position = Vector3(3.0, 0.1, 5.0)
	player.rotation.y = 1.2
	var before: Dictionary = main.capture_save()
	var before_mana := Progression.mana
	Saves._since_autosave = Settings.autosave_seconds() + 1.0
	Saves._process(0.1)
	Saves.wait_for_save()
	_check(Saves.status(Saves.AUTOSAVE) == SaveGame.Status.OK, "after the Autosave every interval, the autosave is written")
	_check(before.falling.size() == 1, "a card in the air is saved as falling")

	# Through the file and back, as a real save goes.
	_check(Saves.save("slot1", true), "the shop saves to a slot")
	main.free()
	Progression.reset()
	_check(Saves.load_slot("slot1"), "and the slot loads")
	main = load(SceneFlow.SHOP_SCENE).instantiate()
	add_child(main)
	pile = main.get_node("Pile")
	hands = main.get_node("Player/Hands")
	player = main.get_node("Player")
	binder = pile.binders[0]
	_check(binder.is_open() and binder.contents.locked_count == 5 and binder.contents.card_at(6) == -1,
		"the binder comes back open, five cards locked in")
	_check(binder.global_position.distance_to(Vector3(2.0, 0.2, 2.0)) < 0.001, "where it lay")
	_check(hands.held_card_id == ids[9], "the card in hand is back in hand")
	var on_table := pile.loose_card(ids[10])
	_check(on_table != null and not on_table.face_up and on_table.position.is_equal_approx(Vector3(4.0, 0.75, 3.0)),
		"the card on the table lies there again, face down")
	var floor_same := true
	var probe_ids := [ids[20], ids[30], 5000, 12345]
	for id in probe_ids:
		var i: int = id # copies are saved in copy order
		floor_same = floor_same and pile.is_on_floor(id) and pile.card_position(id).is_equal_approx(before.cards.positions[i])
	_check(floor_same, "floor cards lie exactly where they lay, at the same height")
	var same_shelf := pile.binders[1]
	_check(same_shelf.state == Binder.State.SHELVED and same_shelf.shelf_unit != null
		and same_shelf.shelf_unit.shelved[same_shelf.shelf_space] == same_shelf, "the shelved binder is back on its shelf")
	_check(Progression.mana == before_mana and Progression.rank("Harmonize") == 1 and Progression.rank("Spider Climb") == 1,
		"Mana and unlocks come back")
	_check(player.global_position.distance_to(Vector3(3.0, 0.1, 5.0)) < 0.01 and is_equal_approx(player.rotation.y, 1.2),
		"you stand where you stood, looking the same way")
	_check(not pile.is_lying(ids[11]) and main._falling.size() == 1, "the card that was in the air waits to land")
	for i in 4:
		await get_tree().physics_frame
	_check(pile.is_lying(ids[11]), "then lands once physics runs")
	var after: Dictionary = main.capture_save()
	var binders_same: bool = after.binders.keys() == before.binders.keys()
	for code in before.binders:
		for key in ["state", "pockets", "spread"]:
			binders_same = binders_same and after.binders[code][key] == before.binders[code][key]
	_check(binders_same and after.hand == before.hand and after.progression.bought == before.progression.bought
		and after.falling.is_empty(), "saved again, every binder, the hand and the unlocks are the same")

	# Copies are saved by set code and number, in copy order.
	var table: Dictionary = before.copies
	_check(table.set.size() == Collection.count() and table.sets[table.set[ids[3]]] == CardDatabase.get_card(ids[3]).set_code
		and table.number[ids[3]] == CardDatabase.get_card(ids[3]).collector_number, "a save lists every copy by set code and number")

	# The data changes: the last set is gone (as if removed since), so the
	# save has copies of cards that no longer exist, and a binder the data
	# has that the save doesn't know.
	var changed: Dictionary = before.duplicate(true)
	var last_code: String = CardDatabase.sets_in_shelf_order()[-1].code
	var codes: PackedStringArray = changed.copies.sets
	_check(codes.find(last_code) >= 0, "the save has copies of the last set")
	codes[codes.find(last_code)] = "ZZZ"
	changed.copies.sets = codes
	changed.binders.erase(last_code)
	# New furniture over some floor cards, and a table that's gone.
	var furniture := Rect2(0.0, 0.0, 0.0, 0.0)
	var buried: Array[int] = []
	for i in changed.cards.where.size():
		var at: Vector3 = changed.cards.positions[i]
		if changed.cards.where[i] == 0 and buried.size() < 3 and at.x > 3.0 and at.x < 9.0 \
				and CardDatabase.get_card(i).set_code != last_code:
			buried.append(i)
			furniture = Rect2(at.x - 0.05, at.z - 0.05, 0.1, 0.1) if furniture.size == Vector2.ZERO else furniture.expand(Vector2(at.x, at.z))
	var on_gone_table: Vector3 = changed.cards.positions[ids[10]]
	var positions_moved: PackedVector3Array = changed.cards.positions
	positions_moved[ids[10]] = Vector3(on_gone_table.x + 20.0, on_gone_table.y, on_gone_table.z)
	changed.cards.positions = positions_moved
	main.free()
	Saves._pending = changed
	main = load(SceneFlow.SHOP_SCENE).instantiate()
	add_child(main)
	pile = main.get_node("Pile")
	var gone := CardDatabase.cards_in_set(last_code)
	_check(gone.all(func(card: CardData) -> bool: return Collection.copies_of(card.id).is_empty())
		and Collection.count() == table.set.size() - gone.size(), "copies of cards gone from the data are dropped")
	var now := ShopSave.make_copies(changed.copies)
	_check(now[ids[3]] >= 0 and Collection.card(now[ids[3]]) == CardDatabase.get_card(ids[3]), "the rest are the same cards")
	var new_binder: Binder = pile.binders[-1]
	_check(new_binder.binder.set_code == last_code and new_binder.state == Binder.State.SHELVED,
		"a binder the save doesn't know goes in its shelf space")
	_check(pile.binders[0].contents.locked_count == 5, "the rest of the save loads as before")
	var test_pile := PileWorld.new()
	add_child(test_pile)
	test_pile.surfaces = main.get_node("Store").surfaces
	var obstacles_now: Array[Rect2] = main.get_node("Store").obstacles.duplicate()
	obstacles_now.append(furniture.grow(0.05))
	test_pile.restore_cards(main.get_node("Store").floor_bounds(), obstacles_now, changed.cards, now, 1)
	var clear_now := buried.all(func(i: int) -> bool:
		var at := test_pile.card_position(now[i])
		return test_pile.is_on_floor(now[i]) and not furniture.grow(0.05).has_point(Vector2(at.x, at.z)))
	_check(not buried.is_empty() and clear_now, "cards under new furniture move to the nearest clear spot")
	_check(test_pile.is_on_floor(now[ids[10]]), "and a card on a table that's gone lands on the floor")
	_check(test_pile.card_position(now[ids[20]]).is_equal_approx(pile.card_position(now[ids[20]])), "while the rest stay put")
	test_pile.free()
	main.free()
	Progression.reset()
	Saves.begin_new_game()
	_clear_test_saves()


## The rare cards: in the pile with no binder, out of reach of every binder
## ability, hung in their own shadow boxes from either cabinet (with Mana,
## achievements and the note the first time one's picked up), and saved.
func _test_rare_cards() -> void:
	var achievements_path := "user://test_rare_achievements.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(achievements_path))
	Achievements.load_from(achievements_path)
	Progression.reset()
	Saves.begin_new_game()
	var rare := CardDatabase.rare_cards()
	_check(rare.size() == 36 and rare[0].collector_number == 1 and rare[35].collector_number == 36, "36 rare cards, numbered 1 to 36")
	_check(rare[0].id == CardDatabase.card_count() - 36, "after every other card, so no other card's id moves")
	_check(CardDatabase.get_set(RareCards.SET_CODE) not in CardDatabase.sets_in_shelf_order()
		and CardDatabase.all_binders().all(func(b: BinderRange) -> bool: return b.set_code != RareCards.SET_CODE),
		"they have no binder and no shelf space")
	_check(CardDatabase.binder_for(rare[0]) == null and CardDatabase.is_rare(rare[0].id) and not CardDatabase.is_rare(0), "and no binder to belong in")
	var rare_material := ShaderMaterial.new()
	rare_material.shader = preload("res://shaders/held_card.gdshader")
	CardView.apply(rare_material, rare[0].id)
	var own_back: Texture2D = rare_material.get_shader_parameter("back_texture")
	_check(own_back != null and own_back != CardDatabase.card_back and rare_material.get_shader_parameter("has_back") == true,
		"rare cards get their own back")
	CardView.apply(rare_material, rare[1].id)
	_check(rare_material.get_shader_parameter("back_texture") not in [null, own_back, CardDatabase.card_back], "each one its own")
	_check(rare_material.shader == preload("res://shaders/held_foil.gdshader"), "and are foil")
	CardView.apply(rare_material, 0)
	_check(rare_material.get_shader_parameter("back_texture") == CardDatabase.card_back
		and rare_material.shader == preload("res://shaders/held_card.gdshader"), "the same material back on an ordinary card is plain again")

	var main: Node3D = load(SceneFlow.SHOP_SCENE).instantiate()
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var pile: PileWorld = main.get_node("Pile")
	_check(rare.all(func(card: CardData) -> bool: return Collection.copies_of(card.id).is_empty()), "a new game has no rare cards (they're parked)")
	_old_start(main)
	var hands: Hands = main.get_node("Player/Hands")
	var cabinets: Array[DisplayCabinet] = main.get_node("Store").cabinets
	_check(rare.all(func(card: CardData) -> bool: return pile.is_on_floor(card.id)), "given copies, rare cards lie on the floor like any other")
	_check(pile.binder_for(rare[0].id) == null, "no binder in the store is theirs")
	_check(cabinets.size() == 2 and cabinets[0].slot_for(1) == 0 and cabinets[0].slot_for(19) == -1 and cabinets[1].slot_for(19) == 0,
		"cards 1-18 go in the back cabinet, 19-36 in the front one")

	# The first one picked up brings up the note, once.
	var notes := [0]
	hands.rare_card_found.connect(func() -> void: notes[0] += 1)
	hands._aim = Hands.Aim.FLOOR
	hands._aim_floor_card = rare[0].id
	hands._pick_up_aimed()
	await get_tree().process_frame
	var note: RareCardNote = main.find_children("*", "RareCardNote", false, false).front()
	_check(notes[0] == 1 and note != null and get_tree().paused, "the first rare card picked up brings up the note, and stops the game")
	_check(note != null and note.find_child("Text", true, false).text == RareCardNote.TEXT, "it says what to do with it")
	if note != null:
		note.ok_button.pressed.emit()
	_check(not get_tree().paused, "OK goes back in")
	await _finish_glide(hands)

	# Binder magic doesn't touch it.
	_buy_through(1, 1) # Teleport
	_buy_through(4, 2) # Harmonize, Abundance
	Progression.allow_debt = false
	_check(not hands.cast_teleport(), "Teleport fizzles on a rare card")
	_check(hands.cast_abundance().is_empty(), "holding a rare card, Abundance brings nothing")
	_check(hands.held_card_id == rare[0].id and hands.behind.is_empty(), "and it stays in hand")
	var binder := pile.binders[0]
	var pockets := BinderContents.new(binder.binder)
	_check(pockets.insert(0, rare[0].id) == BinderContents.Result.WRONG_POCKET, "no binder pocket takes it")

	# Clicking either cabinet sends it to its own shadow box.
	var mana := Progression.mana
	hands._aim = Hands.Aim.CABINET
	hands._aim_cabinet = cabinets[1]
	hands._use_hand()
	_check(hands.held_card_id < 0, "a click on a cabinet takes the rare card from your hand")
	await _finish_glide(hands)
	_check(cabinets[0].displayed[0] == rare[0].id and cabinets[1].displayed_count() == 0,
		"and it goes into its own shadow box, even from the other cabinet")
	_check(Progression.mana == mana + Progression.CARD_LOCKED, "it pays like a card locked in")
	var first := Achievements.rare_index(1)
	_check(Achievements.is_unlocked(first) and Achievements.title(first) == Achievements.RARE[0][0]
		and not Achievements.is_unlocked(Achievements.all_rare_index()), "and unlocks its own achievement")
	_check(main.cards_organized(pile.binders, cabinets) == 1, "it counts as organized")
	_check(main.find_children("*", "RareCardNote", false, false).is_empty() or notes[0] == 1, "the note doesn't come back")

	# A card from a binder stays in hand.
	var common := _first_binder_cards()[0]
	pile.pick_up(common)
	hands.restore_hand([common] as Array[int])
	hands._aim = Hands.Aim.CABINET
	hands._aim_cabinet = cabinets[0]
	_check(not hands._try_display_held_card() and hands.held_card_id == common, "a card with a binder can't go in a cabinet")
	hands.restore_hand([] as Array[int])
	pile.drop(common, Vector3(3.0, 0.0, 3.0), 0.0)

	# The rest; the last unlocks the achievement for all of them.
	for i in range(1, 36):
		pile.pick_up(rare[i].id)
		hands._display(cabinets[0] if i < 18 else cabinets[1], rare[i].id)
	_check(cabinets.all(func(c: DisplayCabinet) -> bool: return c.is_complete()), "every rare card on display")
	_check(Achievements.is_unlocked(Achievements.rare_index(36)) and Achievements.is_unlocked(Achievements.all_rare_index()),
		"the last unlocks its own achievement and the one for all of them")
	_check(not main.is_finished(pile.binders, main._shelves()), "binders still to do: not finished")
	_check(notes[0] == 1, "the note came up only once")

	# Saved and loaded, they stay on display.
	var saved: Dictionary = main.capture_save()
	_check(saved.cabinets.size() == 36, "a save keeps the cabinets' cards")
	main.free()
	Saves._pending = saved
	main = load(SceneFlow.SHOP_SCENE).instantiate()
	add_child(main)
	pile = main.get_node("Pile")
	cabinets = main.get_node("Store").cabinets
	_check(cabinets.all(func(c: DisplayCabinet) -> bool: return c.is_complete()) and cabinets[1].displayed[17] == rare[35].id,
		"and they load back in their shadow boxes")
	_check(rare.all(func(card: CardData) -> bool: return not pile.is_lying(card.id)), "not on the floor as well")
	main.free()
	Progression.reset()
	Saves.begin_new_game()
	_clear_test_saves()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(achievements_path))
	Achievements.load_from(Achievements.SAVE_PATH)


## Waits for a card gliding to or from the hands to get there.
func _finish_glide(hands: Hands) -> void:
	var frames := 0
	while hands._gliding() and frames < 600:
		await get_tree().process_frame
		frames += 1
	await get_tree().process_frame


func _test_wall_art() -> void:
	var store_script := preload("res://scripts/store/store_builder.gd")
	var store: Node3D = store_script.new()
	add_child(store)
	var frames: Array[WallFrame] = store.wall_frames
	_check(frames.size() == WallArt.count() and frames.size() == 12, "twelve wall art frames, one per WallArt entry (%d)" % frames.size())
	var shelf_top := ShelfUnit.HEIGHT + ShelfUnit.CAP_THICKNESS
	var lamp_top := ReadingCorner.LAMP_HEIGHT
	var ok := true
	var rects: Array[Rect2] = []
	for index in frames.size():
		var frame := frames[index]
		var outer := WallFrame.outer_size(frame.opening, frame.mat, frame.moulding)
		var at := frame.global_position
		var bottom := at.y - outer.y / 2
		if index < 5:
			# Over the shelf: on the back wall, facing the door, above the shelf top.
			ok = ok and is_zero_approx(at.z) and frame.global_basis.z.is_equal_approx(Vector3.BACK) and bottom > shelf_top + 0.15
			ok = ok and at.x - outer.x / 2 > store_script.BACK_SHELF.x and at.x + outer.x / 2 < store_script.BACK_SHELF.y
		else:
			# Over the reading corner: on the left wall, facing into the room.
			ok = ok and is_zero_approx(at.x) and frame.global_basis.z.is_equal_approx(Vector3.RIGHT)
			var across := Vector2(at.z - outer.x / 2, at.z + outer.x / 2)
			var shade := Vector2(store_script.FLOOR_LAMP_AT.y - ReadingCorner.SHADE_RADII.y, store_script.FLOOR_LAMP_AT.y + ReadingCorner.SHADE_RADII.y)
			if across.x < shade.y and across.y > shade.x:
				ok = ok and bottom > lamp_top + 0.05
			rects.append(Rect2(at.z - outer.x / 2, bottom, outer.x, outer.y))
		ok = ok and at.y + outer.y / 2 < store_script.CEILING_HEIGHT - 0.3
	_check(ok, "the frames hang over the shelf and the reading corner, clear of the shelf top, the lamp and the ceiling")
	var apart := true
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			apart = apart and not rects[i].intersects(rects[j])
	_check(apart, "the reading corner's frames don't overlap")
	_check(frames[10].opening.y > frames[10].opening.x and frames[0].opening.x > frames[0].opening.y, "the end frames are portrait, the rest landscape")
	# A frame is empty until filled, then shows its art cropped to fill.
	var frame := frames[0]
	var art: MeshInstance3D = frame.get_node("Art")
	_check(not frame.filled and not art.visible, "a frame starts empty")
	var image := Image.create(400, 100, false, Image.FORMAT_RGB8)
	frame.fill(ImageTexture.create_from_image(image))
	_check(frame.filled and art.visible, "filling it shows the art")
	var crop := WallFrame.cover_crop(Rect2(0, 0, 1, 1), Vector2(400, 100), Vector2(1.375, 1))
	_check(is_equal_approx(crop.size.y, 1.0) and is_equal_approx(crop.size.x, 1.375 / 4.0) and is_equal_approx(crop.get_center().x, 0.5),
		"art wider than its window loses its sides, keeping the middle")
	crop = WallFrame.cover_crop(Rect2(0.1, 0.1, 0.8, 0.4), Vector2(100, 100), Vector2(1, 2))
	_check(is_equal_approx(crop.size.x, 0.4) and is_equal_approx(crop.size.y, 0.4) and is_equal_approx(crop.get_center().x, 0.5),
		"and a region of a scan is cropped within itself")
	store.free()
	# Which card fills a frame: by set code and collector number.
	var card := CardData.new()
	card.set_code = WallArt.LIST[2][2]
	card.collector_number = WallArt.LIST[2][3]
	_check(WallArt.index_of(card) == 2, "a frame's card is found by set and number")
	card.collector_number += 1
	_check(WallArt.index_of(card) == -1, "and no other printing")
	var range_data := CardDatabase.all_binders()[0]
	var ids := _first_binder_cards()
	var binder := Binder.new()
	binder.setup(range_data, Color.RED, null)
	var binders: Array[Binder] = [binder]
	var number := CardDatabase.get_card(ids[4]).collector_number
	_check(not WallArt.is_card_filed(range_data.set_code, number, binders), "a card not in its pocket isn't filed")
	binder.contents.insert(4, ids[4])
	_check(WallArt.is_card_filed(range_data.set_code, number, binders), "a card locked into its pocket is")
	binder.free()
	# Its achievement.
	var path := "user://test_achievements.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Achievements.load_from(path)
	var index := Achievements.wall_art_index(0)
	_check(Achievements.is_wall_art(index) and not Achievements.is_rare(index) and Achievements.is_rare(Achievements.all_rare_index())
		and Achievements.key(index) == "art:01", "the wall art's achievements follow the rare cards'")
	Achievements.wall_art_hung(0)
	_check(Achievements.is_unlocked(index) and Achievements.title(index) == WallArt.LIST[0][0] and Achievements.description(index) == WallArt.LIST[0][1],
		"hanging a frame's art unlocks its achievement")
	var screen := AchievementsScreen.make()
	add_child(screen)
	_check(screen.find_child("WallArt", true, false).get_child_count() == WallArt.count(), "the Achievements page has a row of wall art tiles")
	screen.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Achievements.load_from(Achievements.SAVE_PATH)


func _test_shop_clock() -> void:
	var store_script := preload("res://scripts/store/store_builder.gd")
	var store: Node3D = store_script.new()
	add_child(store)
	var clock: ShopClock = store.clock
	_check(clock != null and clock.global_basis.z.is_equal_approx(Vector3.RIGHT) and clock.global_position.x < ShopClock.DEPTH,
		"the clock stands against the left-hand wall, facing into the room")
	var foot := Vector2(clock.global_position.x, clock.global_position.z)
	_check(store.obstacles.any(func(r: Rect2) -> bool: return r.has_point(foot)), "cards keep clear of it")
	var shelf_end := Rect2(store_script.BACK_SHELF.x, 0, 0.1, ShelfUnit.DEPTH)
	_check(not store.obstacles.any(func(r: Rect2) -> bool: return r.has_point(foot) and r.intersects(shelf_end)), "clear of the shelf")
	_check(clock.is_in_group(ReadingCorner.FURNITURE), "it's furniture, not a surface")
	var default_length: float = Settings.DAY_LENGTHS[Settings.DEFAULTS["day_length"]]
	_check(is_equal_approx(ShopClock.pace(default_length), 1.0) and ShopClock.pace(default_length / 2) > 1.0
		and ShopClock.pace(default_length * 2) < 1.0 and ShopClock.pace(0.0) == 0.0,
		"the pendulum beats seconds at the default day, faster for shorter days, and stops with the clock")
	var day := DayCycle.new()
	day.running = false
	add_child(day)
	clock.day = day
	var length_before: int = Settings.value("day_length")
	Settings.change("day_length", Settings.DAY_LENGTHS.find(0.0))
	day.set_hour(15.5)
	clock.phase = 1.0
	clock._process(0.5)
	var pendulum: Node3D = clock.get_node("Pendulum")
	_check(is_equal_approx(clock.phase, 1.0) and is_equal_approx(pendulum.rotation.z, ShopClock.SWING * sin(1.0)), "stopped, the pendulum holds still")
	var hands := clock.get_children().filter(func(n: Node) -> bool: return n.get_class() == "Node3D" and n.name != "Pendulum")
	_check(hands.size() == 2 and is_equal_approx(hands[0].rotation.z, -3.5 / 12.0 * TAU) and is_equal_approx(hands[1].rotation.z, -0.5 * TAU),
		"the hands show half past three")
	Settings.change("day_length", Settings.DEFAULTS["day_length"])
	clock._process(0.5)
	_check(is_equal_approx(clock.phase, 1.0 + PI / 2), "at the default day, half a second is a quarter of a swing there and back")
	Settings.change("day_length", length_before)
	day.free()
	store.free()


func _test_booster_packs() -> void:
	_check(Controls.label(Controls.RIP) == "Space", "ripping a pack is on Space, got " + Controls.label(Controls.RIP))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var code: String = CardDatabase.sets_in_shelf_order()[0].code
	var rarity_of := func(id: int) -> int:
		return PackContents.BASIC if id >= 500 else id / 100 - 1
	# Made-up pools: commons 100s, uncommons 200s, rares 300s, mythics 400s,
	# basic lands 500s.
	var made_up := func(basics: int) -> Array[Array]:
		return [range(100, 190), range(200, 260), range(300, 340), range(400, 410), range(500, 500 + basics)] as Array[Array]
	var sizes_of := func(from: Array[Array]) -> PackedInt32Array:
		return PackContents.pool_sizes(from)
	var counts_of := func(pack: Array) -> Array:
		var counts := [0, 0, 0, 0, 0]
		for id in pack:
			counts[rarity_of.call(id)] += 1
		return counts
	var unique_but_basics := func(pack: Array) -> bool:
		var seen := {}
		for id in pack:
			if id < 500 and seen.has(id):
				return false
			seen[id] = true
		return true
	var in_reveal_order := func(pack: Array) -> bool:
		var order := pack.map(func(id: int) -> int: return PackContents.REVEAL.find(rarity_of.call(id)))
		var sorted := order.duplicate()
		sorted.sort()
		return order == sorted
	var draw_era := func(kind: String, from: Array[Array]) -> Array[int]:
		return PackContents.draw_from(from, PackContents.era_slots(kind, sizes_of.call(from)), rng)

	# Every era's booster, as it really was.
	_check(PackContents.era("LEA") == "sheets" and PackContents.era("3ED") == "sheets" and PackContents.era("ARN") == "eight"
		and PackContents.era("HML") == "eight" and PackContents.era("ALL") == "twelve" and PackContents.era("10E") == "core_land"
		and PackContents.era("TSP") == "timeshifted" and PackContents.era("MAT") == "epilogue", "the odd early sets keep their own boosters")
	var era_by_date := {}
	for set_data in CardDatabase.sets_in_shelf_order():
		era_by_date[PackContents.era(set_data.code)] = era_by_date.get(PackContents.era(set_data.code), []) + [set_data.release_date]
	_check(era_by_date.get("classic", []).all(func(d: String) -> bool: return d < PackContents.DRAFT_FROM)
		and era_by_date.get("draft", []).all(func(d: String) -> bool: return d >= PackContents.DRAFT_FROM and d < PackContents.PLAY_FROM)
		and era_by_date.get("play", []).all(func(d: String) -> bool: return d >= PackContents.PLAY_FROM), "otherwise the release date picks the booster")

	var classic: Array[int] = draw_era.call("classic", made_up.call(5))
	var counts: Array = counts_of.call(classic)
	_check(classic.size() == 15 and counts == [11, 3, 1, 0, 0], "a 1994-2008 booster: 11 commons, 3 uncommons, a rare, no basic land: %s" % [counts])
	_check(in_reveal_order.call(classic) and rarity_of.call(classic[-1]) == CardData.Rarity.RARE, "handed over commons first, the rare last")
	_check(unique_but_basics.call(classic), "no card twice in one pack")
	var no_mythic_before_alara := true
	for i in 100:
		no_mythic_before_alara = no_mythic_before_alara and counts_of.call(draw_era.call("classic", made_up.call(5)))[CardData.Rarity.MYTHIC] == 0
	_check(no_mythic_before_alara, "no mythics before Shards of Alara")

	var draft: Array[int] = draw_era.call("draft", made_up.call(5))
	counts = counts_of.call(draft)
	_check(draft.size() == 15 and counts[PackContents.BASIC] == 1 and counts[0] == 10 and counts[1] == 3 and counts[2] + counts[3] == 1,
		"a 2008-2023 booster: a basic land, 10 commons, 3 uncommons, a rare or mythic: %s" % [counts])
	_check(rarity_of.call(draft[0]) == PackContents.BASIC and in_reveal_order.call(draft), "the basic land comes first")
	var mythics := 0
	for i in 400:
		mythics += counts_of.call(draw_era.call("draft", made_up.call(5)))[CardData.Rarity.MYTHIC]
	_check(mythics > 20 and mythics < 90, "about one rare slot in %d is a mythic, got %d in 400" % [PackContents.MYTHIC_CHANCE, mythics])
	var small_set: Array[int] = draw_era.call("draft", made_up.call(0))
	_check(small_set.size() == 14 and counts_of.call(small_set)[0] == 10, "a small set with no basics of its own has no land slot: 14 cards")
	var no_mythics_left: Array[Array] = [range(100, 120), range(200, 210), [300], [], [500]]
	_check(draw_era.call("draft", no_mythics_left)[-1] == 300, "a mythic slot with no mythics left takes a rare")

	var lands_in_commons := 0
	var common_slots := 0
	var lands_in_uncommons := 0
	for i in 100:
		var alpha_era: Array[Array] = [range(100, 175), range(200, 295), range(300, 417), [], range(500, 505)]
		var sheets: Array[int] = draw_era.call("sheets", alpha_era)
		_check(sheets.size() == 15 and unique_but_basics.call(sheets), "an Alpha-to-Revised booster is 15 cards, only basics can repeat")
		var sheet_counts: Array = counts_of.call(sheets)
		_check(sheet_counts[2] == 1 and sheet_counts[0] + sheet_counts[1] + sheet_counts[PackContents.BASIC] == 14, "with one rare: %s" % [sheet_counts])
		common_slots += 11
		lands_in_commons += 11 - sheet_counts[0]
		lands_in_uncommons += 3 - sheet_counts[1]
	_check(lands_in_commons > common_slots * 0.3 and lands_in_commons < common_slots * 0.46,
		"basic lands fill the spare places on the common sheet (46 of 121): %d of %d common slots" % [lands_in_commons, common_slots])
	_check(lands_in_uncommons > 300 * 0.12 and lands_in_uncommons < 300 * 0.32, "and on the uncommon sheet (26 of 121): %d of 300" % lands_in_uncommons)

	var eight_ok := true
	for i in 50:
		var eight_counts: Array = counts_of.call(draw_era.call("eight", made_up.call(0)))
		eight_ok = eight_ok and eight_counts[0] == 6 and eight_counts[1] + eight_counts[2] == 2 and eight_counts[3] == 0
	_check(eight_ok, "Arabian Nights to Homelands: 8 cards, 6 commons and 2 off the uncommon sheet, no mythics")
	_check(counts_of.call(draw_era.call("twelve", made_up.call(5))) == [8, 3, 1, 0, 0], "Alliances: 12 cards, 8 commons, 3 uncommons, a rare")
	_check(counts_of.call(draw_era.call("core_land", made_up.call(5))) == [10, 3, 1, 0, 1], "Tenth Edition: 10 commons and a basic land")
	_check(counts_of.call(draw_era.call("timeshifted", made_up.call(5))) == [10, 3, 1, 0, 0], "Time Spiral: 10 commons, the timeshifted card is the TSB binder's")
	var play_ok := true
	for i in 50:
		var play: Array[int] = draw_era.call("play", made_up.call(5))
		var play_counts: Array = counts_of.call(play)
		play_ok = play_ok and play.size() == 14 and play_counts[PackContents.BASIC] == 1 and play_counts[0] >= 7 and play_counts[1] >= 3 \
			and play_counts[2] + play_counts[3] >= 1 and unique_but_basics.call(play) and in_reveal_order.call(play)
	_check(play_ok, "a Play Booster: 14 cards, a land, at least 7 commons, 3 uncommons and a rare or mythic")
	var epilogue_ok := true
	for i in 50:
		var epilogue_counts: Array = counts_of.call(draw_era.call("epilogue", made_up.call(5)))
		epilogue_ok = epilogue_ok and epilogue_counts[0] == 0 and epilogue_counts[1] >= 3 and epilogue_counts[2] + epilogue_counts[3] >= 1 \
			and epilogue_counts.reduce(func(a: int, b: int) -> int: return a + b) == 5
	_check(epilogue_ok, "an Aftermath Epilogue Booster: 5 cards, uncommons and rares, no commons")

	var short: Array[Array] = [[1, 2], [], [], [], []]
	_check(draw_era.call("classic", short).size() == 2, "a set with fewer cards left than a pack gives a smaller pack")
	var no_rares: Array[Array] = [range(1, 16), [], [], [], []]
	_check(draw_era.call("classic", no_rares).size() == 15, "slots of a rarity that's run out take another")
	_check(PackContents.pack_size(code) == PackContents.slots(code).reduce(func(n: int, slot: Dictionary) -> int: return n + slot.count, 0),
		"a pack's size is its slots'")
	_check(Hands.rip_tear(0.0) == 0.0 and Hands.rip_tear(0.5) < 0.5 * Hands.RIP_TEAR_AT_BURST
		and is_equal_approx(Hands.rip_tear(1.0), Hands.RIP_TEAR_AT_BURST), "the tear starts slowly and the burst finishes it")
	_check(preload("res://scripts/main.gd").pack_details(code) == "%s\nBooster Pack" % CardDatabase.get_set(code).name, "a pack in hand shows its set")

	# Product makes new cards: any card of the set, however many copies of
	# it there are already.
	var picked := PackContents.pick_set(rng)
	_check(CardDatabase.cards_in_set(picked).size() >= PackContents.pack_size(picked), "packs are of sets with at least a pack's worth of cards")
	var drawn := PackContents.draw(picked, rng)
	_check(drawn.size() == PackContents.pack_size(picked) and Array(drawn).all(func(id: int) -> bool: return CardDatabase.get_card(id).set_code == picked),
		"a pack of the set, drawn from all its cards")
	var box := PackContents.booster_box(picked, rng)
	var seen_in_box := {}
	var repeats := false
	for box_pack in box:
		var in_pack := {}
		for id in box_pack:
			in_pack[id] = true
			repeats = repeats or seen_in_box.has(id)
		_check(in_pack.size() == box_pack.size(), "no card twice in one pack of a box")
		for id in box_pack:
			seen_in_box[id] = true
	_check(box.size() == PackContents.BOX_PACKS and repeats, "a booster box is %d packs, and cards turn up in more than one" % PackContents.BOX_PACKS)
	var bulk := PackContents.bulk_box(picked, rng)
	var bulk_rarities := [0, 0, 0, 0]
	for id in bulk:
		bulk_rarities[CardDatabase.get_card(id).rarity] += 1
	_check(bulk.size() == PackContents.BULK_SIZE and bulk_rarities[0] > bulk.size() * 0.65 and bulk_rarities[1] > bulk.size() * 0.15
		and bulk_rarities[2] + bulk_rarities[3] < bulk.size() * 0.06, "a bulk box is mostly commons, then uncommons: %s" % [bulk_rarities])

	var only_uncommons := PackContents.bulk_box(picked, rng, 50, [0.0, 1.0, 0.0, 0.0] as Array[float])
	_check(only_uncommons.size() == 50 and Array(only_uncommons).all(func(id: int) -> bool:
		return CardDatabase.get_card(id).rarity == CardData.Rarity.UNCOMMON), "a box's mix can be just uncommons")

	var pile := PileWorld.new()
	add_child(pile)
	Collection.reset()
	pile.setup(Rect2(0, 0, 12, 8), [] as Array[Rect2])
	_check(pile.card_count_on_floor() == 0, "a new floor is empty")
	var tipped := Collection.add_all(bulk)
	_check(not pile.is_lying(tipped[0]), "a new copy is held until it's put somewhere")
	pile.scatter(tipped, 4, [Vector2(6, 4)] as Array[Vector2])
	_check(pile.card_count_on_floor() == bulk.size() and Array(tipped).all(pile.is_on_floor), "a bulk box tips out on the floor")
	var near_spot := 0
	for copy in tipped:
		if Vector2(pile.card_position(copy).x, pile.card_position(copy).z).distance_to(Vector2(6, 4)) < 1.5:
			near_spot += 1
	_check(near_spot > bulk.size() * 0.7, "most of it around where it was tipped (%d)" % near_spot)
	var front := BoosterPack.new()
	front.setup(picked)
	front.lie(pile, Vector3(5, 0, 5), 0.0)
	_check(front.is_lying(), "a pack lies on the floor")

	var hands := Hands.new()
	var camera := Camera3D.new()
	var holder := Node3D.new()
	holder.add_child(camera)
	holder.add_child(hands)
	camera.name = "Camera3D"
	add_child(holder)
	hands.pile = pile
	hands._aim = Hands.Aim.LOOSE_PACK
	hands._aim_pack = front
	hands._use_hand()
	_check(hands.held_pack == front and not front.is_lying(), "clicking a pack lying about takes it")
	_check(not hands.has_room() and not hands._hands_empty(), "a pack fills your hands")
	hands._glide.custom_step(10.0)
	hands._aim = Hands.Aim.FLOOR
	hands._aim_point = Vector3(5, 0, 5)
	front.set_tear(0.2)
	hands._use_hand()
	_check(hands.held_pack == front, "a pack that's started to tear can't be put down")
	var ids := hands.rip_pack()
	_check(ids.size() == PackContents.pack_size(front.set_code) and hands.hand_count() == ids.size(), "ripping puts the pack's cards in your hand")
	_check(ids.all(func(id: int) -> bool: return not pile.is_lying(id) and Collection.card(id).set_code == front.set_code),
		"they're new copies, all of the pack's set")
	_check(ids[0] == tipped.size() and Collection.count() == tipped.size() + ids.size(), "made after the bulk box's copies")
	_check(hands.held_card_id == ids[0] and hands.behind.back() == ids[-1], "commons on top, the rare slot at the back")
	_check(hands.held_pack == null and hands._zoomed and hands.revealing == ids.size() - 1, "the cards are up close, to be revealed")
	var full_size := Hands.zoomed_distance(camera.fov, PileWorld.CARD_SIZE.y)
	_check(hands._emerge == 1.0 and -hands._held_view.position.z > full_size,
		"fresh out of the pack, the cards start further off, the size they were in it")
	hands.reveal_next()
	_check(hands.held_card_id == ids[1] and hands.behind.back() == ids[0] and hands.revealing == ids.size() - 2,
		"Space puts the top card at the back and shows the next")
	_check(hands._zoomed, "the hand stays up close while revealing")
	for i in ids.size() - 2:
		hands.reveal_next()
	_check(hands.held_card_id == ids[-1] and hands.revealing == 0, "the last card shown is the rare slot")
	_check(hands._zoomed, "the rare stays up close")
	hands.press_rip()
	_check(not hands._zoomed and hands.held_card_id == ids[-1], "Space once more lowers the stack into your hand, rare on top")
	hands._set_zoomed(true)
	hands.press_rip()
	_check(hands.held_card_id == ids[0], "after that, Space just shows the next card")
	hands._set_zoomed(false)
	hands.restore_hand([] as Array[int])

	# A booster box: picked up, opened in hand, its packs tip out in a heap;
	# one is picked up and put down again.
	var main_script := preload("res://scripts/main.gd")
	var booster: ProductBox = main_script.place_box(pile, ProductBox.Kind.BOOSTER, picked, Vector3(3, 0, 3), 0.0)
	var box_size := booster.box_size()
	_check(is_equal_approx(box_size.x, 0.152) and is_equal_approx(box_size.y, 0.102) and is_equal_approx(box_size.z, 0.127),
		"a booster box is about 6 by 5 inches and 4 tall")
	_check(booster.get_parent() == pile and booster.details() == "%s\nBooster Box" % CardDatabase.get_set(picked).name, "it stands on the floor")
	hands._aim = Hands.Aim.BOX
	hands._aim_box = booster
	hands._use_hand()
	_check(hands.held_box == booster and not hands.has_room() and not hands._hands_empty(), "clicking a box picks it up")
	hands._glide.custom_step(10.0)
	var lying_packs := func() -> Array:
		return pile.get_children().filter(func(n: Node) -> bool:
			return n is BoosterPack and n.is_lying() and not n.is_queued_for_deletion())
	var before_packs: int = lying_packs.call().size()
	var tipped_packs := hands.open_box(booster)
	_check(hands.held_box == null and booster.is_queued_for_deletion(), "Space opens the box in hand")
	_check(tipped_packs.size() == PackContents.BOX_PACKS and lying_packs.call().size() == before_packs + PackContents.BOX_PACKS
		and tipped_packs.all(func(p: BoosterPack) -> bool: return p.set_code == picked), "its %d packs tip out, lying about" % PackContents.BOX_PACKS)
	_check(not Progression._unlocked_sets.has(picked), "opening a set's product doesn't unlock it")
	var loose_pack: BoosterPack = tipped_packs[0]
	hands._aim = Hands.Aim.LOOSE_PACK
	hands._aim_pack = loose_pack
	hands._use_hand()
	_check(hands.held_pack == loose_pack and not loose_pack.is_lying(), "a pack lying about can be picked up")
	hands._glide.custom_step(10.0)
	hands._aim = Hands.Aim.FLOOR
	hands._aim_point = Vector3(5, 0, 5)
	hands._use_hand()
	_check(hands.held_pack == null and loose_pack.is_lying(), "and put down again")
	hands._glide.custom_step(10.0)

	# A bulk box, opened where it stands: its cards tip out on the floor.
	var bulk_box: ProductBox = main_script.place_box(pile, ProductBox.Kind.BULK, picked, Vector3(8, 0, 4), 0.0)
	_check(is_equal_approx(bulk_box.box_size().x, 0.305) and bulk_box.details().ends_with("Bulk Box"), "a bulk box is about a foot wide")
	hands._aim = Hands.Aim.BOX
	hands._aim_box = bulk_box
	var copies_before := Collection.count()
	var tipped_cards := hands.open_box(bulk_box)
	_check(tipped_cards.size() == PackContents.BULK_SIZE and Collection.count() == copies_before + PackContents.BULK_SIZE
		and tipped_cards.all(pile.is_on_floor), "a bulk box tips %d new cards out on the floor" % PackContents.BULK_SIZE)

	# Product lying about is saved and put back.
	var still_box: ProductBox = main_script.place_box(pile, ProductBox.Kind.BULK, picked, Vector3(10, 0, 2), 0.0)
	var products := ShopSave.snapshot_products(pile, hands, holder)
	_check(products.size() == PackContents.BOX_PACKS + 1 and products.any(func(e: Array) -> bool: return e[0] == "bulk_box"),
		"a save lists the packs and boxes lying about")
	var other_pile := PileWorld.new()
	add_child(other_pile)
	other_pile.setup(Rect2(0, 0, 12, 8), [] as Array[Rect2])
	ShopSave.restore_products(products, other_pile)
	var back_boxes := other_pile.get_children().filter(func(n: Node) -> bool: return n is ProductBox)
	_check(back_boxes.size() == 1 and back_boxes[0].global_position.is_equal_approx(still_box.global_position)
		and other_pile.get_children().filter(func(n: Node) -> bool: return n is BoosterPack and n.is_lying()).size() == PackContents.BOX_PACKS,
		"and they load back where they lay")
	other_pile.free()
	holder.free()
	pile.free()


func _test_laptop() -> void:
	_check(LaptopScreen.clock_text(0.0) == "12:00 AM" and LaptopScreen.clock_text(13.5) == "1:30 PM"
		and LaptopScreen.clock_text(9.084) == "9:05 AM", "the taskbar clock reads like a 90s one")
	_check(LaptopText.story_entries(0).size() == 1 and LaptopText.story_entries(1000).size() == LaptopText.STORY.size(),
		"the story starts with one entry and grows as you sort")
	var sets := LaptopScreen.shop_sets()
	_check(not sets.is_empty() and sets[0].release_date >= sets[-1].release_date
		and sets.all(func(s: SetData) -> bool: return s.code != RareCards.SET_CODE), "the Card Shop sells every set, newest first")

	Collection.reset()
	var main: Node3D = load(SceneFlow.SHOP_SCENE).instantiate()
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hands: Hands = main.get_node("Player/Hands")
	var pile: PileWorld = main.get_node("Pile")
	var laptop: Laptop = main.laptop
	var screen: LaptopScreen = main.laptop_screen
	var store_script := preload("res://scripts/store/store_builder.gd")
	var table: Vector2 = store_script.TABLE_CENTERS[2]
	var table_rect := Rect2(table - Vector2(store_script.TABLE_SIZE.x, store_script.TABLE_SIZE.z) / 2,
		Vector2(store_script.TABLE_SIZE.x, store_script.TABLE_SIZE.z))
	_check(laptop != null and laptop.get_parent() == pile and is_equal_approx(laptop.global_position.y, store_script.TABLE_SIZE.y)
		and table_rect.has_point(Vector2(laptop.global_position.x, laptop.global_position.z)), "a new game puts the laptop on the front left table")
	_check(laptop.global_basis.z.z > 0.8, "its screen faces the door")
	var glow: SpotLight3D = laptop.find_child("Glow", true, false)
	_check(glow != null and not glow.shadow_enabled and glow.light_energy > 0.0 and glow.light_energy < 1.0
		and -glow.global_basis.z.dot(laptop.global_basis.z) > 0.8, "its screen casts a faint glow out in front of it")
	_check(not screen.is_open() and not get_tree().paused, "a shop loaded without New Game doesn't open on the laptop")

	# Aimed at: E uses it, Space doesn't open it, the hint says so.
	var camera: Camera3D = main.get_node("Player/Camera3D")
	var target := laptop.global_position + Vector3.UP * 0.12
	camera.global_transform = Transform3D(Basis(), target + laptop.global_basis.z * 0.8 + Vector3.UP * 0.5).looking_at(target)
	hands._update_aim()
	_check(hands._aim == Hands.Aim.BOX and hands._aim_box == laptop, "the laptop can be aimed at")
	_check(hands._laptop_at_hand() == laptop, "so E would use it")
	var hint := [""]
	hands.hint_changed.connect(func(text: String) -> void: hint[0] = text)
	hands._update_hint()
	_check(hint[0] == "E: Use Laptop", "the hint says E: Use Laptop, got " + hint[0])
	hands.press_rip()
	_check(is_instance_valid(laptop) and not laptop.is_queued_for_deletion() and hands.open_box(laptop).is_empty(),
		"Space doesn't open the laptop like a box")
	hands.laptop_used.emit()
	_check(screen.is_open() and get_tree().paused and screen.message_box == null, "using it opens the laptop screen, no welcome")
	screen.close()
	_check(not screen.is_open() and not get_tree().paused, "Close Laptop goes back into the room")

	# Picked up and put down on another table.
	hands._use_hand()
	_check(hands.held_box == laptop and hands._laptop_at_hand() == laptop, "clicking the laptop picks it up")
	hands._glide.custom_step(10.0)
	_check(ShopSave.snapshot_laptop(pile, hands, main.get_node("Player")) is Transform3D
		and ShopSave.snapshot_products(pile, hands, main.get_node("Player")).is_empty(), "in hand, it's saved, and never as product")
	var other: Vector2 = store_script.TABLE_CENTERS[0]
	hands._aim = Hands.Aim.SURFACE
	hands._aim_point = Vector3(other.x, store_script.TABLE_SIZE.y, other.y)
	hands._use_hand()
	hands._glide.custom_step(10.0)
	_check(hands.held_box == null and laptop.get_parent() == pile
		and Vector2(laptop.global_position.x, laptop.global_position.z).distance_to(other) < 0.3
		and is_equal_approx(laptop.global_position.y, store_script.TABLE_SIZE.y), "and puts it down on another table")
	var pose: Transform3D = ShopSave.snapshot_laptop(pile, hands, main.get_node("Player"))
	_check(pose.is_equal_approx(laptop.global_transform), "a save keeps it where it was put")
	var other_pile := PileWorld.new()
	add_child(other_pile)
	var back: Laptop = main.place_laptop(other_pile, pose)
	_check(back.global_transform.is_equal_approx(pose), "and loads it back there")
	other_pile.free()

	# The Card Shop: an order of each kind is paid for, and turns up inside
	# the door the next morning.
	Progression.money = 0
	screen.open()
	var shop := screen.open_app("shop")
	_check(screen.windows.has("shop") and shop.find_child("Order_bulk_box", true, false) != null, "the Card Shop opens with an Order button per product")
	_check(screen.shop_set == sets[0].code, "the newest set is chosen first")
	var code := sets[0].code
	var order_pack: Button = shop.find_child("Order_pack", true, false)
	_check(order_pack.disabled, "with no money, Order is greyed out")
	var before := pile.get_child_count()
	_check(not screen.order_product("pack", code) and main.orders.is_empty() and screen.shop_status.text.begins_with("Not enough money"),
		"and nothing can be ordered")
	var cost := Prices.product_cents("pack", code) + Prices.product_cents("booster_box", code) + Prices.product_cents("bulk_box", code)
	Progression.earn_money(cost + 123)
	screen.order_product("pack", code)
	screen.order_product("booster_box", code)
	screen.order_product("bulk_box", code)
	_check(Progression.money == 123 and main.orders.size() == 3, "each order is paid for at once, %d left" % Progression.money)
	_check(pile.get_child_count() == before, "and nothing arrives until the morning")
	_check(screen.shop_status.text.begins_with("Ordered: ") and screen.shop_status.text.contains("tomorrow morning"), "the shop says it's on its way")
	_check((shop.find_child("Order_pack", true, false) as Button).disabled, "Order greys out again once you can't afford it")
	var day: int = main.day_number
	main.start_new_day()
	_check(main.orders.is_empty() and main.day_number == day + 1, "a new day empties the orders")
	var arrived := pile.get_children().slice(before)
	var pack: BoosterPack = arrived.filter(func(n: Node) -> bool: return n is BoosterPack).front()
	var boxes := arrived.filter(func(n: Node) -> bool: return n is ProductBox)
	_check(pack != null and pack.is_lying() and pack.set_code == code, "a booster pack arrives, lying inside the door")
	_check(boxes.size() == 2 and boxes.all(func(b: ProductBox) -> bool: return b.set_code == code)
		and boxes.any(func(b: ProductBox) -> bool: return b.kind == ProductBox.Kind.BULK), "and a booster box and a bulk box")
	_check(boxes.all(func(b: ProductBox) -> bool: return b.global_position.z > 6.0 and b.global_position.z < 8.0), "by the door")
	screen.open_app("collection")
	screen.open_app("story")
	screen.open_app("readme")
	_check(screen.windows.size() == 4 and screen.open_app("shop") == shop, "every program opens, once")
	shop.close()
	_check(not screen.windows.has("shop"), "closing a window closes the program")
	screen.close()

	# A New Game opens on the welcome; its OK leaves you on the desktop,
	# pointed at the Read Me, and closing the laptop starts the game.
	screen.open(true)
	_check(screen.message_box != null and get_tree().paused, "the welcome message box is up, the game stopped")
	screen.press_ok()
	_check(screen.is_open() and screen.message_box == null and get_tree().paused and screen.readme_nudge,
		"OK leaves you on the desktop, the Read Me picked out")
	screen.open_app("readme")
	_check(not screen.readme_nudge, "opening the Read Me stops pointing at it")
	screen.close()
	_check(not screen.is_open() and not get_tree().paused, "closing the laptop drops you into the room")
	_check(not SceneFlow.take_opening_request(), "only New Game asks for the welcome")
	main.free()
	get_tree().paused = false
