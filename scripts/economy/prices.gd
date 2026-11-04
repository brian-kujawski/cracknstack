class_name Prices
extends RefCounted
## What things cost and what cards sell for, in cents, from each card's
## value (CardValues, CardData.value in dollars).
##
## Selling a card pays its value. Product costs what it's worth on average
## divided by MARGIN: a pack worth $3.19 on average costs about $2.13, so
## selling everything from two packs buys about three
## (/mnt/project-files/economy/economy-simulation.md, "Pack price"). Packs
## are rounded to the nearest PACK_ROUNDING, a booster box is BOX_PACKS packs
## at that price, and a bulk box is rounded to the nearest whole dollar.

## A pack's average worth over its price.
const MARGIN := 1.5
## Packs are priced to the nearest quarter, and never below one.
const PACK_ROUNDING := 25
## Bulk boxes are priced to the nearest dollar, and never below one.
const BULK_ROUNDING := 100


## What card `card` sells for: its value, never less than a cent.
static func sale_cents(card: CardData) -> int:
	return maxi(1, roundi(card.value * 100.0))


## The average value (dollars) of each rarity's cards in set `code`
## (CardData.Rarity order), or -1 where the set has none.
static func rarity_means(code: String) -> PackedFloat64Array:
	var sums := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var counts := PackedInt32Array([0, 0, 0, 0])
	for card in CardDatabase.cards_in_set(code):
		sums[card.rarity] += card.value
		counts[card.rarity] += 1
	var means := PackedFloat64Array()
	for rarity in sums.size():
		means.append(sums[rarity] / counts[rarity] if counts[rarity] > 0 else -1.0)
	return means


## A slot of `wanted` rarity takes the nearest rarity the set has, looking
## down before up, the way PackContents fills it.
static func _slot_mean(means: PackedFloat64Array, wanted: int) -> float:
	for step in means.size():
		for rarity in [wanted - step, wanted + step]:
			if rarity >= 0 and rarity < means.size() and means[rarity] >= 0.0:
				return means[rarity]
	return 0.0


## What a booster pack of `code` is worth on average, in dollars: its
## commons, its uncommons and its rare slot (a mythic one time in
## PackContents.MYTHIC_CHANCE, in sets that have them).
static func pack_worth(code: String) -> float:
	var means := rarity_means(code)
	var commons := PackContents.SIZE - 1 - PackContents.UNCOMMONS
	var worth := commons * _slot_mean(means, CardData.Rarity.COMMON)
	worth += PackContents.UNCOMMONS * _slot_mean(means, CardData.Rarity.UNCOMMON)
	var rare := _slot_mean(means, CardData.Rarity.RARE)
	if means[CardData.Rarity.MYTHIC] >= 0.0:
		var chance := 1.0 / PackContents.MYTHIC_CHANCE
		rare = rare * (1.0 - chance) + means[CardData.Rarity.MYTHIC] * chance
	return worth + rare


## What a bulk box of `code` is worth on average, in dollars
## (PackContents.BULK_SHARES of PackContents.BULK_SIZE cards).
static func bulk_worth(code: String) -> float:
	var means := rarity_means(code)
	var total := 0.0
	var worth := 0.0
	for rarity in PackContents.BULK_SHARES.size():
		var share := maxf(PackContents.BULK_SHARES[rarity], 0.0)
		total += share
		worth += share * _slot_mean(means, rarity)
	return worth / total * PackContents.BULK_SIZE if total > 0.0 else 0.0


## A booster pack's price, in cents.
static func pack_cents(code: String) -> int:
	return _rounded(pack_worth(code) / MARGIN * 100.0, PACK_ROUNDING)


## A Card Shop product's price, in cents: kind "pack", "booster_box" or
## "bulk_box" (as LaptopScreen.PRODUCTS names them).
static func product_cents(kind: String, code: String) -> int:
	match kind:
		"pack":
			return pack_cents(code)
		"booster_box":
			return pack_cents(code) * PackContents.BOX_PACKS
		"bulk_box":
			return _rounded(bulk_worth(code) / MARGIN * 100.0, BULK_ROUNDING)
	return 0


static func _rounded(cents: float, step: int) -> int:
	return maxi(step, roundi(cents / step) * step)
