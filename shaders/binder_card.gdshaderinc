// A card sitting in a binder pocket or lying on a table. Lit like the floor
// cards, with an edge glow: gold when locked in, red when misplaced. A card on
// a table also lights up like a floor card when aimed at or found by magic.
// With FOIL defined it's a foil card (binder_foil.gdshader, see
// foil.gdshaderinc).
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
// rgb colour, a strength (0 = no glow).
uniform vec4 glow = vec4(0.0);
// As floor_card.gdshader's highlighted and glowing flags.
uniform bool highlighted = false;
uniform bool glowing = false;

void fragment() {
	if (cut_away(UV, alpha_corners)) {
		discard;
	}
	vec3 color = FRONT_FACING
		? (has_face ? real_face(texture(face_texture, UV).rgb, UV, alpha_corners) : card_face(UV, accent, set_number, collector_number, rarity))
		: back_of_card(vec2(1.0 - UV.x, UV.y), alpha_corners); // Seen from behind, so u runs the other way.
#ifdef FOIL
	Foil foil = foil_at(UV, NORMAL, TANGENT, BINORMAL);
	foil_mask = FRONT_FACING ? foil.mask : 0.0;
	foil_shift = foil.shift;
	foil_glint = foil.glint;
	foil_across = foil.across;
	if (FRONT_FACING) {
		NORMAL = foil.normal;
	}
	color = ink_over_foil(color, foil_mask);
#endif
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y) * 0.72);
	float band = 1.0 - smoothstep(0.0, 0.1, edge);
	// Paint the edge in the glow colour too, so it reads even without bloom.
	ALBEDO = mix(color, glow.rgb, band * min(glow.a, 1.0) * 0.85);
	ROUGHNESS = 0.45;
	EMISSION = glow.rgb * glow.a * (0.2 + 0.8 * band);
	if (highlighted) {
		EMISSION += vec3(0.35, 0.3, 0.1);
	}
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
