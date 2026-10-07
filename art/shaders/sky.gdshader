// Cartoon sky: a blue gradient down to a pale horizon and a hard-edged sun with a halo ring.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.184, 0.561, 0.941);
uniform vec3 horizon_color : source_color = vec3(0.769, 0.914, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.965, 0.847);

void sky() {
	float h = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.5));
	if (LIGHT0_ENABLED) {
		float d = dot(EYEDIR, LIGHT0_DIRECTION);
		if (d > 0.9993) {
			col = sun_color * 1.4;
		} else if (d > 0.9972 && d < 0.9980) {
			col = mix(col, sun_color, 0.45);
		}
	}
	COLOR = col;
}
