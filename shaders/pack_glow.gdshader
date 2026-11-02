shader_type spatial;
// The burst of colour behind a rare or mythic card as it's revealed
// (PackEffects): a soft round glow with a few rays turning slowly.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 colour = vec3(1.0, 0.8, 0.3);
uniform float amount = 0.0;

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float core = exp(-r * r * 9.0) * smoothstep(1.0, 0.6, r);
	float angle = atan(p.y, p.x) + TIME * 0.4;
	float rays = pow(0.5 + 0.5 * cos(angle * 12.0), 6.0) * smoothstep(1.0, 0.3, r);
	ALBEDO = colour * (core * 0.9 + rays * 0.45) * amount;
}
