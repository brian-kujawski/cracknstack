extends Node
## Headless checks for the data layer, the pile, binders and shelving. Run from the project root:
##   godot --headless res://tests/test_runner.tscn
## Exits with code 1 if any check fails.

const SETTINGS_TEST_PATH := "user://test_settings.cfg"
const SAVES_TEST_DIR := "user://test_saves"

var _failures := 0
var _checks := 0


func _ready() -> void:
	# The checks below are written against the placeholder collection, even
	# when real data has been imported locally, and against default settings,
	# saved somewhere other than yours.
	CardDatabase.load_file(CardDatabase.PLACEHOLDER_PATH)
	Settings.save_path = SETTINGS_TEST_PATH
	Settings.reset_all()
	Saves.save_dir = SAVES_TEST_DIR
	_clear_test_saves()
	_test_database_loaded()
	_test_collector_numbers_are_contiguous()
	_test_shelf_order()
	_test_binders_per_set()
	_test_binder_layout()
	_test_card_sort()
	_test_shelf_layout()
	_test_pile()
	_test_pile_clearing()
	_test_pile_stacking()
	_test_pile_grid()
	_test_binder_spreads()
	_test_binder_contents()
	_test_binder_pockets()
	_test_binder_lettering()
	_test_leather_colour()
	_test_shelving()
	_test_loose_card()
	_test_card_corners()
	_test_real_data_format()
	_test_credits()
	_test_inspect_tilt()
	_test_glide()
	_test_controls()
	_test_settings()
	_test_settings_screen()
	_test_onscreen_text()
	_test_pause()
	await _test_title_screen()
	_test_achievements()
	await _test_credits_roll()
	_test_progression()
	_test_upgrade_menu()
	_test_sorcery_recharge()
	_test_step_one_upgrades()
	_test_demonic_tutor()
	await _test_step_two_upgrades()
	await _test_step_three_upgrades()
	await _test_step_four_upgrades()
	await _test_steps_five_to_seven()
	_test_day_cycle()
	_test_display_cabinets()
	await _test_crouch()
	await _test_lean_over_table()
	await _test_table_cards()
	_test_save_files()
	await _test_shop_save()
	CardDatabase.load_file(CardDatabase.PLACEHOLDER_PATH)
	_clear_test_saves()
	DirAccess.remove_absolute(SETTINGS_TEST_PATH)
	print("%d checks, %d failed" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func _test_database_loaded() -> void:
	_check(CardDatabase.set_count() == 150, "expected 150 placeholder sets, got %d" % CardDatabase.set_count())
	_check(CardDatabase.card_count() > 25000 and CardDatabase.card_count() < 35000,
		"expected ~30k placeholder cards, got %d" % CardDatabase.card_count())


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
	for card in [CardDatabase.get_card(0), CardDatabase.get_card(CardDatabase.card_count() - 1)]:
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
		fits = fits and absf(layout.widths[i] - BinderLayout.thickness(few[i]) - ShelfLayout.SPACE_GAP) < 0.0001
		fits = fits and ((left >= bays[0].x and right <= bays[0].y) or (left >= bays[1].x and right <= bays[1].y))
		if i > 0:
			var same_shelf := layout.shelves[i] == layout.shelves[i - 1]
			fits = fits and layout.shelves[i] >= layout.shelves[i - 1]
			fits = fits and (not same_shelf or left >= layout.lefts[i - 1] + layout.widths[i - 1] - 0.0001)
		fill[layout.shelves[i]] += layout.widths[i]
	_check(fits, "spaces are as wide as their binder, in order, never overlapping or straddling a divider")
	_check(layout.shelves[0] == 0 and layout.shelves[-1] == 1 and absf(fill[0] - fill[1]) < 0.15,
		"the binders split evenly over both shelves (%.2f m and %.2f m)" % fill)

	var eight: Array[BinderRange] = []
	eight.assign(few.slice(0, 8))
	var cramped := ShelfLayout.plan(eight, 1, [Vector2(0.0, 0.5)] as Array[Vector2])
	_check(cramped.binders.size() < 8 and cramped.binders.size() > 0, "binders that don't fit are left out (with an error)")

	var full := ShelfLayout.plan(binders, ShelfUnit.SHELF_HEIGHTS.size(), [Vector2(0.0, 7.9)] as Array[Vector2])
	_check(full.binders.size() == binders.size(), "every binder fits on the back wall's shelves (%d of %d)" % [full.binders.size(), binders.size()])


func _test_pile() -> void:
	var pile := PileWorld.new()
	add_child(pile)
	var obstacle := Rect2(10, 5, 2, 2)
	var obstacles: Array[Rect2] = [obstacle]
	pile.build(Rect2(0, 0, 28, 14), obstacles, 7)
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


func _test_pile_clearing() -> void:
	var pile := PileWorld.new()
	add_child(pile)
	var no_obstacles: Array[Rect2] = []
	pile.build(Rect2(0, 0, 28, 14), no_obstacles, 7)

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
	pile.build(bounds, no_obstacles, 11)
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
	pile.build(Rect2(0, 0, 28, 14), no_obstacles, 7)

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
	_check(contents.take(0) == -1 and contents.card_at(0) == ids[0], "a locked card can't be taken out")
	_check(contents.insert(0, ids[1]) == BinderContents.Result.OCCUPIED, "a full pocket refuses another card")
	_check(contents.insert(2, ids[1]) == BinderContents.Result.MISPLACED, "a card in the wrong pocket stays unlocked")
	_check(contents.insert(1, ids[2]) == BinderContents.Result.MISPLACED, "and blocks the rightful owner's neighbour")
	var other_set := CardDatabase.cards_in_set(CardDatabase.sets_in_shelf_order()[1].code)[3]
	_check(contents.insert(3, other_set.id) == BinderContents.Result.MISPLACED,
		"a card from another set never locks, even at the same number")
	_check(contents.take(2) == ids[1] and contents.card_at(2) == -1, "a misplaced card can be taken back out")
	_check(contents.take(1) == ids[2] and contents.take(3) == other_set.id, "every misplaced card comes back out")
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

	_check(binder.insert(9, ids[10]) == BinderContents.Result.MISPLACED, "filing into the wrong pocket through the binder")
	_check(binder.take(9) == ids[10], "taking the misplaced card back out")
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
		spaced = spaced and spots[i] > spots[i - 1] and spots[i] - spots[i - 1] <= ShelfUnit.LEG_SPACING + ShelfUnit.BAY_WIDTH / 2
	_check(spaced and spots[0] < -1.1 and spots[-1] > 1.1, "leg pairs stand under both ends and along the span")
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
## A tiny atlas: 4 × 2 slots of 16 × 22 px on 64 px pages, so 10 cards need two pages.
const FIXTURE_FACES := {"pages": ["faces/page_0.png", "faces/page_1.png"], "page_size": 64,
	"slot_size": [16, 22], "columns": 4, "rows": 2}
const FIXTURE_CARDS := 10


## Writes a small data file shaped like tools/import_scryfall.py's output,
## with made-up cards: each face is a flat colour whose red channel is
## (card id + 1) × 20.
func _write_fixture(with_pages := true) -> String:
	DirAccess.make_dir_recursive_absolute(FIXTURE_DIR + "/faces")
	DirAccess.make_dir_recursive_absolute(FIXTURE_DIR + "/images/tst")
	var rows := []
	for id in FIXTURE_CARDS:
		var face := Image.create(48, 66, false, Image.FORMAT_RGB8)
		face.fill(Color8((id + 1) * 20, 100, 50))
		face.save_png("%s/images/tst/%d.png" % [FIXTURE_DIR, id + 1])
		rows.append(["TST", id + 1, "Test Card %d" % (id + 1), "rare", ["G"], "Creature — Bear", "images/tst/%d.png" % (id + 1)])
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
	_check(CardDatabase.is_real_data() and CardDatabase.card_count() == FIXTURE_CARDS, "real data replaces the placeholders")
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
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/held_card.gdshader")
	CardView.apply(material, 9)
	_check(material.get_shader_parameter("has_face") == true, "single-card materials switch to the real face")
	_check(CardDatabase.card_back != null and CardDatabase.card_back.get_size() == Vector2(48, 66), "the card back loads")
	_check(material.get_shader_parameter("has_back") == true, "single-card materials get the real card back")

	# One set, one binder: one labelled shelf space, the rest blank.
	var layout := ShelfLayout.plan(CardDatabase.all_binders(), 2, [Vector2(0.0, 7.9)] as Array[Vector2])
	_check(layout.binders.size() == 1 and layout.binders[0] == CardDatabase.all_binders()[0], "one set gets one labelled shelf space")

	# The pile hands each card's atlas slot to the floor shader (in the
	# instance colour's alpha; the headless renderer keeps no buffers to check).
	var pile := PileWorld.new()
	add_child(pile)
	var no_obstacles: Array[Rect2] = []
	pile.build(Rect2(0, 0, 4, 4), no_obstacles, 3)
	_check(pile.card_count_on_floor() == FIXTURE_CARDS, "the whole real set is on the floor")
	var faces_ok := true
	for id in FIXTURE_CARDS:
		faces_ok = faces_ok and pile._faces[id] == id
	_check(faces_ok, "floor cards carry their face atlas slot")
	_check(pile._material.get_shader_parameter("has_back") == true, "face-down floor cards show the real card back")
	pile.free()

	# A missing page falls back to placeholder faces rather than failing.
	path = _write_fixture(false)
	_check(CardDatabase.load_file(path) == OK and CardDatabase.face_atlas == null, "missing atlas pages fall back to placeholder faces")
	_check(CardDatabase.get_card(0).face_index == -1, "and cards stop pointing into the atlas")
	_write_fixture()


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

	Settings.change("quality", 0)
	_check(Settings.value("render_scale") == 2 and Settings.value("shadows") == 0 and Settings.value("anti_aliasing") == 0,
		"Low sets the three quality rows")
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
	_check(main.card_details(card) == "%s\n%s\n%s #004/%s\n%s" % [card.name, set_data.name, set_data.code,
		set_data.number_text(set_data.card_count), CardData.Rarity.keys()[card.rarity].capitalize()],
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
	_check(Achievements.count() == nodes.size(), "one achievement per card the upgrade tree is named after: %d" % Achievements.count())
	var matches := true
	for index in Achievements.count():
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
	_check(Progression.mana == 0, "a misplaced card earns nothing")
	binder.take(1)
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

	# Remember the Fallen: a card you've held, seen again on the floor or
	# misplaced in a pocket.
	var binder := Binder.new()
	binder.setup(CardDatabase.all_binders()[0], Color.RED, null)
	add_child(binder)
	binder.put_down(self, Vector3(4.0, 0.75, 2.0), 0.0)
	binder.open()
	var ids := _first_binder_cards()
	binder.insert(0, ids[1]) # Misplaced.
	hands.seen_cards[ids[1]] = true
	hands.seen_cards[ids[5]] = true
	hands._aim = Hands.Aim.FLOOR
	hands._aim_floor_card = ids[5]
	_check(hands.shown_card_id() == -1, "without Remember the Fallen, a floor card is a mystery")
	hands._aim = Hands.Aim.BINDER
	hands._aim_binder = binder
	hands._aim_pocket = 0
	_check(hands.shown_card_id() == -1, "and so is a misplaced card")

	_buy_through(0, 0) # Remember the Fallen
	_buy_through(1, 0) # Snap I
	_buy_through(3, 0) # Fervor
	_buy_through(4, 0) # Spider Climb
	_check(hands.shown_card_id() == ids[1], "Remember the Fallen names a misplaced card you've held")
	hands._aim = Hands.Aim.FLOOR
	_check(hands.shown_card_id() == ids[5], "and a floor card you've held")
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
	binder.free()
	Progression.reset()
	Progression.allow_debt = OS.is_debug_build()


func _test_demonic_tutor() -> void:
	Progression.reset()
	var pile := PileWorld.new()
	add_child(pile)
	pile.build(Rect2(0, 0, 12, 8), [] as Array[Rect2], 3)
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
	binder.insert(1, ids[2]) # Misplaced in the wrong pocket.
	hands._aim_pocket = 1
	_check(not hands.cast_demonic_tutor(), "a pocket that isn't empty can't be tutored for")
	hands._aim_pocket = 2
	_check(hands.cast_demonic_tutor() and hands.held_card_id == ids[2] and binder.contents.card_at(1) == -1,
		"a card misplaced in a pocket comes out of it")
	hands._glide.custom_step(10.0)
	hands._hold(-1)
	Progression.reset()
	_buy_through(2, 0)
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
	pile.build(Rect2(0, 0, 12, 8), [] as Array[Rect2], 5)
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
	pile.build(Rect2(0, 0, 12, 8), [] as Array[Rect2], 9)
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
	pile.build(Rect2(0, 0, 12, 8), [] as Array[Rect2], 11)
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
	pile.build(Rect2(0, 0, 12, 8), [] as Array[Rect2], 13)
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
	pile.build(Rect2(0, 0, 12, 8), [] as Array[Rect2], 11)
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


## Runs every tossed card in the pile until it lands.
func _land_tossed(pile: PileWorld) -> void:
	for child in pile.get_children():
		if child is TossedCard:
			var steps := 0
			while not child.is_queued_for_deletion() and steps < 600:
				child._physics_process(1.0 / 60.0)
				steps += 1
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
	_check(slots[0].global_position.y > slots[DisplayCabinet.COLUMNS].global_position.y, "top row first")
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
	var ids := _first_binder_cards()
	var binder := pile.binders[0]
	# Some cards locked in, one misplaced, one in hand, one on a table, one
	# in the air.
	binder.place(pile, Transform3D(Basis(Vector3.UP, 0.3), Vector3(2.0, 0.2, 2.0)), 0)
	for i in 5:
		pile.pick_up(ids[i])
		binder.insert(i, ids[i])
	pile.pick_up(ids[7])
	binder.insert(6, ids[7])
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
	_check(binder.is_open() and binder.contents.locked_count == 5 and binder.contents.card_at(6) == ids[7]
		and not binder.contents.is_locked(6), "the binder comes back open, five cards locked in and one misplaced")
	_check(binder.global_position.distance_to(Vector3(2.0, 0.2, 2.0)) < 0.001, "where it lay")
	_check(hands.held_card_id == ids[9], "the card in hand is back in hand")
	var on_table := pile.loose_card(ids[10])
	_check(on_table != null and not on_table.face_up and on_table.position.is_equal_approx(Vector3(4.0, 0.75, 3.0)),
		"the card on the table lies there again, face down")
	var floor_same := true
	var probe_ids := [ids[20], ids[30], 5000, 12345]
	for id in probe_ids:
		var i := ShopSave.card_order().find(id)
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
		for key in ["state", "pockets", "locked", "spread"]:
			binders_same = binders_same and after.binders[code][key] == before.binders[code][key]
	_check(binders_same and after.hand == before.hand and after.progression.bought == before.progression.bought
		and after.falling.is_empty(), "saved again, every binder, the hand and the unlocks are the same")

	# The data changes: the last set is gone from the save (as if imported
	# since), and the save has a set that's no longer in the data.
	var changed: Dictionary = before.duplicate(true)
	var codes: PackedStringArray = changed.sets.codes
	var counts_saved: PackedInt32Array = changed.sets.counts
	var last_code := codes[codes.size() - 1]
	var last_count := counts_saved[counts_saved.size() - 1]
	var keep := ShopSave.card_order().size() - last_count
	codes.remove_at(codes.size() - 1)
	counts_saved.remove_at(counts_saved.size() - 1)
	codes.append("ZZZ")
	counts_saved.append(2)
	changed.sets = {"codes": codes, "counts": counts_saved}
	for key in ["where", "positions", "rotations", "face_up"]:
		var values = changed.cards[key].slice(0, keep)
		values.append_array(changed.cards[key].slice(0, 2))
		changed.cards[key] = values
	changed.binders.erase(last_code)
	# New furniture over some floor cards, and a table that's gone.
	var furniture := Rect2(0.0, 0.0, 0.0, 0.0)
	var buried: Array[int] = []
	var order_now := ShopSave.card_order()
	for i in keep:
		var at: Vector3 = changed.cards.positions[i]
		if changed.cards.where[i] == 0 and buried.size() < 3 and at.x > 3.0 and at.x < 9.0:
			buried.append(order_now[i])
			furniture = Rect2(at.x - 0.05, at.z - 0.05, 0.1, 0.1) if furniture.size == Vector2.ZERO else furniture.expand(Vector2(at.x, at.z))
	var on_gone_table: Vector3 = changed.cards.positions[order_now.find(ids[10])]
	var moved_table_card := order_now.find(ids[10])
	var positions_moved: PackedVector3Array = changed.cards.positions
	positions_moved[moved_table_card] = Vector3(on_gone_table.x + 20.0, on_gone_table.y, on_gone_table.z)
	changed.cards.positions = positions_moved
	main.free()
	Saves._pending = changed
	main = load(SceneFlow.SHOP_SCENE).instantiate()
	add_child(main)
	pile = main.get_node("Pile")
	var new_cards := CardDatabase.cards_in_set(last_code)
	var all_down := new_cards.all(func(card: CardData) -> bool: return pile.is_on_floor(card.id))
	_check(all_down, "a set the save doesn't know is scattered on the pile")
	var new_binder: Binder = pile.binders[-1]
	_check(new_binder.binder.set_code == last_code and new_binder.is_inside_tree() and new_binder.state == Binder.State.CLOSED,
		"and its binder is dropped on top")
	_check(pile.binders[0].contents.locked_count == 5, "the rest of the save loads as before")
	var test_pile := PileWorld.new()
	add_child(test_pile)
	test_pile.surfaces = main.get_node("Store").surfaces
	var obstacles_now: Array[Rect2] = main.get_node("Store").obstacles.duplicate()
	obstacles_now.append(furniture.grow(0.05))
	test_pile.restore_cards(main.get_node("Store").floor_bounds(), obstacles_now, changed.cards, ShopSave.id_map(changed.sets), 1)
	var clear_now := buried.all(func(id: int) -> bool:
		var at := test_pile.card_position(id)
		return test_pile.is_on_floor(id) and not furniture.grow(0.05).has_point(Vector2(at.x, at.z)))
	_check(not buried.is_empty() and clear_now, "cards under new furniture move to the nearest clear spot")
	_check(test_pile.is_on_floor(ids[10]), "and a card on a table that's gone lands on the floor")
	_check(test_pile.card_position(ids[20]).is_equal_approx(pile.card_position(ids[20])), "while the rest stay put")
	test_pile.free()
	main.free()
	Progression.reset()
	Saves.begin_new_game()
	_clear_test_saves()
