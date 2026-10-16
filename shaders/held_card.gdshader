// The card in the player's hand: same face as the floor cards, fed by
// uniforms instead of per-instance data.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/card_face.gdshaderinc"

uniform vec3 accent = vec3(0.5);
uniform int set_number = 0;
uniform int collector_number = 0;
uniform int rarity = 0;

void fragment() {
	ALBEDO = card_face(UV, accent, set_number, collector_number, rarity);
}
