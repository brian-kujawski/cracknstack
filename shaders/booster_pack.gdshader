shader_type spatial;
// A booster pack's foil wrapper (BoosterPack). UV is the pack's own
// front-face space (u left to right, v top to bottom, as you look at the
// front); UV2.x says which surface this is: 0 the front, 1 the back, 2 the
// rim joining them (the crimped seams, and the inside of a tear).
//
// With art for the set (assets/packs/<code>.png, and <code>_back.png) the
// wrapper shows it under the foil; otherwise it draws a stand-in in the
// set's colour with its name lettered on (`lettering`, `back_lettering`).
//
// `tear` is how far across the top the wrapper has torn (0 to 1, from the
// left): the paper shows white along a ragged line just under the top crimp.
// The part above that line is a mesh of its own (`cap` true), which
// BoosterPack peels up and finally flings away.
render_mode cull_back;

uniform vec3 accent = vec3(0.4, 0.3, 0.6);
uniform bool has_art = false;
uniform sampler2D art : source_color, filter_linear_mipmap, repeat_disable;
uniform bool has_back_art = false;
uniform sampler2D back_art : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D lettering : filter_linear_mipmap, repeat_disable;
uniform sampler2D back_lettering : filter_linear_mipmap, repeat_disable;
// Crimped seams top and bottom, as a share of the height.
uniform float crimp = 0.075;
uniform float tear_v = 0.1;
uniform float tear = 0.0;
uniform bool cap = false;

const vec3 SILVER = vec3(0.78, 0.79, 0.82);
const vec3 GOLD = vec3(0.95, 0.78, 0.38);
const vec3 PAPER = vec3(0.93, 0.92, 0.88);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 s = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), s.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), s.x), s.y);
}

// Where the tear runs, as v at this u: a ragged line a little under tear_v.
float tear_line(float u) {
	return tear_v + 0.004 + 0.006 * noise(vec2(u * 45.0, 3.7)) + 0.002 * noise(vec2(u * 160.0, 9.1));
}

// The stand-in front: the set's colour, darker toward the foot, a pale
// band behind the name, a ring of rays above it, and a sheen across.
vec3 stand_in_front(vec2 uv) {
	vec3 base = accent * mix(1.05, 0.55, uv.y);
	vec2 c = (uv - vec2(0.5, 0.36)) * vec2(1.0, 117.0 / 66.0);
	float r = length(c);
	float rays = step(0.5, fract(atan(c.y, c.x) / 6.2831853 * 24.0));
	base = mix(base, mix(base, GOLD, 0.55), (1.0 - smoothstep(0.17, 0.18, r)) * smoothstep(0.12, 0.13, r) * rays);
	base = mix(base, GOLD, smoothstep(0.115, 0.11, r) * smoothstep(0.1, 0.105, r));
	float band = smoothstep(0.585, 0.59, uv.y) * smoothstep(0.785, 0.78, uv.y);
	base = mix(base, base * 0.35, band);
	base = mix(base, GOLD, texture(lettering, uv).r);
	return base;
}

vec3 stand_in_back(vec2 uv) {
	vec3 base = accent * 0.45;
	float stripes = step(0.5, fract((uv.x + uv.y * 0.56) * 14.0));
	base = mix(base, accent * 0.6, stripes * 0.5);
	return mix(base, SILVER, texture(back_lettering, uv).r);
}

void fragment() {
	vec2 uv = UV;
	int surface = int(UV2.x + 0.5);
	bool seam = uv.y < crimp || uv.y > 1.0 - crimp;
	vec3 colour;
	float metal = 0.75;
	float rough = 0.32;
	if (surface == 2) {
		colour = SILVER * 0.8;
		rough = 0.45;
	} else if (surface == 0) {
		colour = has_art ? texture(art, uv).rgb : stand_in_front(uv);
	} else {
		// Seen from behind, the front's u runs the other way.
		vec2 back_uv = vec2(1.0 - uv.x, uv.y);
		colour = has_back_art ? texture(back_art, back_uv).rgb : stand_in_back(back_uv);
	}
	vec3 bump = vec3(0.0);
	if (surface != 2) {
		// Crinkled foil everywhere, and the crimps' fine ridges at the seams.
		float n1 = noise(uv * vec2(38.0, 66.0));
		float n2 = noise(uv * vec2(38.0, 66.0) + vec2(0.37, 0.0));
		float n3 = noise(uv * vec2(38.0, 66.0) + vec2(0.0, 0.37));
		bump.x = (n2 - n1) * 1.2;
		bump.y = (n3 - n1) * 1.2;
		if (seam) {
			bump.x += cos(uv.x * 6.2831853 * 70.0) * 0.6;
			colour = mix(colour, SILVER, 0.35);
			rough = 0.4;
		}
		// The tear: paper shows white along it, and above the line on the
		// body (below it on the cap) the wrapper's gone.
		if (uv.x < tear) {
			float line = tear_line(uv.x);
			if (!cap) {
				if (uv.y < line) {
					discard;
				}
				if (uv.y < line + 0.003) {
					colour = PAPER;
					metal = 0.0;
					rough = 0.9;
					bump = vec3(0.0);
				}
			} else if (uv.y > tear_v - 0.003) {
				colour = PAPER;
				metal = 0.0;
				rough = 0.9;
				bump = vec3(0.0);
			}
		}
	}
	ALBEDO = colour;
	METALLIC = metal;
	ROUGHNESS = rough;
	NORMAL = normalize(NORMAL + (TANGENT * bump.x - BINORMAL * bump.y) * 0.08);
}
