shader_type canvas_item;
// Light tilt-shift: the middle band stays sharp, the top and bottom of the
// screen get softly blurred, which makes the island look like a miniature.
// The blur is measured as a share of the screen height, so it looks the same
// in a small window, maximized, or fullscreen on a 4K/8K display.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// How much of the screen (from the centre) stays fully sharp, 0..1.
uniform float focus_band : hint_range(0.0, 1.0) = 0.45;
// Blur strength at the very top / bottom edge, as tuned at REFERENCE_HEIGHT.
uniform float max_blur : hint_range(0.0, 5.0) = 1.6;
// Screen height (px) the blur strength was tuned at.
uniform float reference_height = 648.0;

void fragment() {
	float d = abs(SCREEN_UV.y - 0.5) * 2.0; // 0 at centre, 1 at top/bottom
	float t = smoothstep(focus_band, 1.0, d);
	// Each mip level doubles the blur in pixels, so add log2(height ratio)
	// to keep the blur the same share of the screen at any resolution.
	float screen_h = 1.0 / SCREEN_PIXEL_SIZE.y;
	float lod = t * (max_blur + max(0.0, log2(screen_h / reference_height)));
	// Spread the extra taps by about one texel of the chosen mip level.
	vec2 o = SCREEN_PIXEL_SIZE * exp2(lod) * 0.75;
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb * 0.2;
	c += textureLod(screen_tex, SCREEN_UV + vec2(o.x, o.y), lod).rgb * 0.2;
	c += textureLod(screen_tex, SCREEN_UV + vec2(-o.x, o.y), lod).rgb * 0.2;
	c += textureLod(screen_tex, SCREEN_UV + vec2(o.x, -o.y), lod).rgb * 0.2;
	c += textureLod(screen_tex, SCREEN_UV + vec2(-o.x, -o.y), lod).rgb * 0.2;
	COLOR = vec4(c, 1.0);
}
