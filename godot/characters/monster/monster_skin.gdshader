shader_type canvas_item;
// Per-instance colour for the monster (character-rig D6): rotates the hue of saturated
// pixels only, so the greens shift together while white (eye, fangs), black
// (pupil) and greys keep their colour. Only skin-green hues are shifted, so the
// props (wood, laptop glow; work-and-wait D3) keep their own colours.

uniform float hue_shift = 0.0; // degrees
uniform float saturation_threshold = 0.15;
uniform float skin_hue = 100.0; // degrees, centre of the drawn greens
uniform float skin_hue_range = 45.0; // degrees each side that are fully shifted

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	// In Godot 4 the incoming COLOR already is texture colour x modulate.
	vec3 hsv = rgb2hsv(COLOR.rgb);
	float weight = smoothstep(saturation_threshold - 0.05, saturation_threshold + 0.05, hsv.y);
	float dist = abs(fract(hsv.x - skin_hue / 360.0 + 0.5) - 0.5) * 360.0;
	weight *= 1.0 - smoothstep(skin_hue_range, skin_hue_range + 15.0, dist);
	hsv.x = fract(hsv.x + hue_shift / 360.0);
	COLOR.rgb = mix(COLOR.rgb, hsv2rgb(hsv), weight);
}
