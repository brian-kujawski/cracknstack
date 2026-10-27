// Foil, as on the rare cards: the face printed over a metallised film, an
// etched "crystal" pattern cut into it. Included by the card shaders when
// FOIL is defined (see held_card, binder_card and floor_card).
//
// All its shine comes from the room's real lights through light(), so it
// changes with where the card is and which way it faces, like any card. The
// film is a diffraction grating: light that isn't mirrored straight back is
// split into a rainbow, its hue set by the angle between the light and the
// eye across the film's lines. The film is cut into facets, each tilted a
// touch and lined its own way, so each catches the light at its own angle
// and colour; a few tiny grains are tilted further and glint. Ink sits on
// top and tints what the film reflects; dark ink lets less through.

// Line spacing of the film's grating. Wider spacing packs more rainbow
// orders into a small change of angle.
const float GRATING_NM = 1300.0;
// How far off the mirror angle the rainbow still reaches, across the lines
// and along them.
const float RAINBOW_SPREAD = 0.75;
const float RAINBOW_ALONG_LINES = 0.4;
// The film's mirror shine and how sharp it is.
const float MIRROR_STRENGTH = 0.6;
const float FOIL_ROUGHNESS = 0.28;
// How much the ink lets the film's own colour through: 0 the reflection
// takes the ink's colour fully, 1 the film shows silver.
const float FILM_SHOW_THROUGH = 0.3;
// How dark the ink reads where the film isn't catching any light: under
// foil there's no white card behind the ink to scatter light back.
const float FOIL_DARKENING = 0.25;
// The card isn't perfectly flat: a gentle warp across the face, in radians.
const float WARP = 0.05;
// Facets across the card's width, how far each tilts (radians), and the
// etched line between them (in facet sizes), where the foil is cut away.
const float CRYSTAL_SCALE = 9.0;
const float CRYSTAL_TILT = 0.12;
const float ETCH_LINE_WIDTH = 0.06;
// Each facet's fine lines: spacing (in card widths) and how strongly they
// show.
const float FINE_LINE_SPACING = 0.008;
const float FINE_LINE_CONTRAST = 0.35;
// Glints: grain size (in card widths), the share of grains that glint, how
// far they tilt, and how sharp and bright their flash is.
const float GRAIN_SIZE = 0.0025;
const float SPARKLE_AMOUNT = 0.06;
const float SPARKLE_TILT = 0.45;
const float SPARKLE_ROUGHNESS = 0.12;
const float SPARKLE_STRENGTH = 3.0;

// What fragment() hands on to light(), per point on the card.
varying float foil_mask;     // how much film shows (0 none)
varying float foil_shift;    // local change in the grating's spacing
varying float foil_glint;    // a glint's strength (0 for an ordinary grain)
varying vec3 foil_across;    // across the facet's lines, view space

struct Foil {
	vec3 normal;
	float mask;
	float shift;
	float glint;
	vec3 across;
};

