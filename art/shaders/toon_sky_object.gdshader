// The toon look for things on the horizon (clouds): same steps, but fog never washes them out.
shader_type spatial;
render_mode cull_back, fog_disabled;

varying vec3 base_color;

void vertex() {
	base_color = COLOR.rgb;
}

void fragment() {
	ALBEDO = base_color;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = ndl > 0.3 ? 1.0 : 0.7;
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
