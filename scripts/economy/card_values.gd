class_name CardValues
extends RefCounted
## What each card is worth in the game, worked out from its real market price
## (Scryfall's US dollar price, kept by tools/import_scryfall.py) when the
## cards load. Real prices span too much to play with (a Black Lotus is about
## 100,000 commons), so they're squashed, per set and per rarity:
##
##   value = COMMON_VALUE * BASE[rarity] * (price / median price of that
##           rarity in the set) ^ SPREAD * era scale
##
## A card at its rarity's median is worth exactly the baseline (a common
## $0.10, a rare 5 commons, a mythic 25); above and below the median the gap
## is square-rooted, so a $20 fetchland in a set of $0.29 rares is worth 41
## commons, not 340. The era scale prices whole sets against each other the
## same way: (the set's median common / REFERENCE_COMMON) ^ ERA_SPREAD, about
## x1-2 for modern sets and x25 for Alpha. See /economy/economy-simulation.md.
##
## A card with no price is worth its rarity's median; a set with no prices
## at all (the placeholder sets) gets plain baselines. Basic lands count as
## commons with their own median. Nothing here is saved: change the numbers
## and every card's value follows on the next start.

## A median common, in game dollars.
const COMMON_VALUE := 0.10
## Baseline worth of each rarity in commons (CardData.Rarity order).
const BASE := [1.0, 2.0, 5.0, 25.0]
## How much of a card's real spread around its rarity's median survives
## (0.5: square root).
const SPREAD := 0.5
## The real median common price the era scale is measured against (Khans of
## Tarkir's, in the sim): its sets are x1.
const REFERENCE_COMMON := 0.06
const ERA_SPREAD := 0.5
## Lowest real price used, so a card listed at $0.00 isn't worth nothing.
const PRICE_FLOOR := 0.01


## Sets every card's value. `cards_by_set` is CardDatabase's code -> cards.
static func assign(cards_by_set: Dictionary) -> void:
	for code in cards_by_set:
		assign_set(cards_by_set[code])


## Sets the value of one set's cards.
static func assign_set(cards: Array) -> void:
	var medians := group_medians(cards)
	var scale := era_scale(medians)
	for card: CardData in cards:
		card.value = value_of(card, medians, scale)


## A set's median real price per group (CardData.Rarity, then BASIC for
## basic lands), -1 where the group has no priced card.
static func group_medians(cards: Array) -> PackedFloat64Array:
	var prices: Array[PackedFloat64Array] = []
	for i in BASIC + 1:
		prices.append(PackedFloat64Array())
	for card: CardData in cards:
		if card.price >= 0.0:
			prices[group(card)].append(maxf(card.price, PRICE_FLOOR))
	var medians := PackedFloat64Array()
	for list in prices:
		medians.append(median(list))
	return medians


## The set's era scale from its medians: 1 when it has no priced commons.
static func era_scale(medians: PackedFloat64Array) -> float:
	var common := medians[CardData.Rarity.COMMON]
	return pow(common / REFERENCE_COMMON, ERA_SPREAD) if common > 0.0 else 1.0


## One card's value in game dollars.
static func value_of(card: CardData, medians: PackedFloat64Array, scale: float) -> float:
	var base: float = BASE[card.rarity]
	var middle := medians[group(card)]
	if middle <= 0.0:
		return COMMON_VALUE * base * scale
	var price := maxf(card.price, PRICE_FLOOR) if card.price >= 0.0 else middle
	return COMMON_VALUE * base * pow(price / middle, SPREAD) * scale


## Basic lands are priced against each other, not against the commons.
const BASIC := 4


static func group(card: CardData) -> int:
	return BASIC if card.type_line.begins_with("Basic Land") else card.rarity


static func median(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return -1.0
	var sorted := values.duplicate()
	sorted.sort()
	var half := sorted.size() / 2
	return sorted[half] if sorted.size() % 2 == 1 else (sorted[half - 1] + sorted[half]) / 2.0
