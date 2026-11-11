// One 9-pocket binder page, lying flat. Empty pockets show their collector
// number faintly so you can see where a card goes; the cards themselves are
// separate quads laid on top.
shader_type spatial;

#include "res://shaders/card_face.gdshaderinc"

// Collector number of the page's first pocket.
uniform int first_number = 0;
// How many of the 9 pockets have a number (the last page can be short; 0
// for a bare inside cover).
uniform int used_pockets = 0;
uniform vec3 page_color = vec3(0.1, 0.1, 0.11);
// rgb colour, a strength: lights up when the page is complete.
uniform vec4 glow = vec4(0.0);
// The inside of a cover (no page there): marbled endpaper (style bible §8),
// turned, mirrored and offset per set (Binder.endpaper_pose) so no two
// binders' papers line up the same way.
uniform bool endpaper_on = false;
uniform sampler2D endpaper : source_color, filter_linear_mipmap, repeat_enable;
// x quarter turns (0-3), y mirrored (0/1), zw offset in tiles.
uniform vec4 endpaper_pose = vec4(0.0);
// How many metres one tile of the paper covers.
const float ENDPAPER_TILE = 0.32;

// Keep in step with Binder.PAGE and Binder.CELL.
const vec2 PAGE = vec2(0.24, 0.31);
const vec2 CELL = vec2(0.074, 0.099);
const vec2 POCKET = vec2(0.067, 0.092);

void fragment() {
	vec3 color = page_color;
	if (endpaper_on) {
		vec2 uv = UV * PAGE / ENDPAPER_TILE;
		for (int i = 0; i < int(endpaper_pose.x); i++) {
			uv = vec2(uv.y, -uv.x);
		}
		if (endpaper_pose.y > 0.5) {
			uv.x = -uv.x;
		}
		// A touch dimmer than the paper itself, so the cards stay the brightest
		// thing in an open binder.
		color = texture(endpaper, uv + endpaper_pose.zw).rgb * 0.82;
	} else if (used_pockets > 0) {
		vec2 m = (UV - 0.5) * PAGE;
		vec2 cell = clamp(floor(m / CELL + 1.5), vec2(0.0), vec2(2.0));
		vec2 d = m - (cell - 1.0) * CELL;
		int index = int(cell.y) * 3 + int(cell.x);
		if (index < used_pockets && abs(d.x) < POCKET.x * 0.5 && abs(d.y) < POCKET.y * 0.5) {
			color = page_color + vec3(0.07);
			vec2 p = d / POCKET + 0.5;
			float ink = number_mask(first_number + index, 3, p, vec2(0.2, 0.42), vec2(0.2, 0.16));
			color = mix(color, vec3(0.42), ink);
		}
	}
	ALBEDO = color;
	ROUGHNESS = endpaper_on ? 0.85 : 0.7;
	EMISSION = glow.rgb * glow.a;
}
