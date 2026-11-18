shader_type spatial;
render_mode cull_disabled;
// Leafwind's floors, drawn in world space so the pattern runs on across
// tiles. The vertex colour is the base tint (Leafwind's palette, set in code).
//   kind 0: wooden planks (boards along x, or along z when board_axis = 1),
//           with seams, staggered end joints and soft grain
//   kind 1: woven leaf mat (basket weave of leaf strips)
//   kind 2: moss (soft blotches)
//   kind 3: bark (long ridges and grooves)

uniform int kind = 0;
uniform int board_axis = 0;
uniform float board_width = 0.4;
uniform float board_length = 2.6;
// Extra tint, for meshes without vertex colours (interior floor boards).
uniform vec3 tint : source_color = vec3(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

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

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	vec3 base = srgb_to_linear(COLOR.rgb) * tint;
	vec2 p = board_axis == 0 ? world_pos.xz : world_pos.zx;  // x = along, y = across
	float shade = 1.0;
	if (kind == 0) {
		float row = floor(p.y / board_width);
		float across = fract(p.y / board_width);
		float offset = hash(row) * board_length;
		float piece = floor((p.x + offset) / board_length);
		float along = fract((p.x + offset) / board_length);
		float seam = smoothstep(0.0, 0.07, across) * smoothstep(1.0, 0.93, across)
				* smoothstep(0.0, 0.015, along) * smoothstep(1.0, 0.985, along);
		float tone = 0.86 + 0.2 * hash(row * 7.0 + piece * 13.0);
		float grain = 0.95 + 0.05 * sin(p.x * 6.0 + noise(vec2(p.x * 0.8, row * 3.0)) * 6.0 + across * 3.0);
		shade = tone * grain * mix(0.5, 1.0, seam);
	} else if (kind == 1) {
		vec2 q = world_pos.xz / 0.5;
		vec2 cell = floor(q);
		vec2 f = fract(q);
		bool flip = mod(cell.x + cell.y, 2.0) > 0.5;
		float t = flip ? f.x : f.y;
		float strip = fract(t * 3.0);
		float edge = smoothstep(0.0, 0.18, strip) * smoothstep(1.0, 0.82, strip);
		float lift = flip ? 0.94 : 1.06;
		shade = lift * mix(0.7, 1.0, edge) * (0.92 + 0.12 * hash2(cell));
	} else if (kind == 2) {
		float n = noise(world_pos.xz * 1.7) * 0.6 + noise(world_pos.xz * 5.0) * 0.4;
		shade = 0.82 + 0.32 * n;
	} else {
		float wobble = noise(vec2(p.x * 0.6, p.y * 2.0)) * 2.0;
		float ridge = sin(p.y * 9.0 + wobble);
		shade = 0.72 + 0.28 * smoothstep(-0.4, 0.7, ridge) + 0.06 * noise(p * 4.0);
	}
	ALBEDO = base * shade;
	ROUGHNESS = kind == 2 ? 1.0 : 0.9;
}
