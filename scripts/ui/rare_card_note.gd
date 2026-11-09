class_name RareCardNote
extends PopupNote
## The note that explains the rare cards, the first time in a game one comes
## to hand.

const TEXT := "A rare card! It doesn't go in a binder. Take it to the display cabinets to put it back in its case!"


func _init() -> void:
	text = TEXT
	accent = RareCards.ACCENT
