class_name Credits
extends RefCounted
## The credits text: the Fan Content disclaimer (plan §2) and, with real
## data, where the card data and images come from and who painted the art.
## Nothing shows it yet: it goes in the in-game menu's credits (M4b), and the
## game doesn't ship until it does.

const DISCLAIMER := "Pickup is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC."

## One line per texture in assets/store/ (each folder's SOURCE.txt has the
## details). They're CC0, so crediting them is a courtesy.
const TEXTURES := [
	"Table and cabinet wood: Wood066 by ambientCG (ambientcg.com), CC0.",
	"Shelf wood: Wood052 by ambientCG (ambientcg.com), CC0.",
	"Table and cabinet baize: Fabric037 by ambientCG (ambientcg.com), CC0.",
	"Carpet: Carpet016 by ambientCG (ambientcg.com), CC0.",
	"Walls: PaintedPlaster017 by ambientCG (ambientcg.com), CC0.",
	"Binder leather: Leather025 by ambientCG (ambientcg.com), CC0.",
	"Brass: Metal048B by ambientCG (ambientcg.com), CC0.",
	"Curtains: Fabric019 by ambientCG (ambientcg.com), CC0.",
]


static func text() -> String:
	var lines := PackedStringArray(["PICKUP", "", DISCLAIMER, ""])
	if CardDatabase.is_real_data():
		lines.append("CARD DATA AND IMAGES")
		lines.append("Card data and images from Scryfall (scryfall.com). Pickup isn't produced by or endorsed by Scryfall.")
		lines.append("Magic: The Gathering card names, text, images and art are © Wizards of the Coast LLC and the artists.")
		for set_data in CardDatabase.sets_in_shelf_order():
			if not set_data.artists.is_empty():
				lines.append("")
				lines.append("%s art by %s." % [set_data.name, ", ".join(set_data.artists)])
	else:
		lines.append("These are placeholder cards. Run tools/import_scryfall.py to bring in Khans of Tarkir.")
	lines.append("")
	lines.append("STORE TEXTURES")
	for credit in TEXTURES:
		lines.append(credit)
	lines.append("")
	lines.append("Pickup is free and always will be.")
	return "\n".join(lines)
