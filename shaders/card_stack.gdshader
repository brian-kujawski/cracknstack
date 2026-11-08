shader_type spatial;
// The edges of a run of cards standing in a sorting tray (SortingTray): off
// white with a faint line between each card, fading to an even tone where
// the lines get too fine to see. The mesh is a unit box whose local z runs
// through the cards, front to back.

uniform float cards = 1.0;
uniform vec3 paper : source_color = vec3(0.9, 0.9, 0.88);
uniform vec3 seam : source_color = vec3(0.6, 0.6, 0.58);

varying vec3 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float u = (local.z + 0.5) * cards;
	float w = fwidth(u);
	float d = abs(fract(u + 0.5) - 0.5); // How far from the nearest gap, in cards.
	float line = 1.0 - smoothstep(0.15 - w, 0.15 + w, d);
	float fade = clamp(1.5 - w * 2.0, 0.0, 1.0); // Lines thinner than a pixel blur to an average.
	ALBEDO = mix(paper, seam, mix(0.3, line, fade));
	ROUGHNESS = 0.8;
}
