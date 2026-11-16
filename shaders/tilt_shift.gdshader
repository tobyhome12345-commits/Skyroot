shader_type canvas_item;
// Light tilt-shift: the middle band stays sharp, the top and bottom of the
// screen get softly blurred, which makes the island look like a miniature.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// How much of the screen (from the centre) stays fully sharp, 0..1.
uniform float focus_band : hint_range(0.0, 1.0) = 0.45;
// Blur strength at the very top / bottom edge.
uniform float max_blur : hint_range(0.0, 5.0) = 1.6;

void fragment() {
	float d = abs(SCREEN_UV.y - 0.5) * 2.0; // 0 at centre, 1 at top/bottom
	float t = smoothstep(focus_band, 1.0, d);
	float lod = t * max_blur;
	vec2 o = SCREEN_PIXEL_SIZE * (1.0 + lod * 2.0);
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb * 0.2;
	c += textureLod(screen_tex, SCREEN_UV + vec2(o.x, o.y), lod).rgb * 0.2;
	c += textureLod(screen_tex, SCREEN_UV + vec2(-o.x, o.y), lod).rgb * 0.2;
	c += textureLod(screen_tex, SCREEN_UV + vec2(o.x, -o.y), lod).rgb * 0.2;
	c += textureLod(screen_tex, SCREEN_UV + vec2(-o.x, -o.y), lod).rgb * 0.2;
	COLOR = vec4(c, 1.0);
}
