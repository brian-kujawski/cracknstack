extends Node
## Headless checks for the data layer, the pile, binders and shelving. Run from the project root:
##   godot --headless res://tests/test_runner.tscn
## Exits with code 1 if any check fails.

var _failures := 0
var _checks := 0


func _ready() -> void:
	# The checks below are written against the placeholder collection, even
	# when real data has been imported locally.
	CardDatabase.load_file(CardDatabase.PLACEHOLDER_PATH)
	_test_database_loaded()
	_test_collector_numbers_are_contiguous()
	_test_shelf_order()
	_test_binder_ranges()
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
	_test_shelving()
	_test_loose_card()
	_test_real_data_format()
	_test_credits()
	_test_inspect_tilt()
	_test_glide()
	_test_controls()
	_test_onscreen_text()
	_test_pause()
	_test_progression()
	_test_upgrade_menu()
	_test_day_cycle()
	await _test_crouch()
	CardDatabase.load_file(CardDatabase.PLACEHOLDER_PATH)
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
	var binders := CardDatabase.all_binders()
	var few: Array[BinderRange] = []
	few.assign(binders.slice(0, 31))
	var split := ShelfLayout.assign(few, [12, 20, 12] as Array[int])
	_check(split[0].size() == 60 and split[1].size() == 100, "a unit has 5 shelves of its own width")
	_check(split[0][0] == few[0] and split[0][10] == few[10] and split[0][11] == null,
		"the first unit takes the first 11 of 31 binders, top shelf left to right")
	_check(split[1][0] == few[11] and split[2][0] == few[21] and split[2][9] == few[30] and split[2][10] == null,
		"the rest split 10 and 10, in order")
	var wide := ShelfLayout.assign(few, [8] as Array[int])
	_check(wide[0][7] == few[7] and wide[0][8] == few[8], "binders wrap onto the next shelf down")

	var units := ShelfLayout.assign(binders, [54, 79, 54] as Array[int])
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


func _test_shelving() -> void:
	var ranges := CardDatabase.all_binders()
	var unit := ShelfUnit.new()
	unit.build(ShelfLayout.assign(ranges, [12, 12, 12] as Array[int])[0], StandardMaterial3D.new())
	add_child(unit)
	unit.position = Vector3(3, 0, 1)
	unit.rotation.y = PI / 2

	var space_point := unit.to_global(unit.space_position(0, 1) + Vector3(0, 0.1, ShelfUnit.DEPTH / 2))
	_check(unit.space_at(space_point) == 1, "aiming at the front of the top shelf's second space finds space 1")
	var lower := unit.to_global(unit.space_position(2, 11) + Vector3(0, 0.2, ShelfUnit.DEPTH / 2))
	_check(unit.space_at(lower) == 2 * unit.spaces_per_shelf + 11, "a lower shelf's last space")

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
	for space in range(1, unit.spaces_per_shelf):
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
	var units := ShelfLayout.assign(CardDatabase.all_binders(), [54, 79, 54] as Array[int])
	var labelled := 0
	for unit in units:
		labelled += unit.filter(func(b): return b != null).size()
	_check(labelled == 1 and units[0][0] == CardDatabase.all_binders()[0], "one set gets one labelled shelf space")

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
	CardDatabase.load_file(CardDatabase.PLACEHOLDER_PATH)
	_check(Credits.DISCLAIMER in Credits.text() and not "Scryfall" in Credits.text(), "placeholder credits still carry the disclaimer")


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


func _test_onscreen_text() -> void:
	var khans := SetData.new()
	khans.code = "KTK"
	khans.card_count = 269
	_check(khans.number_text(4) == "004" and khans.number_text(269) == "269", "collector numbers are zero-padded to three digits")
	khans.card_count = 1200
	_check(khans.number_text(4) == "0004", "a set past 999 pads to four digits")

	var range_data := CardDatabase.all_binders()[0]
	var set_data := CardDatabase.get_set(range_data.set_code)
	_check(range_data.numbers_text() == "%s #001-%s" % [set_data.code, set_data.number_text(range_data.last)],
		"binder numbers read like KTK #001-269, got " + range_data.numbers_text())

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
	var button: Button = menu.find_children("*", "Button", true, false)[0]
	_check(button.text == "Click to Continue", "the pause screen has a Continue button")
	button.pressed.emit()
	_check(not menu.is_paused() and not get_tree().paused, "the Continue button goes back in")
	menu.free()


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
	unit.build(ShelfLayout.assign(CardDatabase.all_binders(), [12, 12, 12] as Array[int])[0], StandardMaterial3D.new())
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
	_check(DayCycle.DAY_LENGTH == 900.0, "a day lasts 15 minutes")


func _test_crouch() -> void:
	var player: CharacterBody3D = load("res://scenes/player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED # Driven by hand below.
	add_child(player)
	player.global_position = Vector3(50, 0, 50)
	var shape: CapsuleShape3D = player.get_node("CollisionShape3D").shape
	_check(is_equal_approx(shape.height, player.stand_body_height), "the body starts standing height")
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