float foil_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float foil_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(foil_hash(i), foil_hash(i + vec2(1.0, 0.0)), u.x),
			mix(foil_hash(i + vec2(0.0, 1.0)), foil_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// The film at uv on the card's face (normal, tangent and binormal in view
// space, tangent along u and binormal along v).
Foil foil_at(vec2 uv, vec3 normal, vec3 tangent, vec3 binormal) {
	Foil foil;
	foil.mask = 1.0;
	foil.glint = 0.0;
	// The grating isn't perfectly even: bands drift across the face.
	foil.shift = (foil_noise(uv * vec2(3.0, 4.0)) - 0.5) * 0.25;
	vec2 tilt = (vec2(foil_noise(uv * 2.5 + 7.0), foil_noise(uv * 2.5 + 19.0)) - 0.5) * 2.0 * WARP;
	vec2 card = uv * vec2(1.0, 1.4); // square units across the card

	// Facets: nearest and second-nearest of a jittered grid of points
	// (Voronoi), the gap between the two giving the etched line.
	vec2 q = card * CRYSTAL_SCALE;
	vec2 base = floor(q);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 facet = base;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = base + vec2(float(i), float(j));
			vec2 r = c + vec2(foil_hash(c), foil_hash(c + 13.1)) - q;
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
	tilt += (vec2(foil_hash(facet + 3.7), foil_hash(facet + 9.2)) - 0.5) * 2.0 * CRYSTAL_TILT;
	foil.shift += (foil_hash(facet + 5.5) - 0.5) * 0.4;
	float angle = foil_hash(facet + 21.3) * PI;
	vec2 across = vec2(cos(angle), sin(angle));
	foil.across = normalize(tangent * across.x + binormal * across.y);
	// The fine lines, faded out where they're too fine to draw without
	// shimmering, and the etched line between facets.
	float line_position = dot(card, across) / FINE_LINE_SPACING;
	float lines = 0.5 + 0.5 * sin(line_position * TAU);
	foil.mask *= 1.0 - FINE_LINE_CONTRAST * lines * smoothstep(0.5, 0.25, fwidth(line_position));
	foil.mask *= mix(0.6, 1.0, smoothstep(ETCH_LINE_WIDTH * 0.5, ETCH_LINE_WIDTH, edge));

	vec2 grain = floor(card / GRAIN_SIZE);
	if (foil_hash(grain + 41.0) < SPARKLE_AMOUNT) {
		tilt += (vec2(foil_hash(grain), foil_hash(grain + 31.0)) - 0.5) * 2.0 * SPARKLE_TILT;
		foil.glint = SPARKLE_STRENGTH * foil_hash(grain + 57.0);
	}
	foil.normal = normalize(normal + tangent * tilt.x + binormal * tilt.y);
	return foil;
}

// Visible light of wavelength w (nm) as RGB (Zucconi's six-bump fit).
vec3 foil_bump(vec3 x, vec3 y_offset) {
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
	return foil_bump(c1 * (x - x1), y1) + foil_bump(c2 * (x - x2), y2);
}

// Grating equation: order m comes out where the light and eye directions,
// projected onto the film across its lines, add to m * wavelength / spacing.
// What lies along the lines just spreads the rainbow out.
vec3 diffraction(vec3 n, vec3 l, vec3 v, float spacing, vec3 lines_across) {
	vec3 sum = l + v;
	vec3 flat_sum = sum - dot(sum, n) * n;
	float across = abs(dot(flat_sum, lines_across));
	float along = length(flat_sum - lines_across * dot(flat_sum, lines_across));
	vec3 color = vec3(0.0);
	for (int m = 1; m <= 3; m++) {
		color += spectrum(spacing * across / float(m)) / float(m);
	}
	// The grating throws most of its light close to the mirror angle.
	return color * exp(-across * across / (RAINBOW_SPREAD * RAINBOW_SPREAD)) * exp(-along * along / RAINBOW_ALONG_LINES);
}

float foil_ggx(float n_dot_h, float roughness) {
	float a = roughness * roughness;
	float a2 = a * a;
	float d = n_dot_h * n_dot_h * (a2 - 1.0) + 1.0;
	return a2 / (PI * d * d);
}

// How dark ink reads over film (see FOIL_DARKENING), for ALBEDO.
vec3 ink_over_foil(vec3 color, float mask) {
	return color * (1.0 - FOIL_DARKENING * mask);
}

// One light's share, for light(): plain diffuse, the paper's own faint
// gloss, and where there's film its mirror shine, rainbow and glints.
// `albedo` is what fragment() set (ink_over_foil()).
void foil_light(vec3 n, vec3 l, vec3 v, vec3 light_color, float attenuation, vec3 albedo,
		float mask, float shift, float glint, vec3 across, inout vec3 diffuse, inout vec3 specular) {
	vec3 incoming = light_color * attenuation * max(dot(n, l), 0.0);
	diffuse += incoming / PI;
	float n_dot_h = max(dot(n, normalize(l + v)), 0.0);
	specular += incoming * 0.01 * foil_ggx(n_dot_h, 0.6);
	if (mask > 0.0) {
		float luma = dot(albedo, vec3(0.299, 0.587, 0.114));
		vec3 ink = mix(albedo, vec3(luma), FILM_SHOW_THROUGH) / (1.0 - FOIL_DARKENING * mask);
		// A glint is a tiny flat mirror: a sharp flash, nearly white.
		float mirror = foil_ggx(n_dot_h, FOIL_ROUGHNESS) * 0.25 * MIRROR_STRENGTH
				+ foil_ggx(n_dot_h, SPARKLE_ROUGHNESS) * 0.02 * glint;
		vec3 rainbow = diffraction(n, l, v, GRATING_NM * (1.0 + shift), across);
		specular += incoming * mask * ink * (mirror + rainbow);
	}
}
