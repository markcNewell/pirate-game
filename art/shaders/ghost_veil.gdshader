// Seen as a ghost: the world drained of colour and tinted cold, darkening toward the edges.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float strength = 1.0;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float grey = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 cold = mix(c, vec3(grey * 0.8, grey * 0.95, grey * 1.15), 0.85);
	float edge = smoothstep(0.35, 0.9, length(SCREEN_UV - 0.5) * 1.4);
	cold *= 1.0 - edge * 0.6;
	COLOR = vec4(mix(c, cold, strength), 1.0);
}
