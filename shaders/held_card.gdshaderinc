// A single card outside the pile (in the hand, or tossed through the air):
// same face as the floor cards, fed by uniforms instead of per-instance data.
// Lit by the room where it really is, like any other object. With FOIL
// defined it's a foil card (held_foil.gdshader, see foil.gdshaderinc).
render_mode cull_disabled;

#include "res://shaders/card_face.gdshaderinc"
#ifdef FOIL
#include "res://shaders/foil.gdshaderinc"
#endif

uniform vec3 accent = vec3(0.5);
uniform int set_number = 0;
uniform int collector_number = 0;
uniform int rarity = 0;
// The card's large image, when real data is loaded.
uniform bool has_face = false;
uniform sampler2D face_texture : source_color, filter_linear_mipmap, repeat_disable;
// Cut by Alpha's die (see cut_away()).
uniform bool alpha_corners = false;

void fragment() {
	if (cut_away(UV, alpha_corners)) {
		discard;
	}
	ALBEDO = FRONT_FACING
		? (has_face ? real_face(texture(face_texture, UV).rgb, UV, alpha_corners) : card_face(UV, accent, set_number, collector_number, rarity))
		: back_of_card(vec2(1.0 - UV.x, UV.y), alpha_corners); // Seen from behind, so u runs the other way.
	ROUGHNESS = 0.6;
#ifdef FOIL
	Foil foil = foil_at(UV, NORMAL, TANGENT, BINORMAL);
	foil_mask = FRONT_FACING ? foil.mask : 0.0;
	foil_shift = foil.shift;
	foil_glint = foil.glint;
	foil_across = foil.across;
	if (FRONT_FACING) {
		NORMAL = foil.normal;
	}
	ALBEDO = ink_over_foil(ALBEDO, foil_mask);
#endif
}

#ifdef FOIL
void light() {
	foil_light(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION, ALBEDO,
			foil_mask, foil_shift, foil_glint, foil_across, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
#endif
