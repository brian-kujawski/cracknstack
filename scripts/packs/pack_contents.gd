class_name PackContents
extends RefCounted
## What's in sealed product, worked out the moment it's opened: which cards
## (card ids, CardData), for Collection to make new copies of. Every card of
## the set can turn up, however many copies of it you already have.
##
## A booster pack is made the way its set's real boosters were (era()):
## a list of slots (slots()), each drawing from the set's cards by rarity
## and from its basic lands (pools()). How many cards, of which rarities,
## and whether there were basic lands at all changed over the years:
##
## - "sheets", Alpha to Revised (1993-94): 15 cards, 11 from the common
##   sheet, 3 from the uncommon sheet, 1 rare. Basic lands filled the spare
##   places on the 121-card common and uncommon sheets, so they turn up in
##   those slots (in Beta about 38% of common slots).
## - "eight", Arabian Nights, Antiquities, The Dark, Fallen Empires,
##   Homelands: 8 cards, 6 commons and 2 from an uncommon sheet that held
##   the scarcer cards too. There was no rare slot: what Scryfall calls rare
##   in these sets were the uncommons printed less often (taken here as half
##   as often as the others).
## - "twelve", Alliances: 12 cards, 8 commons, 3 uncommons, 1 rare.
## - "classic", Legends and Fourth Edition up to Eventide (1994-2008):
##   15 cards, 11 commons, 3 uncommons, 1 rare. Real boosters had no basic
##   lands then (from Fourth Edition basics had their own print sheet and
##   went in starter decks), but their binders still need them, so here a
##   set with basics has a land slot in place of one common, as if it had
##   one (user's call, 2026-11-04). A set without basics keeps the common.
## - "timeshifted", Time Spiral: 10 commons, 3 uncommons, 1 rare, and the
##   pretend land slot (as "classic") where the timeshifted card was: that
##   card belongs in the Timeshifted (TSB) binder.
## - "core_land", Tenth Edition: 10 commons, 3 uncommons, 1 rare, 1 basic.
## - "un", Unglued and Unhinged: 10 cards, 6 commons, 2 uncommons, 1 rare,
##   1 basic.
## - "draft", Shards of Alara (2008) to The Lost Caverns of Ixalan (2023):
##   10 commons, 3 uncommons, a rare that's a mythic one time in
##   MYTHIC_CHANCE, and a basic land. A small set without basics of its own
##   had another set's basic, a checklist or a token there, none of which
##   go in its binder, so its packs hold 14 of its cards.
## - "epilogue", March of the Machine: The Aftermath: 5 cards, 3 uncommons,
##   a rare or mythic, and one more of any of those.
## - "play", Play Boosters, Murders at Karlov Manor (2024) on: 14 cards,
##   7 commons, 3 uncommons, a rare (a mythic one time in
##   PLAY_MYTHIC_CHANCE), a land, a wildcard of any rarity and a foil of any
##   rarity. The game has no foils, so the foil slot is a second wildcard
##   (PLAY_WILDCARD), plain.
##
## No card comes twice in a pack, except basic lands, which were printed
## many times over on a sheet. A slot whose rarity the set doesn't have
## takes the nearest rarity that has; a land slot in a set with no basics
## is left out. A pack is handed over in the order you reveal it: commons,
## uncommons, then the rare or mythic, with the basic land at the very back,
## where it sits in a real pack (user's call, 2026-11-08).
##
## A booster box is BOX_PACKS packs of one set. A bulk box is BULK_SIZE
## cards of one set picked one by one, by rarity in the shares it's given
## (BULK_SHARES by default, mostly commons), and can hold the same card many
## times.

## The pool of a set's basic lands, after its four rarities (CardData.Rarity).
const BASIC := 4
## Pools in the order a pack is handed over.
const REVEAL: Array[int] = [CardData.Rarity.COMMON, CardData.Rarity.UNCOMMON,
	CardData.Rarity.RARE, CardData.Rarity.MYTHIC, BASIC]
