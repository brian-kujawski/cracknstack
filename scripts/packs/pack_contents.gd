class_name PackContents
extends RefCounted
## What's in sealed product, worked out the moment it's opened: which cards
## (card ids, CardData), for Collection to make new copies of. Every card of
## the set can turn up, however many copies of it you already have.
##
## A booster pack is SIZE cards with no card twice: one rare slot (a mythic
## one time in MYTHIC_CHANCE, in sets that have mythics), UNCOMMONS
## uncommons and commons for the rest. A slot whose rarity the set doesn't
## have enough of takes the nearest rarity that has. It's handed over in the
## order you reveal it, the way it's done on stream: commons first, then
## uncommons, the rare slot last.
##
## A booster box is BOX_PACKS packs of one set. A bulk box is BULK_SIZE
## cards of one set picked one by one, by rarity in the shares it's given
## (BULK_SHARES by default, mostly commons), and can hold the same card many
## times.

const SIZE := 15
const UNCOMMONS := 3
const MYTHIC_CHANCE := 8
const BOX_PACKS := 36
const BULK_SIZE := 1000
## A bulk box's mix: the share of each rarity, by CardData.Rarity (common,
## uncommon, rare, mythic). Tune them here; they needn't add up to 1, only
## their sizes against each other count. A box of only uncommons would be
## [0, 1, 0, 0]. A share a set has no cards of (mythics in an old set) goes
## to the nearest rarity it has.
const BULK_SHARES: Array[float] = [0.75, 0.23, 0.0175, 0.0025]


## The cards of `code`'s set by rarity (CardData.Rarity), as card ids.
static func by_rarity(code: String) -> Array[Array]:
	var pools: Array[Array] = [[], [], [], []]
	for card in CardDatabase.cards_in_set(code):
		pools[card.rarity].append(card.id)
	return pools


## A booster pack of `code`, in reveal order.
static func draw(code: String, rng: RandomNumberGenerator) -> PackedInt32Array:
	return PackedInt32Array(draw_from(by_rarity(code), set_has_mythics(code), rng))


## BOX_PACKS packs of `code`, each in reveal order.
static func booster_box(code: String, rng: RandomNumberGenerator) -> Array[PackedInt32Array]:
	var pools := by_rarity(code)
	var mythics := set_has_mythics(code)
	var packs: Array[PackedInt32Array] = []
	for i in BOX_PACKS:
		packs.append(PackedInt32Array(draw_from(pools.duplicate(true), mythics, rng)))
	return packs


## A bulk box of `count` cards of `code`, in no order, mixed by `shares`
## (see BULK_SHARES).
static func bulk_box(code: String, rng: RandomNumberGenerator, count := BULK_SIZE,
		shares: Array[float] = BULK_SHARES) -> PackedInt32Array:
	var pools := by_rarity(code)
	var cards := PackedInt32Array()
	var total := 0.0
	for share in shares:
		total += maxf(share, 0.0)
	if total <= 0.0:
		return cards
	for i in count:
		var roll := rng.randf() * total
		var wanted := 0
		while wanted < shares.size() - 1 and roll >= maxf(shares[wanted], 0.0):
			roll -= maxf(shares[wanted], 0.0)
			wanted += 1
		var rarity := _nearest_rarity(pools, wanted)
		if rarity < 0:
			break
		var pool: Array = pools[rarity]
		cards.append(pool[rng.randi_range(0, pool.size() - 1)])
	return cards


## The same as draw() from pools of ids by rarity (they're emptied as cards
## are drawn, so no card comes twice), in reveal order: by the rarity of the
## pool each came from.
static func draw_from(pools: Array[Array], has_mythics: bool, rng: RandomNumberGenerator) -> Array[int]:
	var rare := CardData.Rarity.RARE
	if has_mythics and rng.randi_range(1, MYTHIC_CHANCE) == 1:
		rare = CardData.Rarity.MYTHIC
	var slots: Array[int] = []
	for i in SIZE - 1 - UNCOMMONS:
		slots.append(CardData.Rarity.COMMON)
	for i in UNCOMMONS:
		slots.append(CardData.Rarity.UNCOMMON)
	slots.append(rare)
	# Drawn into a list per rarity, so the pack comes out commons first and
	# the rarest last, each rarity in the order drawn.
	var by_rarity: Array[Array] = [[], [], [], []]
	for wanted in slots:
		var rarity := _nearest_rarity(pools, wanted)
		if rarity < 0:
			break
		var pool: Array = pools[rarity]
		by_rarity[rarity].append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	var pack: Array[int] = []
	for drawn in by_rarity:
		pack.append_array(drawn)
	return pack


static func set_has_mythics(code: String) -> bool:
	for card in CardDatabase.cards_in_set(code):
		if card.rarity == CardData.Rarity.MYTHIC:
			return true
	return false


## A set to make product of, picked at random from every set with a binder
## that has at least a pack's worth of cards; "" when there's none.
static func pick_set(rng: RandomNumberGenerator) -> String:
	var sets: Array[String] = []
	for set_data in CardDatabase.sets_in_shelf_order():
		if CardDatabase.cards_in_set(set_data.code).size() >= SIZE:
			sets.append(set_data.code)
	return sets[rng.randi_range(0, sets.size() - 1)] if not sets.is_empty() else ""


## The rarity a slot draws from: its own, or else the nearest one with
## cards left, looking down before up (a common for an empty uncommon slot).
## -1 when every pool is empty.
static func _nearest_rarity(pools: Array[Array], wanted: int) -> int:
	for step in pools.size():
		for rarity in [wanted - step, wanted + step]:
			if rarity >= 0 and rarity < pools.size() and not pools[rarity].is_empty():
				return rarity
	return -1
