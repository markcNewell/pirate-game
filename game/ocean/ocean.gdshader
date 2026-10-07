// The toon sea. Vertices move with the same formula as game/ocean/waves.gd (the numbers come
// from Waves.shader_params()), then the surface is coloured in three flat blue bands with
// white caps on high crests, broken foam rings round each island and a ring round each hull.
// Inside a hull the surface is cut away, so the lower deck stays dry until it floods.
shader_type spatial;
render_mode unshaded, cull_disabled;

const int WAVES = 4;
const int MAX_ISLANDS = 8;
const int MAX_SHIPS = 4;

uniform vec4 wave_a[WAVES];  // direction x, direction z, wavenumber k, amplitude
uniform vec4 wave_b[WAVES];  // angular speed, phase, unused, unused
uniform float sea_time = 0.0;

uniform vec3 deep_color : source_color = vec3(0.078, 0.384, 0.769);
uniform vec3 mid_color : source_color = vec3(0.137, 0.537, 0.890);
uniform vec3 light_color : source_color = vec3(0.337, 0.741, 0.969);
uniform vec3 foam_color : source_color = vec3(1.0);
uniform vec3 far_color : source_color = vec3(0.137, 0.537, 0.890);

uniform vec4 islands[MAX_ISLANDS];  // x, z, waterline radius, unused
uniform int island_count = 0;
uniform vec4 ships[MAX_SHIPS];  // x, z, heading, unused
uniform vec4 ships_b[MAX_SHIPS];  // sinking progress, unused...
uniform int ship_count = 0;

varying vec3 world_pos;
varying float wave_height;

float sea_height(vec2 p, float t) {
	float h = 0.0;
	for (int i = 0; i < WAVES; i++) {
		h += wave_a[i].w * sin(wave_a[i].z * dot(wave_a[i].xy, p) - wave_b[i].x * t + wave_b[i].y);
	}
	return h;
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
	float caps = noise(world_pos.xz * 0.9 - sea_time * 0.3);
	if (wave_height > 0.7 && caps > 0.62) {
		foam = 1.0;
	}

	for (int i = 0; i < MAX_ISLANDS; i++) {
		if (i >= island_count) {
			break;
		}
		vec2 d = world_pos.xz - islands[i].xy;
		float r = length(d);
		float a = atan(d.y, d.x);
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
		if (sinking < 0.3 && abs(local.y) < 13.0 && abs(local.x) < hull_half_width(local.y, wave_height) - 0.05) {
			discard;
		}
		if (sinking < 0.2) {
			float e = length(vec2(local.x / 4.4, local.y / 13.6));
			foam = max(foam, step(abs(e - 1.0), 0.05 + 0.03 * noise(local * 0.8 + sea_time)));
		}
	}

	col = mix(col, foam_color, foam);
	// Calm the bands far out so the horizon is a clean line, not a stripe of noise.
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	col = mix(col, far_color, smoothstep(250.0, 600.0, dist) * 0.85);
	ALBEDO = col;
}
