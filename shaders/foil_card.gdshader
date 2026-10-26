// EXPERIMENT: a foil card in the hand. The same face as held_card.gdshader,
// printed over a metallised film instead of white card. All its shine comes
// from the room's real lights through light(), so it changes with where the
// card is and which way it faces, like the non-foil cards.
//
// The film is a diffraction grating: light that isn't mirrored straight back
// is split into a rainbow, the hue depending on the angle between the light
// and the eye across the film (see diffraction()). Ink sits on top and tints
// what the film reflects; dark ink lets less through.
//
// foil_style: 1 traditional (the whole face), 2 etched (frame only, a grainy
// sparkle; the art stays matte), 3 traditional with sparkle on top, 4 the
// same over an etched crystal pattern: the film is cut into facets, each with
// its own fine lines (its own grating, turned its own way) and tilted a
// touch, so each facet catches the light at its own angle and colour.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/card_face.gdshaderinc"

uniform vec3 accent = vec3(0.5);
uniform int set_number = 0;
uniform int collector_number = 0;
uniform int rarity = 0;
uniform bool has_face = false;
uniform sampler2D face_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool alpha_corners = false;

uniform int foil_style = 1;
// Line spacing of the film's grating. Wider spacing packs more rainbow
// orders into a small change of angle.
uniform float grating_nm = 1300.0;
// How much of the light the grating throws into the rainbow, and how far off
// the mirror angle it still reaches.
uniform float rainbow_strength = 1.0;
uniform float rainbow_spread = 0.75;
// The film's mirror shine (zeroth order) and how sharp it is.
uniform float mirror_strength = 0.6;
uniform float foil_roughness = 0.28;
// How much the printed ink lets the film's own colour through: 0 the
// reflection takes the ink's colour fully, 1 the film shows silver.
uniform float film_show_through = 0.3;
// The card isn't perfectly flat: a gentle warp across the face, in radians.
uniform float warp = 0.05;
// Etched: size of the grain (in card widths) and how far each grain tilts.
uniform float grain_size = 0.0025;
uniform float grain_tilt = 0.18;
// Sparkle (styles 3 and 4): the share of grains that are tilted glints, how
// far they tilt, and how sharp and bright their flash is.
uniform float sparkle_amount = 0.12;
uniform float sparkle_tilt = 0.45;
uniform float sparkle_roughness = 0.12;
uniform float sparkle_strength = 3.0;
// Crystal (style 4): facets across the card's width, how far each tilts,
// the width of the etched line between facets (in facet sizes), and how
// strongly each facet's fine lines show.
uniform float crystal_scale = 9.0;
uniform float crystal_tilt = 0.12;
uniform float etch_line_width = 0.06;
uniform float etch_line_contrast = 0.35;
uniform float etch_line_spacing = 0.008;
// How much the film mirrors the room around it (ambient reflections: the
// sky unless a ReflectionProbe has captured the room).
uniform float room_reflection = 0.0;
// How dark the ink reads where the film isn't catching any light.
uniform float foil_darkening = 0.25;

varying float foil_mask;
varying float film_shift;
// A glint's sparkle strength (0 for an ordinary grain).
varying float glint;
// The direction across a crystal facet's lines, in view space (zero where
// the film's lines run every way).
varying vec3 grating_across;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Where the art sits on a modern (2015) frame. Real masks would follow each
// card's frame.
bool in_art_box(vec2 uv) {
	return uv.x > 0.075 && uv.x < 0.925 && uv.y > 0.11 && uv.y < 0.555;
}

// Visible light of wavelength w (nm) as RGB (Zucconi's six-bump fit).
vec3 bump3y(vec3 x, vec3 y_offset) {
	return clamp(1.0 - x * x - y_offset, 0.0, 1.0);
}

vec3 spectrum(float w) {
	if (w < 400.0 || w > 700.0) {
		return vec3(0.0);
	}
	float x = (w - 400.0) / 300.0;
	const vec3 c1 = vec3(3.54585104, 2.93225262, 2.41593945);
	const vec3 x1 = vec3(0.69549072, 0.49228336, 0.27699880);
	const vec3 y1 = vec3(0.02312639, 0.15225084, 0.52607955);
	const vec3 c2 = vec3(3.90307140, 3.21182957, 3.96587128);
	const vec3 x2 = vec3(0.11748627, 0.86755042, 0.66077860);
	const vec3 y2 = vec3(0.84897130, 0.88445281, 0.73949448);
	return bump3y(c1 * (x - x1), y1) + bump3y(c2 * (x - x2), y2);
}

// Grating equation: order m comes out where the light and eye directions,
// projected onto the film, add to m * wavelength / spacing. The film's lines
// run every way (it's holographic film, not one grating), so only the length
// of that projection matters.
vec3 diffraction(vec3 n, vec3 l, vec3 v, float spacing, vec3 lines_across) {
	vec3 sum = l + v;
	vec3 flat_sum = sum - dot(sum, n) * n;
	float across = length(flat_sum);
	float along_lines = 0.0;
	if (dot(lines_across, lines_across) > 0.25) {
		// Lines running one way split light only across them: what lies
		// along the lines just spreads the rainbow out.
		across = abs(dot(flat_sum, lines_across));
		along_lines = length(flat_sum - lines_across * dot(flat_sum, lines_across));
	}
	vec3 color = vec3(0.0);
	for (int m = 1; m <= 3; m++) {
		color += spectrum(spacing * across / float(m)) / float(m);
	}
	// The grating throws most of its light close to the mirror angle.
	return color * exp(-across * across / (rainbow_spread * rainbow_spread)) * exp(-along_lines * along_lines / 0.4);
}

