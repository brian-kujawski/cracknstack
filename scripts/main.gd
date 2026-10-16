extends Node3D
## Main scene: the graybox store (M1) and the player. The card pile arrives
## in M2.

@onready var _status: Label = $HUD/Status


func _ready() -> void:
	var binders := CardDatabase.all_binders()
	_status.text = "Pickup graybox: %d cards in %d sets, %d labelled binder spaces\nWASD move · mouse look · Ctrl/C crouch · Esc frees mouse" % [
		CardDatabase.card_count(), CardDatabase.set_count(), binders.size()]