## Draft-era boosters: one rare slot in this many is a mythic.
const MYTHIC_CHANCE := 8
## Play Boosters: about one rare slot in this many is a mythic.
const PLAY_MYTHIC_CHANCE := 7
## Lucky Clover (Level 11): draft-era mythics one rare slot in this many
## instead, and Play Boosters' scaled the same way.
const CLOVER_MYTHIC_CHANCE := 6.0
## Once you own this share of a set's cards, each pack slot is this much
## likelier to give a card you don't own yet than one you do (silent, no
## ability), and Demonic Tutor (Level 14) multiplies that by its own.
const NUDGE_FROM := 0.75
const NUDGE_WEIGHT := 1.25
const TUTOR_WEIGHT := 1.2
## Ancestral Recall (Level 17): one pack in this many has a bonus rare slot.
const RECALL_CHANCE := 15
## Cards on an early print sheet (11 x 11). Basic lands filled what the
## set's commons or uncommons left over.
const SHEET := 121
## A Play Booster's two wildcard slots (the second is the foil slot, plain
## here): the chance of each rarity (common, uncommon, rare, mythic). Rough
## figures from published pull rates; tune here.
const PLAY_WILDCARD: Array[float] = [0.5, 0.42, 0.067, 0.011]
## The first set with mythic rares and a basic land in every pack (Shards
## of Alara), and the first with Play Boosters (Murders at Karlov Manor).
const DRAFT_FROM := "2008-10-03"
const PLAY_FROM := "2024-02-09"
## Sets whose boosters don't follow their date's era (see the list above).
const ERA_OF_SET := {
	"LEA": "sheets", "LEB": "sheets", "2ED": "sheets", "3ED": "sheets",
	"ARN": "eight", "ATQ": "eight", "DRK": "eight", "FEM": "eight", "HML": "eight",
	"ALL": "twelve", "TSP": "timeshifted", "10E": "core_land",
	"UGL": "un", "UNH": "un", "MAT": "epilogue",
}

const BOX_PACKS := 36
const BULK_SIZE := 1000
## A bulk box's mix: the share of each rarity, by CardData.Rarity (common,
## uncommon, rare, mythic). Tune them here; they needn't add up to 1, only
## their sizes against each other count. A box of only uncommons would be
## [0, 1, 0, 0]. A share a set has no cards of (mythics in an old set) goes
## to the nearest rarity it has.
const BULK_SHARES: Array[float] = [0.75, 0.23, 0.0175, 0.0025]


## The cards of `code`'s set by rarity (CardData.Rarity), as card ids.
## Basic lands count as commons here.
static func by_rarity(code: String) -> Array[Array]:
	var pools: Array[Array] = [[], [], [], []]
	for card in CardDatabase.cards_in_set(code):
		pools[card.rarity].append(card.id)
	return pools


## The cards of `code`'s set a pack draws from, as card ids: by rarity
## (CardData.Rarity), then its basic lands (BASIC), which aren't in the
## commons.
static func pools(code: String) -> Array[Array]:
	var into: Array[Array] = [[], [], [], [], []]
	for card in CardDatabase.cards_in_set(code):
		into[BASIC if is_basic_land(card) else card.rarity].append(card.id)
	return into


static func is_basic_land(card: CardData) -> bool:
	return card.type_line.begins_with("Basic") and card.type_line.contains("Land")


## Which kind of booster `code`'s set came in (see the list at the top).
static func era(code: String) -> String:
	if ERA_OF_SET.has(code):
		return ERA_OF_SET[code]
	var set_data := CardDatabase.get_set(code)
	var date := set_data.release_date if set_data != null else ""
	if date >= PLAY_FROM:
		return "play"
	if date >= DRAFT_FROM:
		return "draft"
	return "classic"


