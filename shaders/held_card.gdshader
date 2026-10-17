// A single card outside the pile (in the hand, or tossed through the air):
// same face as the floor cards, fed by uniforms instead of per-instance data.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/card_face.gdshaderinc"

uniform vec3 accent = vec3(0.5);
uniform int set_number = 0;
uniform int collector_number = 0;
uniform int rarity = 0;
// The card's large image, when real data is loaded.
uniform bool has_face = false;
uniform sampler2D face_texture : source_color, filter_linear_mipmap, repeat_disable;

void fragment() {
	ALBEDO = FRONT_FACING
		? (has_face ? real_face(texture(face_texture, UV).rgb, UV) : card_face(UV, accent, set_number, collector_number, rarity))
		: back_of_card(vec2(1.0 - UV.x, UV.y)); // Seen from behind, so u runs the other way.
}
