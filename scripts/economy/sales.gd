class_name Sales
extends RefCounted
## Selling a card: the one way every sale goes, by hand at a shipping box
## (Hands.sell_held_card) or a whole sorting tray at once (SortingTray), and
## later the machines. The copy is gone for good and the money is yours.


## Sells copy `copy`: it's marked sold and its price (Prices.sale_cents)
## is paid. Returns the cents, or 0 if it was already sold.
static func sell(copy: int) -> int:
	if copy < 0 or Collection.is_sold(copy):
		return 0
	var cents := Prices.sale_cents(Collection.card(copy))
	Collection.mark_sold(copy)
	Progression.earn_money(cents)
	return cents


## Sells every copy in `copies` (sell, for a whole sorting tray): the money
## is paid in one go, so the HUD redraws once rather than once a card.
## Returns each copy's cents, in order (0 for one already sold).
static func sell_all(copies: Array[int]) -> PackedInt32Array:
	var paid := PackedInt32Array()
	var total := 0
	for copy in copies:
		var cents := 0
		if copy >= 0 and not Collection.is_sold(copy):
			cents = Prices.sale_cents(Collection.card(copy))
			Collection.mark_sold(copy)
		paid.append(cents)
		total += cents
	if total > 0:
		Progression.earn_money(total)
	return paid
