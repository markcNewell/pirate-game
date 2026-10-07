// A lighthouse beam: a soft additive cone that fades out toward its far end.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.88, 0.55, 0.22);
uniform float length = 110.0;

varying float along;

void vertex() {
	along = clamp(-VERTEX.z / length, 0.0, 1.0);
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a * pow(1.0 - along, 1.6);
}