float ggx(float n_dot_h, float roughness) {
	float a = roughness * roughness;
	float a2 = a * a;
	float d = n_dot_h * n_dot_h * (a2 - 1.0) + 1.0;
	return a2 / (PI * d * d);
}

void fragment() {
	if (cut_away(UV, alpha_corners)) {
		discard;
	}
	vec3 color = FRONT_FACING
		? (has_face ? real_face(texture(face_texture, UV).rgb, UV, alpha_corners) : card_face(UV, accent, set_number, collector_number, rarity))
		: back_of_card(vec2(1.0 - UV.x, UV.y), alpha_corners);
	foil_mask = FRONT_FACING ? 1.0 : 0.0;
	if (foil_style == 2 && in_art_box(UV)) {
		foil_mask = 0.0;
	}
	// The film's grating isn't perfectly even: bands drift across the face.
	film_shift = (value_noise(UV * vec2(3.0, 4.0)) - 0.5) * 0.25;
	vec2 tilt = (vec2(value_noise(UV * 2.5 + 7.0), value_noise(UV * 2.5 + 19.0)) - 0.5) * 2.0 * warp;
	if (foil_style == 2 && foil_mask > 0.0) {
		// Etching leaves the foil as a field of tiny grains, each catching
		// the light at its own angle.
		vec2 cell = floor(UV * vec2(1.0, 1.4) / grain_size);
		tilt += (vec2(hash(cell), hash(cell + 31.0)) - 0.5) * 2.0 * grain_tilt;
		film_shift += (hash(cell + 77.0) - 0.5) * 0.3;
	}
	glint = 0.0;
	grating_across = vec3(0.0);
	vec2 card = UV * vec2(1.0, 1.4); // square units across the card
	if (foil_style == 4 && foil_mask > 0.0) {
		// Crystal facets: nearest and second-nearest of a jittered grid of
		// points (Voronoi), the gap between the two giving the etched line.
		vec2 q = card * crystal_scale;
		vec2 base = floor(q);
		float d1 = 8.0;
		float d2 = 8.0;
		vec2 facet = base;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 c = base + vec2(float(i), float(j));
				vec2 r = c + vec2(hash(c), hash(c + 13.1)) - q;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					facet = c;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
		float edge = sqrt(d2) - sqrt(d1);
		tilt += (vec2(hash(facet + 3.7), hash(facet + 9.2)) - 0.5) * 2.0 * crystal_tilt;
		film_shift += (hash(facet + 5.5) - 0.5) * 0.4;
		float angle = hash(facet + 21.3) * PI;
		vec2 across_2d = vec2(cos(angle), sin(angle));
		grating_across = normalize(TANGENT * across_2d.x + BINORMAL * across_2d.y);
		// The fine lines themselves, faintly, and the etched line between
		// facets where the foil is cut away.
		float line_position = dot(card, across_2d) / etch_line_spacing;
		float lines = 0.5 + 0.5 * sin(line_position * TAU);
		// Fade the lines out when they're too fine to draw without shimmering.
		float drawable = smoothstep(0.5, 0.25, fwidth(line_position));
		foil_mask *= 1.0 - etch_line_contrast * lines * drawable;
		foil_mask *= mix(0.6, 1.0, smoothstep(etch_line_width * 0.5, etch_line_width, edge));
	}
	if (foil_style >= 3 && foil_mask > 0.0) {
		vec2 cell = floor(card / grain_size);
		if (hash(cell + 41.0) < sparkle_amount) {
			tilt += (vec2(hash(cell), hash(cell + 31.0)) - 0.5) * 2.0 * sparkle_tilt;
			glint = sparkle_strength * hash(cell + 57.0);
		}
	}
	NORMAL = normalize(NORMAL + TANGENT * tilt.x + BINORMAL * tilt.y);
	// Under foil the ink has no white card behind it to scatter light back,
	// so the face reads darker except where the film catches the light.
	ALBEDO = color * (1.0 - foil_darkening * foil_mask);
	ROUGHNESS = mix(0.6, foil_roughness, foil_mask);
	METALLIC = room_reflection * foil_mask;
}

void light() {
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	vec3 incoming = LIGHT_COLOR * ATTENUATION * n_dot_l;
	DIFFUSE_LIGHT += incoming / PI;
	vec3 h = normalize(LIGHT + VIEW);
	float n_dot_h = max(dot(NORMAL, h), 0.0);
	// The ink and paper's own faint gloss, foil or not.
	SPECULAR_LIGHT += incoming * 0.04 * ggx(n_dot_h, 0.6) * 0.25;
	if (foil_mask > 0.0) {
		// Ink over the film filters what it reflects.
		float luma = dot(ALBEDO, vec3(0.299, 0.587, 0.114));
		vec3 ink = mix(ALBEDO, vec3(luma), film_show_through) / max(1.0 - foil_darkening * foil_mask, 0.01);
		vec3 mirror = vec3(ggx(n_dot_h, foil_roughness) * 0.25 * mirror_strength);
		// A glint is a tiny flat mirror: a sharp flash, nearly white.
		mirror += vec3(ggx(n_dot_h, sparkle_roughness) * 0.02 * glint);
		vec3 rainbow = diffraction(NORMAL, LIGHT, VIEW, grating_nm * (1.0 + film_shift), grating_across) * rainbow_strength;
		SPECULAR_LIGHT += incoming * foil_mask * ink * (mirror + rainbow);
	}
}
