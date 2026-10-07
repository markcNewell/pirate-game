// The storm's curtain of rain seen from outside (and its wall from inside): a see-through grey
// tube with streaks falling down it, fading out at the top and where it meets the sea.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.55, 0.6, 0.66, 0.4);
uniform float height = 80.0;
uniform float strength = 1.0;

varying vec3 local;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	float a = atan(local.z, local.x);
	float lane = floor(a * 90.0);
	float fall = local.y * 0.12 + TIME * 3.0 + hash(vec2(lane, 3.0)) * 20.0;
	float streak = step(0.55, hash(vec2(lane, floor(fall))));
	float y = local.y + height * 0.5;
	float fade = smoothstep(0.0, 6.0, y) * (1.0 - smoothstep(height * 0.6, height, y));
	ALBEDO = color.rgb;
	ALPHA = color.a * strength * fade * (0.55 + 0.45 * streak);
}
