// Cartoon sky: a gradient down to the horizon, a hard-edged sun with a halo ring, a warm blush
// on the horizon around the sun at dawn and dusk, and a moon and twinkling stars at night.
// World drives every uniform from Daylight.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.184, 0.561, 0.941);
uniform vec3 horizon_color : source_color = vec3(0.769, 0.914, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.965, 0.847);
uniform vec3 glow_color : source_color = vec3(1.0, 0.55, 0.3);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float glow = 0.0;
uniform float stars = 0.0;
uniform float time = 0.0;
// Storm cover: hides the sun, moon and stars.
uniform float overcast = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
	vec3 dir = EYEDIR;
	float h = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.5));

	// Dawn and dusk: the horizon blushes in the sun's direction, in flat steps.
	vec2 flat_dir = normalize(dir.xz + 1e-5);
	vec2 flat_sun = normalize(sun_dir.xz + 1e-5);
	float toward = max(dot(flat_dir, flat_sun), 0.0);
	float blush = glow * pow(toward, 3.0) * pow(1.0 - h, 6.0);
	col = mix(col, glow_color, blush > 0.45 ? 0.75 : (blush > 0.15 ? 0.4 : blush * 1.5));

	if (stars * (1.0 - overcast) > 0.0 && dir.y > 0.0) {
		vec2 uv = vec2(atan(dir.x, dir.z) * 40.0, asin(dir.y) * 40.0);
		vec2 cell = floor(uv);
		float pick = hash(cell);
		vec2 spot = vec2(hash(cell + 7.1), hash(cell + 3.3)) * 0.6 + 0.2;
		float d = length(fract(uv) - spot);
		float twinkle = 0.6 + 0.4 * sin(time * 2.0 + pick * 60.0);
		if (pick > 0.93 && d < 0.09 + 0.06 * (pick - 0.93) / 0.07) {
			col = mix(col, vec3(1.0, 0.97, 0.88), stars * (1.0 - overcast) * twinkle * smoothstep(0.02, 0.25, dir.y));
		}
	}

	float ds = overcast > 0.6 ? 0.0 : dot(dir, sun_dir);
	if (ds > 0.9993) {
		col = sun_color * 1.4;
	} else if (ds > 0.9972 && ds < 0.9980) {
		col = mix(col, sun_color, 0.45);
	}

	// A pale moon with two darker patches.
	float dm = overcast > 0.6 ? 0.0 : dot(dir, moon_dir);
	if (moon_dir.y > -0.02 && dm > 0.9994) {
		vec3 side = normalize(cross(moon_dir, vec3(0.0, 1.0, 0.0)));
		vec3 up = cross(side, moon_dir);
		vec2 p = vec2(dot(dir, side), dot(dir, up)) / 0.035;
		vec3 moon = vec3(0.93, 0.95, 1.0);
		if (length(p - vec2(0.25, 0.2)) < 0.28 || length(p - vec2(-0.3, -0.25)) < 0.18) {
			moon = vec3(0.78, 0.82, 0.92);
		}
		col = moon;
	} else if (moon_dir.y > -0.02 && dm > 0.9975 && dm < 0.9982) {
		col = mix(col, vec3(0.8, 0.85, 1.0), 0.3 * stars);
	}
	COLOR = col;
}
