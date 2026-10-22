// The nameplates on the shelf: plate and lettering in one mesh. Each vertex
// carries its albedo in COLOR and its metallic and roughness in UV, so black
// enamel, gold and embossed letters share one draw call. `glow` lights a
// plate up while it turns gold.
shader_type spatial;

instance uniform float glow = 0.0;
uniform vec3 glow_color : source_color = vec3(1.0, 0.8, 0.45);

void fragment() {
	ALBEDO = COLOR.rgb;
	METALLIC = UV.x;
	ROUGHNESS = UV.y;
	EMISSION = glow_color * glow * 1.6;
}
