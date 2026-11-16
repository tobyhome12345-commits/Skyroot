shader_type spatial;
render_mode cull_disabled;
// Island ground: keeps the per-tile colours (vertex colours) and adds a real
// stone texture from the Kenney Modular Cave pack, projected in world space
// so it tiles seamlessly across every tile. Grass gets a light touch, the
// rocky underside a strong one.

uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
// How many times the texture repeats per metre.
uniform float detail_scale = 0.5;
uniform float grass_strength = 0.8;
uniform float rock_strength = 0.9;
// Average brightness of the texture, so it darkens and lightens around 1.0.
uniform float detail_mid = 0.38;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv;
	if (n.y >= n.x && n.y >= n.z) {
		uv = world_pos.xz;
	} else if (n.x >= n.z) {
		uv = world_pos.zy;
	} else {
		uv = world_pos.xy;
	}
	float d = dot(texture(detail_tex, uv * detail_scale).rgb, vec3(0.3333)) / detail_mid;
	// Grass top (facing up, at ground level) vs dirt band and rock below.
	bool grass = world_normal.y > 0.5 && world_pos.y > -0.3;
	float strength = grass ? grass_strength : rock_strength;
	vec3 base = srgb_to_linear(COLOR.rgb);
	ALBEDO = base * mix(1.0, d, strength);
	ROUGHNESS = 0.95;
}
