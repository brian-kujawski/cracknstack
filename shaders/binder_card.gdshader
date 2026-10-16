// A card sitting in a binder pocket or on top of an unsorted stack. Lit like
// the floor cards, with an edge glow: gold when locked in, red when misplaced.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/card_face.gdshaderinc"

uniform vec3 accent = vec3(0.5);
uniform int set_number = 0;
uniform int collector_number = 0;
uniform int rarity = 0;
// rgb colour, a strength (0 = no glow).
uniform vec4 glow = vec4(0.0);

void fragment() {
	vec3 color = FRONT_FACING
		? card_face(UV, accent, set_number, collector_number, rarity)
		: card_back(UV);
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y) * 0.72);
	float band = 1.0 - smoothstep(0.0, 0.1, edge);
	// Paint the edge in the glow colour too, so it reads even without bloom.
	ALBEDO = mix(color, glow.rgb, band * min(glow.a, 1.0) * 0.85);
	ROUGHNESS = 0.45;
	EMISSION = glow.rgb * glow.a * (0.2 + 0.8 * band);
}
