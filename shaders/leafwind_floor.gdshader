shader_type spatial;
render_mode cull_disabled;
// Leafwind's floors, drawn in world space so the pattern runs on across
// tiles. The vertex colour is the base tint (set in code).
//   kind 0: warm wooden planks: long boards with soft seams, staggered joints,
//           a few worn (paler) boards, fine grain; UV.x picks the board
//           direction per tile (0 = along x, 1 = along z); COLOR.a is how
//           close the edge of a deck is, where moss creeps in
//   kind 2: moss (soft blotches)
//   kind 4: a round wooden plaza: rings of curved boards round
//           plaza_centre, out to plaza_radius, plain planks beyond
// All kinds: a few fallen leaves, and soft dappled sunlight (brighter
// patches, as if light falls through the canopy).

uniform int kind = 0;
uniform float board_width = 0.42;
uniform float board_length = 3.4;
// Extra tint, for meshes without vertex colours (interior floor boards).
uniform vec3 tint : source_color = vec3(1.0);
uniform vec2 plaza_centre = vec2(0.0);
uniform float plaza_radius = 3.4;
uniform bool leaves = true;
uniform bool dapple = true;
// Rooms: boards one way (0 / 1) and no moss (their meshes carry no data).
uniform int force_axis = -1;
uniform bool edge_moss = true;

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

// Planks along p.x (p.y across). Returns shade and sets `worn`.
float planks(vec2 p, out float worn) {
	float row = floor(p.y / board_width);
	float across = fract(p.y / board_width);
	float offset = hash(row) * board_length;
	float piece = floor((p.x + offset) / board_length);
	float along = fract((p.x + offset) / board_length);
	float seam = smoothstep(0.0, 0.05, across) * smoothstep(1.0, 0.95, across)
			* smoothstep(0.0, 0.01, along) * smoothstep(1.0, 0.99, along);
	float id = hash(row * 7.0 + piece * 13.0);
	worn = step(0.88, id);
	float tone = 0.92 + 0.14 * id;
	float grain = 0.97 + 0.03 * sin(p.x * 5.0 + noise(vec2(p.x * 0.7, row * 3.0)) * 5.0 + across * 2.0);
	return tone * grain * mix(0.78, 1.0, seam);
}

void fragment() {
	vec3 base = srgb_to_linear(COLOR.rgb) * tint;
	vec3 col = base;
	float worn = 0.0;
	if (kind == 2) {
		float n = noise(world_pos.xz * 1.7) * 0.6 + noise(world_pos.xz * 5.0) * 0.4;
		col = base * (0.86 + 0.28 * n);
	} else {
		float axis = force_axis >= 0 ? float(force_axis) : UV.x;
		vec2 p = axis < 0.5 ? world_pos.xz : world_pos.zx;
		float shade;
		vec2 rel = world_pos.xz - plaza_centre;
		float r = length(rel);
		if (kind == 4 && r < plaza_radius) {
			// Curved boards in rings, joints spaced along each ring.
			float ring = floor(r / 0.45);
			float across = fract(r / 0.45);
			float segs = max(4.0, floor(6.2832 * (ring + 0.5) * 0.45 / 1.5));
			float a = (atan(rel.y, rel.x) / 6.2832 + 0.5) * segs + hash(ring) * 3.0;
			float along = fract(a);
			float seam = smoothstep(0.0, 0.06, across) * smoothstep(1.0, 0.94, across)
					* smoothstep(0.0, 0.03, along) * smoothstep(1.0, 0.97, along);
			float id = hash(ring * 5.0 + floor(a) * 11.0);
			shade = (0.93 + 0.12 * id) * mix(0.78, 1.0, seam);
			// A darker rim board round the edge, and a lighter disc in the middle.
			shade *= r > plaza_radius - 0.3 ? 0.82 : 1.0;
			shade *= r < 0.5 ? 1.08 : 1.0;
		} else {
			shade = planks(p, worn);
		}
		col = base * shade;
		// Worn boards are paler and a touch greyer.
		col = mix(col, col * vec3(1.08, 1.04, 0.98) + vec3(0.03), worn * 0.6);
		// Moss creeping in from the deck's open edges.
		float moss = edge_moss ? smoothstep(0.35, 0.75, COLOR.a + (noise(world_pos.xz * 2.2) - 0.5) * 0.6) : 0.0;
		col = mix(col, srgb_to_linear(vec3(0.5, 0.64, 0.36)) * (0.85 + 0.3 * noise(world_pos.xz * 6.0)), moss * 0.85);
	}
	// A few fallen leaves.
	if (leaves) {
		vec2 cell = floor(world_pos.xz / 0.9);
		float h = hash2(cell);
		if (h > 0.9) {
			vec2 c = (cell + 0.25 + 0.5 * vec2(hash2(cell + 3.1), hash2(cell + 7.7))) * 0.9;
			float ang = hash2(cell + 1.3) * 6.2832;
			vec2 d = world_pos.xz - c;
			d = vec2(cos(ang) * d.x - sin(ang) * d.y, sin(ang) * d.x + cos(ang) * d.y);
			float leaf = 1.0 - smoothstep(0.85, 1.0, length(d / vec2(0.16, 0.07)));
			vec3 leaf_col = h > 0.96 ? vec3(0.86, 0.66, 0.3) : vec3(0.5, 0.66, 0.34);
			col = mix(col, srgb_to_linear(leaf_col), leaf * 0.9);
		}
	}
	// Dappled sunlight through the canopy.
	if (dapple) {
		float dp = noise(world_pos.xz * 0.22 + vec2(3.0, 7.0)) * 0.65 + noise(world_pos.xz * 0.6) * 0.35;
		col *= 0.93 + 0.2 * smoothstep(0.45, 0.72, dp);
	}
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
