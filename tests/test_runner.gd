extends Node
## Headless checks for the data layer, the pile, binders and shelving. Run from the project root:
##   godot --headless res://tests/test_runner.tscn
## Exits with code 1 if any check fails.

var _failures := 0
var _checks := 0


func _ready() -> void:
	_test_database_loaded()
	_test_collector_numbers_are_contiguous()
	_test_shelf_order()
	_test_binder_ranges()
	_test_binder_layout()
	_test_card_sort()
	_test_shelf_layout()
	_test_pile()
	_test_binder_spreads()
	_test_binder_contents()
	_test_binder_pockets()
	_test_shelving()
	_test_unsorted_stack()
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


func _test_binder_ranges() -> void:
	var small := SetData.new()
	small.code = "TST"
	small.name = "Test Set"
	small.card_count = 269
	small.build_binder_ranges(360)
	_check(small.binder_ranges.size() == 1, "269 cards should fit one binder")
	_check(small.binder_ranges[0].label == "Test Set, 1–269", "single-volume label: " + small.binder_ranges[0].label)

	var big := SetData.new()
	big.code = "BIG"
	big.name = "Big Set"
	big.card_count = 700
	big.build_binder_ranges(360)
	_check(big.binder_ranges.size() == 2, "700 cards should need two binders")
	_check(big.binder_ranges[1].label == "Big Set, Vol. 2 (361–700)", "volume label: " + big.binder_ranges[1].label)
	_check(big.binder_for(360).volume == 1 and big.binder_for(361).volume == 2, "binder_for picks the right volume")
	_check(big.binder_for(701) == null, "out-of-range number has no binder")


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

	var volume_two := BinderRange.new()
	volume_two.first = 361
	volume_two.last = 700
	_check(BinderLayout.page_of(volume_two, 361) == 0 and BinderLayout.pocket_of(volume_two, 361) == 0,
		"each volume starts at page 0 pocket 0")


func _test_card_sort() -> void:
	var first_set := CardDatabase.sets_in_shelf_order()[0]
	var last_set := CardDatabase.sets_in_shelf_order()[-1]
	var a := CardDatabase.cards_in_set(first_set.code)[5]
	var b := CardDatabase.cards_in_set(first_set.code)[6]
	var c := CardDatabase.cards_in_set(last_set.code)[0]
	_check(CardSort.compare(a, b) and not CardSort.compare(b, a), "lower collector number sorts first")
	_check(CardSort.compare(b, c), "earlier set sorts before later set regardless of number")


func _test_shelf_layout() -> void:
	_check(ShelfLayout.slot_for_index(0) == Vector3i(0, 0, 0), "first binder is top-left of the first unit")
	_check(ShelfLayout.slot_for_index(11) == Vector3i(0, 0, 11), "binder 12 ends the top shelf")
	_check(ShelfLayout.slot_for_index(12) == Vector3i(0, 1, 0), "binder 13 starts the second shelf")
	_check(ShelfLayout.slot_for_index(60) == Vector3i(1, 0, 0), "binder 61 starts the next unit")

	var binders := CardDatabase.all_binders()
	var unit_count := ShelfLayout.units_needed(binders.size())
	var units := ShelfLayout.assign(binders, unit_count)
	var seen := 0
	var previous: BinderRange = null
	var in_order := true
	for unit in units:
		for binder in unit:
			if binder == null:
				continue
			seen += 1
			if previous != null:
				var prev_set := CardDatabase.get_set(previous.set_code)
				var this_set := CardDatabase.get_set(binder.set_code)
				var same_set_later_volume: bool = previous.set_code == binder.set_code and previous.volume < binder.volume
				in_order = in_order and (same_set_later_volume or CardSort.compare_sets(prev_set, this_set))
			previous = binder
	_check(seen == binders.size(), "every binder gets exactly one shelf space (%d of %d)" % [seen, binders.size()])
	_check(in_order, "shelf spaces read in release-date order")


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

	# Pick up the top card: it leaves the floor and its neighbours slide toward the gap.
	var gap := pile.card_position(top)
	pile.pick_up(top)
	_check(not pile.is_on_floor(top) and pile.card_count_on_floor() == total - 1, "picked-up card leaves the floor")
	_check(pile.top_card_at(gap) != top, "picked-up card can't be picked again")
	var sliding: Array = pile._slides.keys()
	_check(sliding.size() <= PileWorld.GAP_FILL_MAX_CARDS, "gap fill moves at most %d cards (moved %d)" % [PileWorld.GAP_FILL_MAX_CARDS, sliding.size()])
	var before := {}
	for id in sliding:
		before[id] = Vector2(pile.card_position(id).x, pile.card_position(id).z).distance_to(Vector2(gap.x, gap.z))
	pile._process(1.0)
	var all_closer := true
	for id in sliding:
		var after := Vector2(pile.card_position(id).x, pile.card_position(id).z).distance_to(Vector2(gap.x, gap.z))
		all_closer = all_closer and after < before[id]
	_check(all_closer, "gap-fill neighbours end closer to the gap")
	_check(pile._slides.is_empty(), "gap fill finishes and does not chain")

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
	binder.put_down(self, Vector3(4.0, 0.75, 2.0), 0.6, false)
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


func _test_shelving() -> void:
	var ranges := CardDatabase.all_binders()
	var unit := ShelfUnit.new()
	unit.build(ShelfLayout.assign(ranges, ShelfLayout.units_needed(ranges.size()))[0], StandardMaterial3D.new())
	add_child(unit)
	unit.position = Vector3(3, 0, 1)
	unit.rotation.y = PI / 2

	var space_point := unit.to_global(unit.space_position(0, 1) + Vector3(0, 0.1, ShelfUnit.DEPTH / 2))
	_check(unit.space_at(space_point) == 1, "aiming at the front of the top shelf's second space finds space 1")
	var lower := unit.to_global(unit.space_position(2, 11) + Vector3(0, 0.2, ShelfUnit.DEPTH / 2))
	_check(unit.space_at(lower) == 2 * ShelfLayout.SPACES_PER_SHELF + 11, "a lower shelf's last space")

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
	var spine := right.to_global(Vector3(-Binder.COVER.x / 2, Binder.THICKNESS / 2, 0))
	var spine_local := unit.to_local(spine)
	_check(spine_local.z > ShelfUnit.DEPTH / 2 and absf(spine_local.x - unit.space_position(0, 0).x) < 0.03,
		"the binder stands spine out in its space")
	_check(not unit.is_section_complete(0), "an incomplete binder doesn't light its shelf")

	# Fill every binder on the top shelf, shelve them all: the shelf lights up.
	var shelf_binders: Array[Binder] = [right]
	for space in range(1, ShelfLayout.SPACES_PER_SHELF):
		if unit.spaces[space] == null:
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
	unit.unshelve(0)
	_check(not unit.is_section_complete(0), "taking one down turns it off again")
	unit.queue_free()
	wrong.queue_free()
	for b in shelf_binders:
		if is_instance_valid(b):
			b.queue_free()


func _test_unsorted_stack() -> void:
	var stack := UnsortedStack.new()
	stack.setup(null)
	add_child(stack)
	stack.place(Vector3(1, 0.75, 1), 0.0, false)
	stack.push(10)
	stack.push(20)
	_check(stack.size() == 2 and stack.top_card() == 20, "the last card stacked is on top")
	_check(stack.pop() == 20 and stack.pop() == 10, "cards come off the top first")
	_check(stack.is_queued_for_deletion(), "an empty stack goes away")
