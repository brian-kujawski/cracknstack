class_name CardView
extends RefCounted
## Fills in a single-card material (held_card, binder_card) for a card id.


static func apply(material: ShaderMaterial, id: int) -> void:
	var card := CardDatabase.get_card(id)
	var set_data := CardDatabase.get_set(card.set_code)
	var accent := set_data.accent_color
	material.set_shader_parameter("accent", Vector3(accent.r, accent.g, accent.b))
	material.set_shader_parameter("set_number", CardDatabase.sets_in_shelf_order().find(set_data) + 1)
	material.set_shader_parameter("collector_number", card.collector_number)
	material.set_shader_parameter("rarity", card.rarity)
