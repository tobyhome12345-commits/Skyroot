shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
// A soft wisp of pale mist on a quad that always faces the camera. Its edge
// is broken up with slow-drifting noise so it reads as haze, not a disc.

uniform vec3 colour : source_color = vec3(0.92, 0.95, 0.98);
uniform float opacity = 0.32;
uniform float seed = 0.0;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
			mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// Face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c * vec2(1.0, 1.6)) * 2.0;
	float n = noise(UV * 4.0 + vec2(seed, TIME * 0.02)) * 0.5 + noise(UV * 9.0 - vec2(TIME * 0.015, seed)) * 0.25;
	float a = smoothstep(1.0, 0.15, r + (n - 0.35) * 0.6);
	ALBEDO = colour;
	ALPHA = a * opacity;
}
