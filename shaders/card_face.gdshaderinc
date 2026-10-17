// Placeholder card face, drawn entirely in the shader so ~30,000 distinct
// cards need no textures (plan §4.3). With real data the shaders sample the
// card's image instead and only use real_face() and back_of_card() below.
//
// Layout (UV y runs top to bottom):
//   set-tinted border · set number top-left · tinted art box ·
//   rarity pip bottom-left · collector number bottom-right.

const float BORDER = 0.06;

// Seven-segment digit. Bits: 0 top, 1 top-right, 2 bottom-right, 3 bottom,
// 4 bottom-left, 5 top-left, 6 middle.
const int DIGIT_SEGMENTS[10] = int[](0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F);

float box_mask(vec2 p, vec2 lo, vec2 hi) {
	vec2 inside = step(lo, p) * step(p, hi);
	return inside.x * inside.y;
}

// p in [0,1]^2 with y up.
float digit_mask(int digit, vec2 p) {
	if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) {
		return 0.0;
	}
	int s = DIGIT_SEGMENTS[clamp(digit, 0, 9)];
	float t = 0.16;
	float m = 0.0;
	m += float((s >> 0) & 1) * box_mask(p, vec2(t, 1.0 - t), vec2(1.0 - t, 1.0));
	m += float((s >> 1) & 1) * box_mask(p, vec2(1.0 - t, 0.5), vec2(1.0, 1.0 - t * 0.5));
	m += float((s >> 2) & 1) * box_mask(p, vec2(1.0 - t, t * 0.5), vec2(1.0, 0.5));
	m += float((s >> 3) & 1) * box_mask(p, vec2(t, 0.0), vec2(1.0 - t, t));
	m += float((s >> 4) & 1) * box_mask(p, vec2(0.0, t * 0.5), vec2(t, 0.5));
	m += float((s >> 5) & 1) * box_mask(p, vec2(0.0, 0.5), vec2(t, 1.0 - t * 0.5));
	m += float((s >> 6) & 1) * box_mask(p, vec2(t, 0.5 - t * 0.5), vec2(1.0 - t, 0.5 + t * 0.5));
	return min(m, 1.0);
}

// Draws `value` with exactly `count` digits (leading zeros) in the box whose
// top-left corner is `origin` (UV space) with per-digit size `cell`.
float number_mask(int value, int count, vec2 uv, vec2 origin, vec2 cell) {
	vec2 local = (uv - origin) / cell;
	if (local.y < 0.0 || local.y > 1.0 || local.x < 0.0 || local.x >= float(count)) {
		return 0.0;
	}
	int index = int(floor(local.x));
	int divisor = 1;
	for (int i = 0; i < count - 1 - index; i++) {
		divisor *= 10;
	}
	int digit = (value / divisor) % 10;
	vec2 p = vec2(fract(local.x) * 1.25 - 0.1, 1.0 - local.y);
	return digit_mask(digit, p);
}

vec3 rarity_color(int rarity) {
	if (rarity == 1) return vec3(0.75, 0.78, 0.82); // uncommon: silver
	if (rarity == 2) return vec3(0.9, 0.72, 0.25);  // rare: gold
	if (rarity == 3) return vec3(0.95, 0.42, 0.12); // mythic: orange
	return vec3(0.08, 0.08, 0.08);                  // common: black
}

vec3 card_back(vec2 uv) {
	vec3 base = vec3(0.32, 0.2, 0.12);
	vec2 c = (uv - 0.5) * vec2(1.0, 1.4);
	float oval = 1.0 - smoothstep(0.30, 0.32, length(c));
	return mix(base, vec3(0.55, 0.38, 0.2), oval);
}

vec3 card_face(vec2 uv, vec3 accent, int set_number, int collector_number, int rarity) {
	vec3 ink = accent * 0.25;
	if (uv.x < BORDER || uv.x > 1.0 - BORDER || uv.y < BORDER * 0.75 || uv.y > 1.0 - BORDER * 0.75) {
		return accent;
	}
	vec3 color = vec3(0.93, 0.9, 0.84);
	// Art box.
	if (box_mask(uv, vec2(0.12, 0.2), vec2(0.88, 0.62)) > 0.0) {
		color = mix(accent, vec3(1.0), 0.45);
	}
	// Set number, top-left (the "set symbol" for placeholders).
	float ink_mask = number_mask(set_number, 3, uv, vec2(0.1, 0.06), vec2(0.075, 0.09));
	// Collector number, bottom-right, larger.
	ink_mask = max(ink_mask, number_mask(collector_number, 3, uv, vec2(0.52, 0.72), vec2(0.115, 0.17)));
	color = mix(color, ink, ink_mask);
	// Rarity pip.
	if (length((uv - vec2(0.2, 0.81)) * vec2(1.0, 1.4)) < 0.06) {
		color = rarity_color(rarity);
	}
	return color;
}

// A real card image (sampled at uv) with its corners rounded off like a
// real card's, so the scan's corner background doesn't show.
const vec2 CORNER_RADIUS = vec2(0.048, 0.034); // ~3 mm on a 63 × 88 mm card

vec3 real_face(vec3 sampled, vec2 uv) {
	vec2 into_corner = max(abs(uv - 0.5) - (0.5 - CORNER_RADIUS), 0.0) / CORNER_RADIUS;
	return length(into_corner) > 1.0 ? vec3(0.02) : sampled;
}

// The real card back, one image for every card, when real data is loaded.
uniform bool has_back = false;
uniform sampler2D back_texture : source_color, filter_linear_mipmap, repeat_disable;

// The back of a card, with uv reading the right way round as you look at it.
vec3 back_of_card(vec2 uv) {
	return has_back ? real_face(texture(back_texture, uv).rgb, uv) : card_back(uv);
}
