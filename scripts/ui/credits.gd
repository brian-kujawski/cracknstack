class_name Credits
extends RefCounted
## The credits text: the Fan Content disclaimer (plan §2) and, with real
## data, where the card data and images come from and who painted the art.
## The credits roll (CreditsRoll) scrolls it, from the main menu's Credits
## button and after the game is finished.

const DISCLAIMER := "Crack & Stack is unofficial Fan Content permitted under the Fan Content Policy. Not approved/endorsed by Wizards. Portions of the materials used are property of Wizards of the Coast. ©Wizards of the Coast LLC."

## One line per texture in assets/store/ (each folder's SOURCE.txt has the
## details). They're CC0, so crediting them is a courtesy.
const TEXTURES := [
	"Wood: Wood066 by ambientCG (ambientcg.com), CC0.",
	"Table and cabinet baize: Fabric037 by ambientCG (ambientcg.com), CC0.",
	"Floorboards: baked from Wood066 by ambientCG (ambientcg.com), CC0.",
	"Walls: PaintedPlaster017 by ambientCG (ambientcg.com), CC0.",
	"Binder leather: Leather025 by ambientCG (ambientcg.com), CC0.",
	"Brass: Metal048B by ambientCG (ambientcg.com), CC0.",
	"Curtains: Fabric019 by ambientCG (ambientcg.com), CC0.",
]
## One line per font in assets/fonts/ (each has its licence beside it).
const FONTS := [
	"EB Garamond by Georg Duffner and Octavio Pardo, SIL Open Font License 1.1.",
	"Almendra and Almendra SC by Ana Sanfelippo, SIL Open Font License 1.1.",
	"Source Sans 3 by Paul D. Hunt for Adobe, SIL Open Font License 1.1.",
]


## The credits as the roll shows them, in order: [kind, content] where kind
## is "title", "heading", "text" or "end" (the closing line), each one
## string that may wrap, or "names" (a PackedStringArray in columns).
static func roll() -> Array:
	var blocks := [["title", "CRACK & STACK"], ["text", DISCLAIMER]]
	if CardDatabase.is_real_data():
		blocks.append(["heading", "CARD DATA AND IMAGES"])
		blocks.append(["text", "Card data and images from Scryfall (scryfall.com). Crack & Stack isn't produced by or endorsed by Scryfall.\nMagic: The Gathering card names, text, images and art are © Wizards of the Coast LLC and the artists."])
		var names := artists()
		if not names.is_empty():
			blocks.append(["heading", "ARTISTS"])
			blocks.append(["names", names])
	else:
		blocks.append(["text", "These are placeholder cards. Run tools/import_scryfall.py to bring in Khans of Tarkir."])
	blocks.append(["heading", "STORE TEXTURES"])
	blocks.append(["text", "\n".join(TEXTURES)])
	blocks.append(["heading", "FONTS"])
	blocks.append(["text", "\n".join(FONTS)])
	blocks.append(["end", "Crack & Stack is free and always will be."])
	return blocks


## Every artist across the imported sets, each named once, alphabetically.
static func artists() -> PackedStringArray:
	var seen := {}
	for set_data in CardDatabase.sets_in_shelf_order():
		for artist in set_data.artists:
			seen[artist] = true
	var names: Array = seen.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	return PackedStringArray(names)


static func text() -> String:
	var lines := PackedStringArray(["CRACK & STACK", "", DISCLAIMER, ""])
	if CardDatabase.is_real_data():
		lines.append("CARD DATA AND IMAGES")
		lines.append("Card data and images from Scryfall (scryfall.com). Crack & Stack isn't produced by or endorsed by Scryfall.")
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
	lines.append("FONTS")
	for credit in FONTS:
		lines.append(credit)
	lines.append("")
	lines.append("Crack & Stack is free and always will be.")
	return "\n".join(lines)
