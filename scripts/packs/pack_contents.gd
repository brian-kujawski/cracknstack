class_name PackContents
extends RefCounted
## What's in a booster pack, worked out the moment it's ripped open.
##
## A prototype: there are no duplicates yet, so a pack is made of cards
## still lying about (on the floor or a table) from its set, which leave the
## pile and come to hand. A pack is SIZE cards: one rare slot (a mythic one
## time in MYTHIC_CHANCE, in sets that have mythics), UNCOMMONS uncommons and
## commons for the rest. A slot whose rarity has run out takes the nearest
## rarity that hasn't, so a pack is always full while its set has SIZE cards
## lying about, and a smaller pack after that.
##
## The pack is handed over in the order you reveal it, the way it's done on
## stream: commons first, then uncommons, the rare slot last.

const SIZE := 15
const UNCOMMONS := 3
const MYTHIC_CHANCE := 8


## The cards of `code`'s set lying about in `pile`, by rarity (CardData.Rarity).
static func lying_by_rarity(pile: PileWorld, code: String) -> Array[Array]:
	var pools: Array[Array] = [[], [], [], []]
	for card in CardDatabase.cards_in_set(code):
		if pile.is_lying(card.id):
			pools[card.rarity].append(card.id)
	return pools


## How many cards of `code`'s set are lying about.
static func lying_count(pile: PileWorld, code: String) -> int:
	var count := 0
	for card in CardDatabase.cards_in_set(code):
		if pile.is_lying(card.id):
			count += 1
	return count


## Draws a pack of `code` from what's lying about, in reveal order. Nothing
## is taken from the pile here (see Hands.rip_pack).
static func draw(pile: PileWorld, code: String, rng: RandomNumberGenerator) -> Array[int]:
	return draw_from(lying_by_rarity(pile, code), set_has_mythics(code), rng)


## The same from pools of ids by rarity (they're emptied as cards are
## drawn), in reveal order: by the rarity of the pool each came from.
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


## A set to make a pack of: one with at least a full pack lying about, picked
## at random, or "" when no set has.
static func pick_set(pile: PileWorld, rng: RandomNumberGenerator) -> String:
	var sets := CardDatabase.sets_in_shelf_order().duplicate()
	for i in range(sets.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = sets[i]
		sets[i] = sets[j]
		sets[j] = swap
	for set_data: SetData in sets:
		if lying_count(pile, set_data.code) >= SIZE:
			return set_data.code
	return ""


## The rarity a slot draws from: its own, or else the nearest one with
## cards left, looking down before up (a common for an empty uncommon slot).
## -1 when every pool is empty.
static func _nearest_rarity(pools: Array[Array], wanted: int) -> int:
	for step in pools.size():
		for rarity in [wanted - step, wanted + step]:
			if rarity >= 0 and rarity < pools.size() and not pools[rarity].is_empty():
				return rarity
	return -1
