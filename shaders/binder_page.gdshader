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

// Keep in step with Binder.PAGE and Binder.CELL.
const vec2 PAGE = vec2(0.24, 0.31);
const vec2 CELL = vec2(0.074, 0.099);
const vec2 POCKET = vec2(0.067, 0.092);

void fragment() {
	vec3 color = page_color;
	if (used_pockets > 0) {
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
	ROUGHNESS = 0.7;
	EMISSION = glow.rgb * glow.a;
}
