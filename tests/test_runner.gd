extends Node
## Headless checks for the data layer. Run from the project root:
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
	tossed.launch(top, pile, ShaderMaterial.new(), start, Vector3(1.6, 1.0, 0.0), TAU)
	var steps := 0
	while is_instance_valid(tossed) and not tossed.is_queued_for_deletion() and steps < 600:
		tossed._physics_process(1.0 / 60.0)
		steps += 1
	var landed := pile.card_position(top)
	_check(pile.is_on_floor(top), "tossed card lands back on the floor (after %d steps)" % steps)
	_check(landed.x > 5.3 and landed.x < 7.5 and absf(landed.z - 5.0) < 0.05, "toss is a gentle lob forward (landed at x=%.2f)" % landed.x)
	pile.queue_free()
