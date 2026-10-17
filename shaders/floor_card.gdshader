// Cards lying on the floor, drawn with one MultiMesh per chunk. Each card
// is a face plus four thin edges (see PileWorld._card_mesh).
// Per instance:  COLOR = (set accent colour, face atlas index or -1)
//                CUSTOM = (collector number, set number, rarity + 4 * highlighted, face up)
// With real data the face comes from the atlas (FaceAtlas); with a face
// index of -1 the placeholder face is drawn instead.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/card_face.gdshaderinc"

uniform sampler2DArray faces : source_color, filter_linear_mipmap, repeat_disable;
uniform ivec2 face_grid = ivec2(1, 1);
uniform vec2 face_slot_uv = vec2(1.0);

varying vec3 accent;
varying flat float face_index;
varying flat vec4 card;

void vertex() {
	accent = COLOR.rgb;
	face_index = COLOR.a;
	card = INSTANCE_CUSTOM;
}

// Card edge colour: dark, so each layer of a stack shows as a line.
const vec3 EDGE = vec3(0.2, 0.18, 0.16);

void fragment() {
	bool highlighted = int(card.z + 0.5) >= 4;
	// PlaneMesh UVs already read the right way round from above (u along
	// +x, v along +z), so faces are sampled as they are.
	vec2 uv = UV;
	// Sample the atlas outside any branch so mipmap selection stays smooth.
	int index = max(int(face_index + 0.5), 0);
	int per_page = face_grid.x * face_grid.y;
	int slot = index % per_page;
	vec2 cell = vec2(float(slot % face_grid.x), float(slot / face_grid.x));
	vec2 atlas_uv = (cell + clamp(uv, 0.01, 0.99)) * face_slot_uv;
	vec3 atlas_face = texture(faces, vec3(atlas_uv, float(index / per_page))).rgb;
	// The mesh's edge faces carry UV (-1, -1).
	if (UV.x < -0.5) {
		ALBEDO = EDGE;
		ROUGHNESS = 0.8;
	} else {
		int rarity = int(card.z + 0.5) % 4;
		vec3 front = face_index > -0.5
			? real_face(atlas_face, uv)
			: card_face(uv, accent, int(card.y + 0.5), int(card.x + 0.5), rarity);
		ALBEDO = card.w > 0.5 ? front : card_back(uv);
		ROUGHNESS = 0.6;
	}
	if (highlighted) {
		EMISSION = vec3(0.35, 0.3, 0.1);
	}
}