## A booster pack of `code`'s slots (era_slots()).
static func slots(code: String) -> Array[Dictionary]:
	return era_slots(era(code), pool_sizes(pools(code)))


## The slots of a booster of era `kind` (era()), for a set whose pools()
## hold `sizes` cards: each {count, weights, main, fallback}.
## `weights` maps a pool (CardData.Rarity or BASIC) to how likely the slot
## is to draw from it, among the pools with cards left. `main` is the
## rarity a slot takes the nearest of when none of its pools has, and
## `fallback` false leaves the slot out instead (land slots).
static func era_slots(kind: String, sizes: PackedInt32Array) -> Array[Dictionary]:
	var c := CardData.Rarity.COMMON
	var u := CardData.Rarity.UNCOMMON
	var r := CardData.Rarity.RARE
	var m := CardData.Rarity.MYTHIC
	var list: Array[Dictionary] = []
	match kind:
		"sheets":
			_add(list, 11, {c: sizes[c], BASIC: maxi(SHEET - sizes[c], 0)})
			_add(list, 3, {u: sizes[u], BASIC: maxi(SHEET - sizes[u], 0)})
			_add(list, 1, {r: 1.0})
		"eight":
			_add(list, 6, {c: sizes[c], BASIC: sizes[BASIC]})
			_add(list, 2, {u: 2.0 * sizes[u], r: sizes[r]})
		"twelve":
			_add(list, 8, {c: 1.0})
			_add(list, 3, {u: 1.0})
			_add(list, 1, {r: 1.0})
		"timeshifted":
			_add(list, 1, {BASIC: 1.0}, c)
			_add(list, 10, {c: 1.0})
			_add(list, 3, {u: 1.0})
			_add(list, 1, {r: 1.0})
		"core_land":
			_add(list, 1, {BASIC: 1.0})
			_add(list, 10, {c: 1.0})
			_add(list, 3, {u: 1.0})
			_add(list, 1, {r: 1.0})
		"un":
			_add(list, 1, {BASIC: 1.0})
			_add(list, 6, {c: 1.0})
			_add(list, 2, {u: 1.0})
			_add(list, 1, {r: 1.0})
		"draft":
			_add(list, 1, {BASIC: 1.0})
			_add(list, 10, {c: 1.0})
			_add(list, 3, {u: 1.0})
			_add(list, 1, {r: mythic_chance() - 1.0, m: 1.0})
		"epilogue":
			_add(list, 3, {u: 1.0})
			_add(list, 1, {r: mythic_chance() - 1.0, m: 1.0})
			_add(list, 1, {u: 0.6, r: 0.35, m: 0.05})
		"play":
			_add(list, 1, {BASIC: 1.0})
			_add(list, 7, {c: 1.0})
			_add(list, 3, {u: 1.0})
			_add(list, 2, {c: PLAY_WILDCARD[0], u: PLAY_WILDCARD[1], r: PLAY_WILDCARD[2], m: PLAY_WILDCARD[3]})
			_add(list, 1, {r: play_mythic_chance() - 1.0, m: 1.0})
		_:
			_add(list, 1, {BASIC: 1.0}, c)
			_add(list, 10, {c: 1.0})
			_add(list, 3, {u: 1.0})
			_add(list, 1, {r: 1.0})
	return list


## One rare slot in this many is a mythic, in a draft-era booster: 8, or
## 6 with Lucky Clover.
static func mythic_chance() -> float:
	return CLOVER_MYTHIC_CHANCE if Progression.rank("Lucky Clover") > 0 else float(MYTHIC_CHANCE)


## The same for a Play Booster: about 7, or 5.25 with Lucky Clover.
static func play_mythic_chance() -> float:
	return PLAY_MYTHIC_CHANCE * mythic_chance() / MYTHIC_CHANCE


