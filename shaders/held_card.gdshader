// A single card outside the pile (in the hand, or tossed through the air):
// same face as the floor cards, fed by uniforms instead of per-instance data.
//
// It's lit by the room's real lights, but as if it lay face up on the surface
// below it (light_floor): held at eye level it would sit outside the lamps'
// cones and go nearly black, then jump bright again on landing. Lit this way
// it matches the cards under it, shadows included, all the way down.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/card_face.gdshaderinc"

uniform vec3 accent = vec3(0.5);
uniform int set_number = 0;
uniform int collector_number = 0;
uniform int rarity = 0;
// The card's large image, when real data is loaded.
uniform bool has_face = false;
uniform sampler2D face_texture : source_color, filter_linear_mipmap, repeat_disable;
// World height of the surface the card is lit as if lying on.
uniform float light_floor = 0.02;

void fragment() {
	ALBEDO = FRONT_FACING
		? (has_face ? real_face(texture(face_texture, UV).rgb, UV) : card_face(UV, accent, set_number, collector_number, rarity))
		: back_of_card(vec2(1.0 - UV.x, UV.y)); // Seen from behind, so u runs the other way.
	ROUGHNESS = 0.6;
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world.y = min(world.y, light_floor);
	LIGHT_VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
