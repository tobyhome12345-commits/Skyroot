shader_type spatial;
render_mode cull_disabled;
// Bark for branches, trunks, logs and stilts: long ridges running along the
// piece (UV.x = metres along it, UV.y = 0..1 around it), tinted by the
// vertex colour.

uniform float ridges = 7.0;

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
	vec3 base = srgb_to_linear(COLOR.rgb);
	float wobble = noise(vec2(UV.x * 0.9, UV.y * ridges)) * 2.2;
	float ridge = sin(UV.y * ridges * 6.2832 + wobble);
	float shade = 0.74 + 0.26 * smoothstep(-0.5, 0.75, ridge);
	shade *= 0.94 + 0.08 * noise(vec2(UV.x * 3.0, UV.y * 20.0));
	ALBEDO = base * shade;
	ROUGHNESS = 0.95;
}
