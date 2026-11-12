// The view out of the shop's leaded windows (StoreBuilder._build_windows).
//
// The glass is a flat pane, but what's seen through it isn't painted on it:
// each pixel follows the line from the eye through the glass out to three
// upright picture planes standing outside, a near one (railings, a hedge), a
// middle one (the houses across the street) and a far one (rooftops, trees,
// the sky), and shows whatever of each picture it meets there, nearest first.
// So the view shifts with parallax as you walk past, like a real window.
//
// Old hand-made glass: every diamond quarry bends the view by its own small
// tilt and ripple and softens it, and the lead came is drawn over the top.
// The DayCycle tints the whole view (`daylight`), so it dims to dusk and
// dark at night.
//
// The three pictures are drop-in images in assets/store/window_view/ (see
// SOURCE.txt there); each says where it stands with its *_rect uniform.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform sampler2D near_layer : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D mid_layer : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D far_layer : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D leaded : source_color, filter_linear_mipmap;
// Each layer: (left x, bottom y, width, height) in room metres, and how far
// outside the window wall it stands.
uniform vec4 near_rect = vec4(-1.0, -0.6, 14.0, 3.5);
uniform vec4 mid_rect = vec4(-14.0, -1.0, 40.0, 16.0);
uniform vec4 far_rect = vec4(-50.0, -4.0, 112.0, 42.0);
uniform float near_depth = 1.6;
uniform float mid_depth = 11.0;
uniform float far_depth = 40.0;
// The outside of the window wall, along +z.
uniform float wall_z = 8.0;
// The view's tint and brightness, from the DayCycle.
uniform vec4 daylight : source_color = vec4(1.0);
// Diamond quarries across and down one pane (tools/bake_leaded_glass.py).
uniform vec2 quarries = vec2(10.0, 3.5);
// How far each quarry tilts the view (radians), and how soft it makes it.
uniform float tilt = 0.012;
uniform float softness = 2.2;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Where the ray meets the plane `depth` past the wall, as a layer's UV.
vec2 layer_uv(vec3 from, vec3 dir, float depth, vec4 rect) {
	float t = (wall_z + depth - from.z) / max(dir.z, 0.001);
	vec3 hit = from + dir * t;
	return vec2((hit.x - rect.x) / rect.z, 1.0 - (hit.y - rect.y) / rect.w);
}

vec4 layer(sampler2D tex, vec2 uv, float lod) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec4(0.0);
	}
	return textureLod(tex, uv, lod);
}

void fragment() {
	vec3 eye = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 dir = normalize(world_pos - eye);

	// Which diamond quarry this is: the pane's UV in diamond coordinates.
	vec2 p = UV * quarries;
	vec2 cell = floor(vec2(p.x + p.y, p.x - p.y) + 0.5);
	float a = hash(cell) * 6.2831;
	float ripple = sin(dot(UV, vec2(37.0, 23.0)) + hash(cell + 7.0) * 6.0) * 0.004;
	dir = normalize(dir + vec3(cos(a), sin(a), 0.0) * (tilt * hash(cell + 3.0)) + vec3(ripple, ripple * 0.6, 0.0));

	float lod = softness + hash(cell + 11.0);
	vec3 colour = layer(far_layer, layer_uv(world_pos, dir, far_depth, far_rect), lod + 0.6).rgb;
	vec4 mid = layer(mid_layer, layer_uv(world_pos, dir, mid_depth, mid_rect), lod);
	colour = mix(colour, mid.rgb, mid.a);
	vec4 near = layer(near_layer, layer_uv(world_pos, dir, near_depth, near_rect), lod - 0.4);
	colour = mix(colour, near.rgb, near.a);

	vec3 glass = texture(leaded, UV).rgb;
	ALBEDO = colour * glass * daylight.rgb;
}
