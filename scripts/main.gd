extends Node3D
## Skeleton main scene: an empty floor to walk on and a readout proving the
## card data loaded. The graybox store replaces the floor in M1.

@onready var _status: Label = $HUD/Status


func _ready() -> void:
	var binders := CardDatabase.all_binders()
	_status.text = "Pickup skeleton: %d cards in %d sets, %d binders\nWASD move · mouse look · Ctrl/C crouch · Esc frees mouse" % [
		CardDatabase.card_count(), CardDatabase.set_count(), binders.size()]
