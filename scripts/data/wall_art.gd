class_name WallArt
extends RefCounted
## The wall art: twelve picture frames that hang empty, white behind their
## mats, until one particular card is locked into its own binder pocket. Then
## that card's art fills the frame, and its own achievement unlocks.
##
## Five hang over the binder shelf, one per basic land; seven hang over the
## reading corner, for iconic art from over the years. StoreBuilder hangs
## them in this order (see WALL_FRAMES there).
##
## Which card fills each frame, its achievement's title and line, and its art
## are yours to choose (see assets/wall_art/README.txt). A card is named by
## set code and collector number, never by id (ids move when the data is
## imported again). The cards here are placeholders from Khans of Tarkir.

const IMAGE_PATH := "res://assets/wall_art/art%02d"

## Every frame, in StoreBuilder's order: the shelf's five left to right as
## you face it, then over the reading corner the centre piece, the pair on
## its shelf side (top, bottom), the pair on its door side (top, bottom),
## and the end frames, shelf end then door end. The end frames are
## portrait, the rest landscape.
## [achievement title, line shown once unlocked, set code, collector number]
const LIST := [
	["Plains", "Hung the Plains on the wall.", "KTK", 250],
	["Island", "Hung the Island on the wall.", "KTK", 254],
	["Swamp", "Hung the Swamp on the wall.", "KTK", 258],
	["Mountain", "Hung the Mountain on the wall.", "KTK", 262],
	["Forest", "Hung the Forest on the wall.", "KTK", 266],
	["Wall Art 06", "Hung Wall Art 06 on the wall.", "KTK", 1],
	["Wall Art 07", "Hung Wall Art 07 on the wall.", "KTK", 2],
	["Wall Art 08", "Hung Wall Art 08 on the wall.", "KTK", 3],
	["Wall Art 09", "Hung Wall Art 09 on the wall.", "KTK", 4],
	["Wall Art 10", "Hung Wall Art 10 on the wall.", "KTK", 5],
	["Wall Art 11", "Hung Wall Art 11 on the wall.", "KTK", 6],
	["Wall Art 12", "Hung Wall Art 12 on the wall.", "KTK", 7],
]

## How much of a card scan the art box takes, as a UV rectangle, for a frame
## whose own art isn't there yet: about right for the usual card frame.
const SCAN_ART_BOX := Rect2(0.08, 0.11, 0.84, 0.45)


static func count() -> int:
	return LIST.size()


## The frame `card` fills (from 0), or -1.
static func index_of(card: CardData) -> int:
	for index in count():
		if LIST[index][2] == card.set_code and LIST[index][3] == card.collector_number:
			return index
	return -1


## Whether frame `index`'s card is locked into its own pocket in one of
## `binders`.
static func is_filed(index: int, binders: Array[Binder]) -> bool:
	return is_card_filed(LIST[index][2], LIST[index][3], binders)


static func is_card_filed(set_code: String, collector_number: int, binders: Array[Binder]) -> bool:
	for binder in binders:
		if binder.binder.set_code == set_code and binder.binder.contains(collector_number):
			return binder.contents.is_locked(collector_number - binder.binder.first)
	return false


## Frame `index`'s art file (assets/wall_art/artNN.png or .jpg, NN from 01),
## or "" if it has none yet.
static func image_path(index: int) -> String:
	return RareCards.find_image(IMAGE_PATH % (index + 1))


## What frame `index` shows once filled, and the part of it to show (a UV
## rectangle): its own art, whole; without that, the art box of its card's
## scan; without either, null.
static func art(index: int) -> Array:
	var image := FaceAtlas.load_image(image_path(index)) if not image_path(index).is_empty() else null
	if image != null:
		return [ImageTexture.create_from_image(image), Rect2(0, 0, 1, 1)]
	for card in CardDatabase.cards_in_set(LIST[index][2]):
		if card.collector_number == LIST[index][3] and not card.image_large.is_empty():
			image = FaceAtlas.load_image(card.image_large)
			if image != null:
				return [ImageTexture.create_from_image(image), SCAN_ART_BOX]
	return [null, Rect2()]
