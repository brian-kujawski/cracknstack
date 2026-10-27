// Cards lying on the floor, drawn with one MultiMesh per chunk. Each card
// is a face plus thin edges, corners rounded (see PileWorld.card_mesh).
// Per instance:  COLOR = (set accent colour, face atlas index or -1)
//                CUSTOM = (collector number, set number,
//                          rarity + 4 * highlighted + 8 * glowing + 16 * Alpha corners, face up)
// With real data the face comes from the atlas (FaceAtlas); with a face
// index of -1 the placeholder face is drawn instead. With FOIL defined the
// faces are foil (floor_foil.gdshader, see foil.gdshaderinc).
render_mode cull_disabled;

#include "res://shaders/card_face.gdshaderinc"
#ifdef FOIL
#include "res://shaders/foil.gdshaderinc"

// The foil chunk holds only rare cards: each one's own back, one layer per
// collector number, and which of them has one (see
// CardDatabase.apply_rare_backs).
uniform sampler2DArray rare_backs : source_color, filter_linear_mipmap, repeat_disable;
uniform int rare_has_back[36];
#endif

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
#ifdef FOIL
	// Across the face: u runs along +x, v along +z.
	TANGENT = vec3(1.0, 0.0, 0.0);
	BINORMAL = vec3(0.0, 0.0, 1.0);
#endif
	// The mesh is cut with the usual corners; UV2 holds where each vertex
	// goes for Alpha's deeper cut.
	if (int(card.z + 0.5) >= 16) {
		if (UV.x > -0.5) {
			UV += (UV2 - VERTEX.xz) / CARD_SIZE;
		}
		VERTEX.xz = UV2;
	}
}

// Card edge colour: dark, so each layer of a stack shows as a line.
const vec3 EDGE = vec3(0.2, 0.18, 0.16);

void fragment() {
	int flags = int(card.z + 0.5);
	bool highlighted = (flags / 4) % 2 == 1;
	bool glowing = (flags / 8) % 2 == 1;
	bool alpha_corners = flags >= 16;
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
#ifdef FOIL
	vec3 rare_back = texture(rare_backs, vec3(clamp(uv, 0.0, 1.0), float(clamp(int(card.x + 0.5), 1, 36) - 1))).rgb;
#endif
	// The mesh's edge faces carry UV (-1, -1).
	if (UV.x < -0.5) {
		ALBEDO = EDGE;
		ROUGHNESS = 0.8;
	} else {
		int rarity = int(card.z + 0.5) % 4;
		vec3 front = face_index > -0.5
			? real_face(atlas_face, uv, alpha_corners)
			: card_face(uv, accent, int(card.y + 0.5), int(card.x + 0.5), rarity);
		vec3 back = back_of_card(uv, alpha_corners);
#ifdef FOIL
		int number = clamp(int(card.x + 0.5), 1, 36);
		if (rare_has_back[number - 1] == 1) {
			back = real_face(rare_back, uv, alpha_corners);
		}
#endif
		ALBEDO = card.w > 0.5 ? front : back;
		ROUGHNESS = 0.6;
	}
#ifdef FOIL
	Foil foil = foil_at(uv, NORMAL, TANGENT, BINORMAL);
	foil_mask = UV.x > -0.5 && card.w > 0.5 ? foil.mask : 0.0;
	foil_shift = foil.shift;
	foil_glint = foil.glint;
	foil_across = foil.across;
	if (foil_mask > 0.0) {
		NORMAL = foil.normal;
	}
	ALBEDO = ink_over_foil(ALBEDO, foil_mask);
#endif
	if (highlighted) {
		EMISSION = vec3(0.35, 0.3, 0.1);
	}
	// Found by magic: a bright pulse that reads from across the room.
	if (glowing) {
		EMISSION += vec3(1.6, 0.9, 0.3) * (0.6 + 0.4 * sin(TIME * 5.0));
	}
}

#ifdef FOIL
void light() {
	foil_light(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION, ALBEDO,
			foil_mask, foil_shift, foil_glint, foil_across, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
#endif
