shader_type spatial;
// A binder's cover leather (binder.gd), mapped in the binder's own space so
// it moves with it, with its lettering (BinderLettering) pressed into it.
//
// Colour: the set's dye (Binder.leather_colour) times the leather map's own
// light and dark, measured against its average, so any leather texture
// dropped into assets/store/leather/ gives its grain and mottling but the
// set still decides the colour. A slow, broad mottle on top keeps a large
// cover from looking like one flat sheet of plastic, and the covers darken
// a little toward their edges, where real leather is burnished by handling.
//
// Lettering: where the masks are white the leather is pressed in (with the
// edges of each letter catching the light) and filled with silver foil,
// which turns to gold leaf as `gilt` goes to 1. A blind-tooled rule (pressed,
// no foil) frames the cover.

uniform vec3 dye : source_color = vec3(0.4, 0.2, 0.15);
uniform sampler2D leather_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leather_roughness : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leather_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mottle : filter_linear_mipmap, repeat_enable;
// The leather map's average brightness (linear), and how much of its light
// and dark comes through.
uniform float leather_mean = 0.9;
uniform float grain_contrast = 1.0;
// One copy of the leather map per this many metres.
uniform float leather_size = 0.4;
uniform float normal_strength = 3.0;
uniform float roughness_scale = 1.0;
uniform float mottle_size = 0.35;
uniform float mottle_amount = 0.18;
uniform float burnish = 0.3;
uniform vec3 glow : source_color = vec3(0.0);

// Binder size: half the cover (x, z), and the thickness.
uniform vec2 cover_half = vec2(0.13, 0.165);
uniform float thickness = 0.05;
// Lettering masks and where they sit: the cover's as x, z, width, depth;
// the spine's as its z start and length (it spans the whole thickness).
uniform sampler2D cover_mask : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform vec4 cover_rect;
uniform sampler2D spine_mask : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform vec2 spine_span;
// The blind-tooled rule round the cover: its inset from the edges (x, z)
// and its width, in metres.
uniform vec3 rule = vec3(0.026, 0.024, 0.0014);
// How deep the letters and rule are pressed in (metres), and silver foil
// (0) to gold leaf (1).
uniform float press_depth = 0.0004;
uniform float gilt = 0.0;
const vec3 SILVER = vec3(0.78, 0.78, 0.8);
const vec3 GOLD = vec3(0.86, 0.66, 0.32);

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

vec3 triplanar_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / (w.x + w.y + w.z);
}

// A texture projected along each axis and blended by `w`. (A macro, since
// a function can't take samplers with different hints.)
#define TRIPLANAR(tex, p, w) (texture(tex, (p).zy) * (w).x + texture(tex, (p).xz) * (w).y + texture(tex, (p).xy) * (w).z)

// The normal map in the binder's space ("whiteout" blend of the three
// projections).
vec3 triplanar_normal(vec3 p, vec3 n, vec3 w) {
	vec3 tx = texture(leather_normal, p.zy).rgb * 2.0 - 1.0;
	vec3 ty = texture(leather_normal, p.xz).rgb * 2.0 - 1.0;
	vec3 tz = texture(leather_normal, p.xy).rgb * 2.0 - 1.0;
	tx.xy *= normal_strength;
	ty.xy *= normal_strength;
	tz.xy *= normal_strength;
	vec3 nx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	vec3 ny = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	vec3 nz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(nx.zyx * w.x + ny.xzy * w.y + nz.xyz * w.z);
}

// How much of the cover's front, at an x, z point, is pressed in by the
// lettering and by the framing rule.
vec2 cover_marks(vec2 p) {
	vec2 uv = (p - cover_rect.xy) / cover_rect.zw;
	float letters = 0.0;
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) {
		letters = textureLod(cover_mask, uv, 0.6).r;
	}
	vec2 d = abs(p) - (cover_half - rule.xy);
	float edge = abs(length(max(d, 0.0)) + min(max(d.x, d.y), 0.0));
	float frame = 1.0 - smoothstep(rule.z * 0.5 - 0.0003, rule.z * 0.5 + 0.0003, edge);
	return vec2(letters, frame);
}

float cover_press(vec2 p) {
	vec2 marks = cover_marks(p);
	return max(marks.x, marks.y);
}

float spine_press(vec2 p) {
	vec2 uv = vec2((p.x - spine_span.x) / spine_span.y, 1.0 - p.y / thickness);
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return 0.0;
	}
	return textureLod(spine_mask, uv, 0.6).r;
}

void fragment() {
	vec3 n = normalize(local_normal);
	vec3 w = triplanar_weights(n);
	vec3 p = local_pos / leather_size;
	vec3 leather = TRIPLANAR(leather_albedo, p, w).rgb;
	float shade = mix(1.0, dot(leather, vec3(0.2126, 0.7152, 0.0722)) / leather_mean, grain_contrast);
	float broad = TRIPLANAR(mottle, local_pos / mottle_size, w).r;
	shade *= 1.0 + (broad - 0.5) * 2.0 * mottle_amount;
	// Burnished edges on the front and back covers.
	vec2 to_edge = cover_half - abs(local_pos.xz);
	shade *= 1.0 - burnish * w.y * (1.0 - smoothstep(0.0, 0.02, min(to_edge.x, to_edge.y)));
	vec3 albedo = dye * shade;
	float roughness = clamp(TRIPLANAR(leather_roughness, p, w).r * roughness_scale, 0.05, 1.0);
	vec3 normal = triplanar_normal(p, n, w);

	// Lettering: the press amount at this point and its slope, from either
	// the front cover or the spine.
	float press = 0.0;
	float letters = 0.0;
	vec3 slope = vec3(0.0);
	const float STEP = 0.0005;
	if (n.y > 0.5 && local_pos.y > thickness - 0.002) {
		vec2 q = local_pos.xz;
		vec2 marks = cover_marks(q);
		letters = marks.x;
		press = max(marks.x, marks.y);
		vec2 grad = vec2(cover_press(q + vec2(STEP, 0.0)) - cover_press(q - vec2(STEP, 0.0)),
			cover_press(q + vec2(0.0, STEP)) - cover_press(q - vec2(0.0, STEP))) / (2.0 * STEP);
		// Pressed in: walls slope toward the inside of each letter.
		slope = vec3(grad.x, 0.0, grad.y) * press_depth;
	} else if (n.x < -0.25 && local_pos.x < -cover_half.x + 0.009) {
		vec2 q = local_pos.zy;
		press = spine_press(q);
		letters = press;
		vec2 grad = vec2(spine_press(q + vec2(STEP, 0.0)) - spine_press(q - vec2(STEP, 0.0)),
			spine_press(q + vec2(0.0, STEP)) - spine_press(q - vec2(0.0, STEP))) / (2.0 * STEP);
		slope = vec3(0.0, grad.y, grad.x) * press_depth;
	}
	// Pressed leather is compacted: darker, smoother and flatter.
	albedo *= 1.0 - 0.7 * press;
	roughness = mix(roughness, roughness * 0.8, press);
	normal = normalize(mix(normal, n, press * 0.6) + slope);
	// Foil in the letters only; the framing rule stays blind.
	albedo = mix(albedo, mix(SILVER, GOLD, gilt), letters);
	roughness = mix(roughness, 0.32, letters);
	normal = normalize(mix(normal, normalize(n + slope), letters * 0.7));

	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = letters;
	NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(normal, 0.0))).xyz);
	EMISSION = glow;
}
