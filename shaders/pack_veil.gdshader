shader_type spatial;
// The dark veil behind a pack being ripped (PackEffects): a black sheet
// hanging in front of the camera, darker toward the edges of the view.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float amount = 0.0;

void fragment() {
	// Where on screen this is, from the middle (0) to the corners (about 1).
	vec2 from_middle = (SCREEN_UV - 0.5) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0) * 1.6;
	float edge = smoothstep(0.15, 1.1, length(from_middle));
	ALBEDO = vec3(0.0);
	ALPHA = clamp(amount * mix(0.82, 1.0, edge) + amount * 0.25 * edge, 0.0, 0.97);
}
