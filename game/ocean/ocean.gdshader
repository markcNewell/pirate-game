// The toon sea. Vertices move with the same formula as game/ocean/waves.gd (the numbers come
// from Waves.shader_params()), then the surface is coloured in three flat blue bands with
// white caps on high crests, broken foam rings round each island and a ring round each hull.
// Inside a hull the surface is cut away, so the lower deck stays dry until it floods.
shader_type spatial;
render_mode unshaded, cull_disabled;

const int WAVES = 4;
const int MAX_ISLANDS = 12;
const int MAX_SHIPS = 8;

uniform vec4 wave_a[WAVES];  // direction x, direction z, wavenumber k, amplitude
uniform vec4 wave_b[WAVES];  // angular speed, phase, unused, unused
uniform float sea_time = 0.0;
// The storm scales the waves up toward its heart, exactly as Storm.wave_factor does.
uniform vec2 storm_centre = vec2(1e6, 1e6);
uniform float storm_radius = 150.0;
uniform float storm_gain = 1.6;
uniform float storm_on = 0.0;
// The Black Reef's storm, which never moves (Reef.amount).
uniform vec2 reef_centre = vec2(1e6, 1e6);
uniform float reef_radius = 150.0;

uniform vec3 deep_color : source_color = vec3(0.078, 0.384, 0.769);
uniform vec3 mid_color : source_color = vec3(0.137, 0.537, 0.890);
uniform vec3 light_color : source_color = vec3(0.337, 0.741, 0.969);
uniform vec3 foam_color : source_color = vec3(1.0);
uniform vec3 far_color : source_color = vec3(0.137, 0.537, 0.890);
uniform vec3 shallow_color : source_color = vec3(0.30, 0.82, 0.86);
uniform vec3 beach_color : source_color = vec3(0.62, 0.93, 0.90);
uniform vec3 daylight : source_color = vec3(1.0);  // the time of day's tint over everything
uniform float sun_glints = 1.0;
// A glittering path on the water toward a low sun or the moon.
uniform vec3 path_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 path_color : source_color = vec3(1.0, 0.85, 0.6);
uniform float path_strength = 0.0;

uniform vec4 islands[MAX_ISLANDS];  // x, z, waterline radius, unused
uniform int island_count = 0;
uniform vec4 ships[MAX_SHIPS];  // x, z, heading, unused
uniform vec4 ships_b[MAX_SHIPS];  // sinking progress, water inside, speed (m/s), unused
uniform int ship_count = 0;

varying vec3 world_pos;
varying float wave_height;

