// Ink outline, drawn as a second pass: the model again, pushed out along its normals and
// turned inside out, so only the rim shows around the real surface. The push grows with
// distance so lines stay about the same thickness on screen.
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 ink : source_color = vec4(0.106, 0.102, 0.141, 1.0);
uniform float width = 0.0022;
uniform float min_width = 0.012;
// Where the outline normals are: 0 CUSTOM0 (smoothed copies, on MeshBuilder meshes and static
// Blender models), 1 TANGENT, 2 NORMAL (animated models, see Models).
uniform int normal_source = 0;

void vertex() {
	// CUSTOM0's length is the outline's weight there (short on small details; see Models).
	vec3 n = normal_source == 0 ? CUSTOM0.xyz : (normal_source == 1 ? TANGENT : NORMAL * length(CUSTOM0.xyz));
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(CAMERA_POSITION_WORLD - world);
	VERTEX += n * max(min_width, dist * width);
}

void fragment() {
	ALBEDO = ink.rgb;
}
