class_name CardData
extends RefCounted
## One card: the base printing of a card in a set. Game code gets these from
## CardDatabase and never constructs them itself.

enum Rarity { COMMON, UNCOMMON, RARE, MYTHIC }

## Index into CardDatabase; stable for a given data file.
var id: int
var name: String
var set_code: String
## Plain whole number. Only base versions are included, so there are no
## suffixed or starred numbers (see plan §3.3).
var collector_number: int
var rarity: Rarity
var colors: PackedStringArray
var type_line: String
## Slot in the face atlas (FaceAtlas), or -1 to draw the placeholder face.
var face_index: int = -1
## Path to a large face image. Empty means "draw the placeholder face".
var image_large: String = ""
## Path to the card's near face (NearFaces), or "" if it has none.
var image_near: String = ""
## Real market price in US dollars when imported (Scryfall), -1 for none;
## and the foil price.
var price: float = -1.0
var foil_price: float = -1.0
## A stand-in price (CardValues.estimate_missing) where the real one is
## missing or can't be right, -1 for none.
var estimate: float = -1.0
## What it's worth in the game, in game dollars (CardValues, from the price).
var value: float = 0.0


## Alpha (LEA) was cut with a die that rounded the corners deeper than every
## set printed since.
func has_alpha_corners() -> bool:
	return set_code == "LEA"


static func rarity_from_string(value: String) -> Rarity:
	match value:
		"uncommon":
			return Rarity.UNCOMMON
		"rare":
			return Rarity.RARE
		"mythic":
			return Rarity.MYTHIC
		_:
			return Rarity.COMMON
