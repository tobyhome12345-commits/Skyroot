shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
// A soft ribbon of wind: white at its middle, pale blue at its soft edges,
// with faint bands of air flowing along it (round and round, going nowhere).
// UV.x runs along the ribbon (in metres), UV.y across it (0..1).
// COLOR.a fades the ribbon's ends (set per vertex).

uniform vec3 core_colour : source_color = vec3(0.97, 0.99, 1.0);
uniform vec3 edge_colour : source_color = vec3(0.72, 0.86, 1.0);
uniform float opacity = 0.75;
uniform float flow_speed = 0.6;
uniform float band_length = 1.4;

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;            // 0 middle, 1 edge
	float soft = 1.0 - smoothstep(0.35, 1.0, across);
	float bands = 0.65 + 0.35 * sin((UV.x / band_length - TIME * flow_speed) * 6.2832);
	ALBEDO = mix(core_colour, edge_colour, across);
	ALPHA = clamp(soft * bands * COLOR.a * opacity, 0.0, 1.0);
}
