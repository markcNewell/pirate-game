// Toon lighting: three flat steps of light instead of a smooth gradient, hard sun shadows,
// and a faint rim so silhouettes read against the sea. Colour comes from the mesh's vertex
// colours, so one material serves a whole model.
shader_type spatial;
render_mode cull_back;

uniform float rim_amount = 0.12;
uniform vec4 tint : source_color = vec4(1.0);

varying vec3 base_color;

void vertex() {
	base_color = COLOR.rgb;
}

void fragment() {
	ALBEDO = base_color * tint.rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = ALBEDO * rim * rim_amount;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (!LIGHT_IS_DIRECTIONAL) {
		// Lanterns: flat pools of light that step down with distance, lighting only the
		// faces that look toward them.
		float pool = ATTENUATION > 0.45 ? 1.0 : (ATTENUATION > 0.12 ? 0.55 : (ATTENUATION > 0.03 ? 0.22 : 0.0));
		DIFFUSE_LIGHT += (ndl > 0.0 ? 1.0 : 0.25) * pool * LIGHT_COLOR / PI;
	} else {
		// Lit, half-lit and shade. Shade keeps some sun so dark sides stay readable colours.
		float band = ndl > 0.45 ? 1.0 : (ndl > 0.0 ? 0.72 : 0.45);
		if (ATTENUATION < 0.5) {
			band = min(band, 0.45);
		}
		DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
	}
}
