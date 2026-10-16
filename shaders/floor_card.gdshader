// Cards lying on the floor, drawn with one MultiMesh per chunk.
// Per instance:  COLOR = set accent colour
//                CUSTOM = (collector number, set number, rarity + 4 * highlighted, face up)
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/card_face.gdshaderinc"

varying vec3 accent;
varying flat vec4 card;

void vertex() {
	accent = COLOR.rgb;
	card = INSTANCE_CUSTOM;
}

void fragment() {
	// PlaneMesh UVs run mirrored when seen from above; flip so text reads.
	vec2 uv = vec2(1.0 - UV.x, UV.y);
	int rarity = int(card.z + 0.5) % 4;
	bool highlighted = int(card.z + 0.5) >= 4;
	vec3 color = card.w > 0.5
		? card_face(uv, accent, int(card.y + 0.5), int(card.x + 0.5), rarity)
		: card_back(uv);
	ALBEDO = color;
	ROUGHNESS = 0.6;
	if (highlighted) {
		EMISSION = vec3(0.35, 0.3, 0.1);
	}
}