## How much likelier each pack slot of `code` is to give a card you don't
## own yet than one you do: 1, 1.25 once you own NUDGE_FROM of the set,
## times 1.2 with Demonic Tutor.
static func needed_weight(code: String) -> float:
	var weight := TUTOR_WEIGHT if Progression.rank("Demonic Tutor") > 0 else 1.0
	if owned_share(code) >= NUDGE_FROM:
		weight *= NUDGE_WEIGHT
	return weight


## The share of set `code`'s cards you own at least one copy of (0 for a
## set with no cards).
static func owned_share(code: String) -> float:
	var cards := CardDatabase.cards_in_set(code)
	if cards.is_empty():
		return 0.0
	var owned := 0
	for card in cards:
		if Collection.owns(card.id):
			owned += 1
	return float(owned) / cards.size()


## The cards of `code` you don't own yet: id -> true.
static func unowned(code: String) -> Dictionary:
	var missing := {}
	for card in CardDatabase.cards_in_set(code):
		if not Collection.owns(card.id):
			missing[card.id] = true
	return missing


## A slot of `count` cards. `instead` is the rarity it takes when none of
## its pools has cards; a land slot without one is left out.
static func _add(list: Array[Dictionary], count: int, weights: Dictionary, instead := -1) -> void:
	var main := instead
	for pool in weights:
		if instead < 0 and pool != BASIC and (main < 0 or weights[pool] > weights[main]):
			main = pool
	list.append({count = count, weights = weights, main = main, fallback = main >= 0})


static func pool_sizes(of: Array[Array]) -> PackedInt32Array:
	var sizes := PackedInt32Array()
	for pool in of:
		sizes.append(pool.size())
	return sizes


## How likely `slot` is to draw from each pool, with pools of `sizes`
## cards: {pool: chance}, adding up to 1, or empty when it's left out.
static func slot_chances(slot: Dictionary, sizes: PackedInt32Array) -> Dictionary:
	var weights: Dictionary = slot.weights
	var total := 0.0
	for pool in weights:
		if sizes[pool] > 0:
			total += maxf(weights[pool], 0.0)
	var chances := {}
	if total > 0.0:
		for pool in weights:
			if sizes[pool] > 0 and weights[pool] > 0.0:
				chances[pool] = weights[pool] / total
	elif slot.fallback:
		var nearest := _nearest_rarity(sizes, slot.main)
		if nearest >= 0:
			chances[nearest] = 1.0
	return chances


## How many cards a booster pack of `code` holds.
static func pack_size(code: String) -> int:
	var sizes := pool_sizes(pools(code))
	var count := 0
	for slot in slots(code):
		if not slot_chances(slot, sizes).is_empty():
			count += slot.count
	return count


## Whether the shop and the debug tools make packs of `code`: it has at
## least a pack's worth of cards.
static func sells_packs(code: String) -> bool:
	var size := pack_size(code)
	return size > 0 and CardDatabase.cards_in_set(code).size() >= size


## A booster pack of `code`, in reveal order. Your collection and level
## shape it: see needed_weight() and with_recall().
static func draw(code: String, rng: RandomNumberGenerator) -> PackedInt32Array:
	var weight := needed_weight(code)
	return PackedInt32Array(draw_from(pools(code), with_recall(slots(code), rng), rng,
		weight, unowned(code) if weight != 1.0 else {}))


## BOX_PACKS packs of `code`, each in reveal order.
static func booster_box(code: String, rng: RandomNumberGenerator) -> Array[PackedInt32Array]:
	var from := pools(code)
	var list := slots(code)
	var weight := needed_weight(code)
	var missing := unowned(code) if weight != 1.0 else {}
	var packs: Array[PackedInt32Array] = []
	for i in BOX_PACKS:
		packs.append(PackedInt32Array(draw_from(from.duplicate(true), with_recall(list, rng), rng, weight, missing)))
	return packs


