// Cards lying on the floor, drawn with one MultiMesh per chunk. Each card
// is a face plus four thin edges (see PileWorld._card_mesh).
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

// Card edge colour: dark, so each layer of a stack shows as a line.
const vec3 EDGE = vec3(0.2, 0.18, 0.16);

void fragment() {
	bool highlighted = int(card.z + 0.5) >= 4;
	// The mesh's edge faces carry UV (-1, -1).
	if (UV.x < -0.5) {
		ALBEDO = EDGE;
		ROUGHNESS = 0.8;
	} else {
		// PlaneMesh UVs run mirrored when seen from above; flip so text reads.
		vec2 uv = vec2(1.0 - UV.x, UV.y);
		int rarity = int(card.z + 0.5) % 4;
		ALBEDO = card.w > 0.5
			? card_face(uv, accent, int(card.y + 0.5), int(card.x + 0.5), rarity)
			: card_back(uv);
		ROUGHNESS = 0.6;
	}
	if (highlighted) {
		EMISSION = vec3(0.35, 0.3, 0.1);
	}
}
