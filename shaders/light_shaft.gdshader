shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
// A soft slanting ray of light (a long quad): brightest along its middle,
// fading out at both sides and both ends. UV.x across, UV.y along.

uniform vec3 colour : source_color = vec3(1.0, 0.97, 0.86);
uniform float strength = 0.12;

void fragment() {
	float across = sin(UV.x * 3.14159);
	float along = smoothstep(0.0, 0.35, UV.y) * smoothstep(1.0, 0.55, UV.y);
	ALBEDO = colour;
	ALPHA = across * across * along * strength;
}
