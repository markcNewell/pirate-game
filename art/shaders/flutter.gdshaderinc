// Shared by the cloth shader and its outline pass so the ink moves with the cloth: a wave that
// runs out along +x from the pole (x = 0, held still) and grows toward the free end.
uniform float flutter_amp = 0.2;
uniform float flutter_len = 2.4;

vec3 flutter(vec3 v, float t) {
	float k = clamp(v.x / flutter_len, 0.0, 1.0);
	return vec3(0.0, 0.0, k * flutter_amp * sin(v.x * 2.6 - t * 7.5 + v.y * 0.9));
}
