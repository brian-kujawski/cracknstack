// A single card outside the pile (in the hand, or tossed through the air):
// same face as the floor cards, fed by uniforms instead of per-instance data.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/card_face.gdshaderinc"

uniform vec3 accent = vec3(0.5);
uniform int set_number = 0;
uniform int collector_number = 0;
uniform int rarity = 0;

void fragment() {
	ALBEDO = FRONT_FACING
		? card_face(UV, accent, set_number, collector_number, rarity)
		: card_back(UV);
}
