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
## A card with no price, or one under BAD_PRICE of its rarity's median (bad
## data, like Alpha Timber Wolves at $0.10), gets an estimate first
## (estimate_missing): its foil price if that's all it has, or else what
## its printing in another set says, through a fit of the two sets' prices
## for the cards they share (so Alpha Ancestral Recall is priced from
## Unlimited's); a few with no priced printing anywhere have STAND_INS.
## Without an estimate it's worth its rarity's median (the cards banned in
## 2020, delisted by stores); a set with no prices at all (the placeholder
## sets) gets plain baselines.
## See /economy/price-outliers.md. Basic lands count as
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
## A price under this share of its rarity's median is taken for bad data.
const BAD_PRICE := 0.01
## Fewest cards two sets must both have priced to estimate one from the
## other.
const MIN_SHARED := 30
## Cards with no priced printing anywhere: priced like the dearest of these
## cards in the same set, or with none named, like the set's dearest card.
const STAND_INS := {
	"Black Lotus": [],
	"Mox Sapphire": ["Mox Jet", "Mox Ruby", "Mox Pearl", "Mox Emerald"],
}


## Sets every card's value. `cards_by_set` is CardDatabase's code -> cards.
static func assign(cards_by_set: Dictionary) -> void:
	estimate_missing(cards_by_set)
	for code in cards_by_set:
		assign_set(cards_by_set[code])


## Sets the value of one set's cards.
static func assign_set(cards: Array) -> void:
	var medians := group_medians(cards)
	var scale := era_scale(medians)
	for card: CardData in cards:
		card.value = value_of(card, medians, scale)


## Gives an estimate to every card whose price is missing or bad (see the
## top), where one can be made.
static func estimate_missing(cards_by_set: Dictionary) -> void:
	# Set code -> {card name: real price} for the prices that are fine.
	var prices := {}
	var pending: Array[CardData] = []
	for code in cards_by_set:
		var medians := group_medians(cards_by_set[code])
		var known := {}
		for card: CardData in cards_by_set[code]:
			card.estimate = -1.0
			if is_bad(card, medians):
				pending.append(card)
			elif card.price >= 0.0:
				known[card.name] = maxf(known.get(card.name, 0.0), maxf(card.price, PRICE_FLOOR))
		prices[code] = known
	var fits := {}
	var left: Array[CardData] = []
	for card in pending:
		if card.price < 0.0 and card.foil_price >= 0.0:
			card.estimate = card.foil_price
			continue
		var best_shared := 0
		for other in prices:
			var priced: Dictionary = prices[other]
			if other == card.set_code or not priced.has(card.name):
				continue
			var key := "%s<%s" % [card.set_code, other]
			if not fits.has(key):
				fits[key] = fit(prices.get(card.set_code, {}), priced)
			var line: PackedFloat64Array = fits[key]
			if line.size() == 3 and line[2] > best_shared:
				best_shared = int(line[2])
				card.estimate = exp(line[0] + line[1] * log(priced[card.name]))
		if card.estimate < 0.0:
			left.append(card)
	for card in left:
		if STAND_INS.has(card.name):
			card.estimate = stand_in(card, cards_by_set[card.set_code])


## A fit of log(price in `a`) against log(price in `b`) over the cards both
## have priced (by name): [intercept, slope, how many], or empty for fewer
## than MIN_SHARED.
static func fit(a: Dictionary, b: Dictionary) -> PackedFloat64Array:
	var xs := PackedFloat64Array()
	var ys := PackedFloat64Array()
	for name in a:
		if b.has(name):
			xs.append(log(b[name]))
			ys.append(log(a[name]))
	if xs.size() < MIN_SHARED:
		return PackedFloat64Array()
	var mean_x := 0.0
	var mean_y := 0.0
	for i in xs.size():
		mean_x += xs[i] / xs.size()
		mean_y += ys[i] / ys.size()
	var cov := 0.0
	var spread := 0.0
	for i in xs.size():
		cov += (xs[i] - mean_x) * (ys[i] - mean_y)
		spread += (xs[i] - mean_x) * (xs[i] - mean_x)
	if spread <= 0.0:
		return PackedFloat64Array()
	var slope := cov / spread
	return PackedFloat64Array([mean_y - slope * mean_x, slope, xs.size()])


## A STAND_INS card's price: the dearest of its named cards in `cards`, or
## of all of them.
static func stand_in(card: CardData, cards: Array) -> float:
	var like: Array = STAND_INS[card.name]
	var dearest := -1.0
	for other: CardData in cards:
		if other != card and (like.is_empty() or other.name in like):
			dearest = maxf(dearest, priced_at(other))
	return dearest


## The price a card is valued at: its estimate if it has one, else its
## real price (-1 for none).
static func priced_at(card: CardData) -> float:
	return card.estimate if card.estimate >= 0.0 else card.price


## Whether a card's price is missing or too far under its rarity's median to
## be right.
static func is_bad(card: CardData, medians: PackedFloat64Array) -> bool:
	if card.price < 0.0:
		return true
	var middle := medians[group(card)]
	return middle > 0.0 and card.price < BAD_PRICE * middle


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
	var price := middle
	if card.estimate >= 0.0:
		price = maxf(card.estimate, PRICE_FLOOR)
	elif not is_bad(card, medians):
		price = maxf(card.price, PRICE_FLOOR)
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
