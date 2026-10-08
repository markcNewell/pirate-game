// The ink outline for fluttering cloth: outline.gdshader moved by the same flutter.
// Ink outline, drawn as a second pass: the model again, pushed out along its normals and
// turned inside out, so only the rim shows around the real surface. The push grows with
// distance so lines stay about the same thickness on screen.
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 ink : source_color = vec4(0.106, 0.102, 0.141, 1.0);
uniform float width = 0.0022;
uniform float min_width = 0.012;
// Meshes from MeshBuilder carry smoothed normals in CUSTOM0 so hard corners stay closed.
uniform bool use_custom_normals = true;

#include "res://art/shaders/flutter.gdshaderinc"

void vertex() {
	vec3 n = use_custom_normals ? CUSTOM0.xyz : NORMAL;
	VERTEX += flutter(VERTEX, TIME);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(CAMERA_POSITION_WORLD - world);
	float scale = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	VERTEX += normalize(n) * max(min_width, dist * width) / scale;
}

void fragment() {
	ALBEDO = ink.rgb;
}