float sea_height(vec2 p, float t) {
	float h = 0.0;
	for (int i = 0; i < WAVES; i++) {
		h += wave_a[i].w * sin(wave_a[i].z * dot(wave_a[i].xy, p) - wave_b[i].x * t + wave_b[i].y);
	}
	float strength = storm_on * max(1.0 - smoothstep(0.7, 1.5, length(p - storm_centre) / storm_radius),
		1.0 - smoothstep(0.7, 1.5, length(p - reef_centre) / reef_radius));
	return h * (1.0 + storm_gain * strength);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// Same shape as ShipShape.half_width.
float hull_half_width(float z, float y) {
	float t = z / 13.0;
	float plan = 1.0 - 0.92 * pow(max(0.0, -t), 2.0) - 0.25 * pow(max(0.0, t), 4.0);
	float v = clamp((y + 2.2) / 5.2, 0.0, 1.0);
	return 3.75 * plan * (0.35 + 0.65 * pow(v, 0.6));
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = sea_height(wp.xz, sea_time);
	VERTEX.y += h;
	world_pos = vec3(wp.x, h, wp.z);
	wave_height = h;
}

void fragment() {
	float n = noise(world_pos.xz * 0.15 + sea_time * 0.05);
	float h = wave_height + (n - 0.5) * 0.25;
	vec3 col = h > 0.28 ? light_color : (h > -0.2 ? mid_color : deep_color);

	float foam = 0.0;
	// White caps: only the highest crests, broken up by noise.
	float caps = noise(world_pos.xz * 1.1 - sea_time * 0.3);
	if (wave_height > 0.74 && caps > 0.66) {
		foam = 1.0;
	}

	for (int i = 0; i < MAX_ISLANDS; i++) {
		if (i >= island_count) {
			break;
		}
		vec2 d = world_pos.xz - islands[i].xy;
		float r = length(d);
		float a = atan(d.y, d.x);
		// Bright shallows shelving away from the beach, in two flat toon steps.
		float shore = r - islands[i].z * (1.0 + 0.04 * sin(a * 5.0));
		if (shore < 6.0) {
			col = beach_color;
		} else if (shore < 16.0 + 3.0 * sin(a * 3.0 + 1.0)) {
			col = shallow_color;
		}
		if (shore < 16.0) {
			// Caustics: a net of bright wavy lines rippling over the sandy bottom.
			vec2 q = world_pos.xz * 0.35;
			float w1 = noise(q + vec2(sea_time * 0.25, sea_time * 0.1));
			float w2 = noise(q * 1.7 - vec2(sea_time * 0.15, -sea_time * 0.2) + 5.0);
			float net = abs(w1 - w2);
			float seen = 1.0 - smoothstep(50.0, 110.0, length(world_pos - CAMERA_POSITION_WORLD));
			col = mix(col, vec3(1.0), step(net, 0.035) * 0.55 * seen * (1.0 - smoothstep(10.0, 16.0, shore)));
		}
		float edge = islands[i].z * (1.0 + 0.04 * sin(a * 5.0)) + 0.8 * sin(sea_time * 0.9 + a * 3.0);
		float ring1 = step(abs(r - edge - 0.6), 0.9);
		float ring2 = step(abs(r - edge - 4.0 - 1.2 * sin(sea_time * 0.7 + a * 4.0)), 0.35);
		float broken = step(0.35, noise(vec2(a * 12.0, r * 0.4 - sea_time * 0.4)));
		foam = max(foam, max(ring1, ring2 * broken));
	}

	for (int i = 0; i < MAX_SHIPS; i++) {
		if (i >= ship_count) {
			break;
		}
		// Into the ship's frame: x across the beam, z along the keel (bow at -z).
		vec2 d = world_pos.xz - ships[i].xy;
		if (dot(d, d) > 900.0) {
			continue;
		}
		float c = cos(ships[i].z);
		float s = sin(ships[i].z);
		vec2 local = vec2(c * d.x - s * d.y, s * d.x + c * d.y);
		float sinking = ships_b[i].x;
		float speed = ships_b[i].z;
		if (sinking < 0.3 && abs(local.y) < 13.0 && abs(local.x) < hull_half_width(local.y, wave_height) - 0.05) {
			discard;
		}
		if (sinking < 0.2) {
			float e = length(vec2(local.x / 4.4, local.y / 13.6));
			foam = max(foam, step(abs(e - 1.0), 0.05 + 0.03 * noise(local * 0.8 + sea_time)));
			if (speed > 0.5) {
				// A V of foam spreading behind the stern, broken up and fading with distance,
				// and a churned trail straight behind.
				float behind = local.y - 12.0;
				float len = 25.0 + speed * 9.0;
				if (behind > 0.0 && behind < len) {
					float fade = 1.0 - behind / len;
					float arm = abs(abs(local.x) - (2.2 + behind * 0.3));
					float broken = noise(vec2(behind * 0.5 - sea_time * speed * 0.4, local.x * 0.7));
					foam = max(foam, step(arm, 0.25 + behind * 0.012) * step(0.3, broken * fade + 0.1));
					float churn = noise(local * 0.9 + vec2(0.0, -sea_time * speed * 0.6));
					foam = max(foam, step(abs(local.x), 1.2 + behind * 0.04) * step(1.15 - fade * 0.5, churn + 0.45));
				}
				// Bow wave curling off both sides of the bow.
				if (local.y > -14.0 && local.y < -6.0) {
					float hw = hull_half_width(local.y, wave_height);
					float curl = abs(abs(local.x) - hw - 0.3 - (local.y + 14.0) * 0.08);
					foam = max(foam, step(curl, 0.18 * min(speed, 6.0) / 6.0 + 0.05));
				}
			}
		}
	}

	// Faint ripple lines on the water close by, so it never reads as a flat sheet.
	float close = 1.0 - smoothstep(12.0, 40.0, length(world_pos - CAMERA_POSITION_WORLD));
	if (close > 0.0 && foam < 0.5) {
		vec2 q = world_pos.xz * 0.5;
		float r1 = noise(q + vec2(sea_time * 0.3, -sea_time * 0.12));
		float r2 = noise(q * 1.4 - vec2(sea_time * 0.18, sea_time * 0.25) + 9.0);
		col = mix(col, light_color, step(abs(r1 - r2), 0.03) * 0.45 * close);
	}

	// A few glints of sun on the near sea.
	float near = length(world_pos - CAMERA_POSITION_WORLD);
	if (near < 120.0) {
		vec2 cell = floor(world_pos.xz * 1.2);
		float glint = hash(cell);
		float twinkle = sin(sea_time * 4.0 + glint * 40.0);
		if (glint > 1.0 - 0.008 * sun_glints && twinkle > 0.7 && wave_height > 0.05) {
			foam = 1.0;
		}
	}
	// Shadows of clouds drifting across the open sea, in one flat toon step.
	float cloud = noise(world_pos.xz * 0.006 + vec2(sea_time * 0.004, sea_time * 0.0025));
	col *= cloud > 0.62 ? 0.91 : 1.0;
	col = mix(col, foam_color, foam) * daylight;
	if (path_strength > 0.0) {
		vec2 to = world_pos.xz - CAMERA_POSITION_WORLD.xz;
		float along = dot(normalize(to), normalize(path_dir.xz + 1e-5));
		float sparkle = hash(floor(world_pos.xz * 0.8));
		float twinkle = sin(sea_time * 3.0 + sparkle * 50.0);
		if (along > 0.992 - 0.004 * sparkle && sparkle > 0.55 && twinkle > 0.2 && length(to) > 12.0) {
			col = mix(col, path_color, path_strength);
		}
	}
	// Calm the bands far out so the horizon is a clean line, not a stripe of noise.
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	col = mix(col, far_color, smoothstep(250.0, 600.0, dist) * 0.85);
	ALBEDO = col;
}
