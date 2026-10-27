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
## and put its art in assets/rare_cards/ as rareNNN.png or .jpg (NNN = its
## number, from 001). Without art a card shows the gold placeholder face.
## Each card's back is rareNNN_back.png or .jpg beside it; without one, that
## card has every other card's back.

const SET_CODE := "RARE"
const SET_NAME := "Rare Cards"
const ACCENT := Color(0.85, 0.66, 0.2)
const IMAGE_PATH := "res://assets/rare_cards/rare%03d"
const BACK_PATH := "res://assets/rare_cards/rare%03d_back"
## The image types FaceAtlas.load_image reads, in the order they're looked for.
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]

## Every rare card in shadow-box order: number 1 hangs top left in the first
## cabinet (nearest the back wall), 18 bottom right in it, then 19 to 36 the
## same way in the second.
const LIST := [
	"Black Lotus",
	"Mox Emerald",
	"Mox Jet",
	"Mox Pearl",
	"Mox Ruby",
	"Mox Sapphire",
	"Ancestral Recall",
	"Time Twister",
	"Time Walk",
	"Charizard",
	"Michael Jordan",
	"Blue Eyes White Dragon",
	"Business Card",
	"Costco Card",
	"Rare Card 15", "Rare Card 16", "Rare Card 17", "Rare Card 18",
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
		card.image_large = _find_image(IMAGE_PATH % (i + 1))
		cards.append(card)
	return cards


## Rare card `number`'s own back image, or "" if it has none.
static func back_path(number: int) -> String:
	return _find_image(BACK_PATH % number)


## The image at `base` plus whichever of IMAGE_EXTENSIONS is there, or "".
## A real file wins over one that's only left in Godot's import cache (an
## old .import file can outlive the image it was made from).
static func _find_image(base: String) -> String:
	for extension in IMAGE_EXTENSIONS:
		var path := "%s.%s" % [base, extension]
		if FileAccess.file_exists(path):
			return path
	for extension in IMAGE_EXTENSIONS:
		var path := "%s.%s" % [base, extension]
		if ResourceLoader.exists(path):
			return path
	return ""


static func is_rare(card: CardData) -> bool:
	return card.set_code == SET_CODE
