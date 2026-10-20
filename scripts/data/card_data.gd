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
