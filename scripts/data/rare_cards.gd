class_name RareCards
extends RefCounted
## The rare cards (plan §3.7): 36 one-of-a-kind cards hidden in the pile
## that have no binder. Each goes in its own shadow box in the display
## cabinets instead (DisplayCabinet), and unlocks its own achievement there.
##
## They're one extra set, added by CardDatabase to whatever data it loads,
## after every other card so no other card's id moves. The set never gets a
## binder or a shelf space, so nothing that works on binders (filing,
## Teleport, Tithe, Brainstorm and the rest) ever finds them.
##
## Names and art are placeholders, yours to replace (see
## assets/rare_cards/README.txt): rename a card in LIST,
## and put its art in assets/rare_cards/ as rareNNN.png (NNN = its number,
## from 001). Without art a card shows the gold placeholder face. Their
## back is assets/rare_cards/back.png; without it they share every other
## card's back.

const SET_CODE := "RARE"
const SET_NAME := "Rare Cards"
const ACCENT := Color(0.85, 0.66, 0.2)
const IMAGE_PATH := "res://assets/rare_cards/rare%03d.png"
const BACK_PATH := "res://assets/rare_cards/back.png"

## Every rare card in shadow-box order: number 1 hangs top left in the first
## cabinet (nearest the back wall), 18 bottom right in it, then 19 to 36 the
## same way in the second.
const LIST := [
	"Rare Card 01", "Rare Card 02", "Rare Card 03", "Rare Card 04", "Rare Card 05", "Rare Card 06",
	"Rare Card 07", "Rare Card 08", "Rare Card 09", "Rare Card 10", "Rare Card 11", "Rare Card 12",
	"Rare Card 13", "Rare Card 14", "Rare Card 15", "Rare Card 16", "Rare Card 17", "Rare Card 18",
	"Rare Card 19", "Rare Card 20", "Rare Card 21", "Rare Card 22", "Rare Card 23", "Rare Card 24",
	"Rare Card 25", "Rare Card 26", "Rare Card 27", "Rare Card 28", "Rare Card 29", "Rare Card 30",
	"Rare Card 31", "Rare Card 32", "Rare Card 33", "Rare Card 34", "Rare Card 35", "Rare Card 36",
]


static func count() -> int:
	return LIST.size()


static func make_set() -> SetData:
	var set_data := SetData.new()
	set_data.code = SET_CODE
	set_data.name = SET_NAME
	set_data.release_date = "9999-12-31"
	set_data.card_count = count()
	set_data.accent_color = ACCENT
	return set_data


## The rare cards as CardData, numbered 1 to 36, with ids from `first_id`.
static func make_cards(first_id: int) -> Array[CardData]:
	var cards: Array[CardData] = []
	for i in count():
		var card := CardData.new()
		card.id = first_id + i
		card.name = LIST[i]
		card.set_code = SET_CODE
		card.collector_number = i + 1
		card.rarity = CardData.Rarity.MYTHIC
		card.type_line = ""
		var image := IMAGE_PATH % (i + 1)
		if FileAccess.file_exists(image) or ResourceLoader.exists(image):
			card.image_large = image
		cards.append(card)
	return cards


static func is_rare(card: CardData) -> bool:
	return card.set_code == SET_CODE