## Ancestral Recall: one pack in RECALL_CHANCE gets a bonus rare slot (a
## mythic as often as any rare slot). `list` itself isn't changed. Without
## it, `list` as it is, and the rng untouched.
static func with_recall(list: Array[Dictionary], rng: RandomNumberGenerator) -> Array[Dictionary]:
	if Progression.rank("Ancestral Recall") == 0 or rng.randi_range(1, RECALL_CHANCE) != 1:
		return list
	var more := list.duplicate()
	_add(more, 1, {CardData.Rarity.RARE: mythic_chance() - 1.0, CardData.Rarity.MYTHIC: 1.0})
	return more


## A bulk box of `count` cards of `code`, in no order, mixed by `shares`
## (see BULK_SHARES).
static func bulk_box(code: String, rng: RandomNumberGenerator, count := BULK_SIZE,
		shares: Array[float] = BULK_SHARES) -> PackedInt32Array:
	var by := by_rarity(code)
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
		var rarity := _nearest_rarity(pool_sizes(by), wanted)
		if rarity < 0:
			break
		var pool: Array = by[rarity]
		cards.append(pool[rng.randi_range(0, pool.size() - 1)])
	return cards


## A pack drawn slot by slot from `from` (pools(): ids by rarity, then
## basic lands), which is emptied as cards are drawn so no card comes
## twice; basic lands stay, as there were many of each on a sheet. In
## reveal order (REVEAL), each pool's cards in the order drawn. Cards in
## `missing` (id -> true) are `weight` times as likely to be picked within
## their pool as the rest.
static func draw_from(from: Array[Array], list: Array[Dictionary], rng: RandomNumberGenerator,
		weight := 1.0, missing := {}) -> Array[int]:
	var drawn: Array[Array] = [[], [], [], [], []]
	for slot in list:
		for i in slot.count:
			var pool_index := _roll_pool(slot_chances(slot, pool_sizes(from)), rng)
			if pool_index < 0:
				continue
			var pool: Array = from[pool_index]
			var at := _pick(pool, rng, weight, missing)
			drawn[pool_index].append(pool[at] if pool_index == BASIC else pool.pop_at(at))
	var pack: Array[int] = []
	for pool_index in REVEAL:
		pack.append_array(drawn[pool_index])
	return pack


## Where in `pool` a slot's card comes from: evenly, or with cards in
## `missing` `weight` times as likely.
static func _pick(pool: Array, rng: RandomNumberGenerator, weight: float, missing: Dictionary) -> int:
	if weight == 1.0 or missing.is_empty():
		return rng.randi_range(0, pool.size() - 1)
	var total := 0.0
	for id in pool:
		total += weight if missing.has(id) else 1.0
	var roll := rng.randf() * total
	for at in pool.size():
		roll -= weight if missing.has(pool[at]) else 1.0
		if roll < 0.0:
			return at
	return pool.size() - 1


static func _roll_pool(chances: Dictionary, rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	var picked := -1
	for pool in chances:
		picked = pool
		if roll < chances[pool]:
			break
		roll -= chances[pool]
	return picked


## A set to make product of, picked at random from every unlocked set with
## a binder that has at least a pack's worth of cards; "" when there's none.
static func pick_set(rng: RandomNumberGenerator) -> String:
	var sets: Array[String] = []
	for set_data in CardDatabase.sets_in_shelf_order():
		if sells_packs(set_data.code) and Progression.is_set_unlocked(set_data.code):
			sets.append(set_data.code)
	return sets[rng.randi_range(0, sets.size() - 1)] if not sets.is_empty() else ""


## The rarity a slot draws from: its own, or else the nearest one with
## cards left, looking down before up (a common for an empty uncommon slot).
## Only the four rarities, never the basic lands. -1 when they're all empty.
static func _nearest_rarity(sizes: PackedInt32Array, wanted: int) -> int:
	for step in 4:
		for rarity in [wanted - step, wanted + step]:
			if rarity >= 0 and rarity < 4 and sizes[rarity] > 0:
				return rarity
	return -1
