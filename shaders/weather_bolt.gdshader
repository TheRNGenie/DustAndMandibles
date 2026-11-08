// A lightning bolt (WeatherFx._draw_bolt): ribbons turned to the camera, a
// white-hot core inside a blue glow across each ribbon (UV.x), bright enough to
// bloom. UV.y is how far down the channel a point is: `reveal` draws the
// stepped leader racing down before the return stroke lights the whole path.
// Vertex alpha weights a branch (forks dimmer than the main channel).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float energy = 1.0;
uniform float reveal = 1.0;
uniform vec3 core_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 glow_color : source_color = vec3(0.5, 0.64, 1.0);

void fragment() {
	if (UV.y > reveal) {
		discard;
	}
	float u = abs(UV.x * 2.0 - 1.0);
	float core = 1.0 - smoothstep(0.05, 0.2, u);
	float glow = pow(max(1.0 - u, 0.0), 3.0);
	// The tip of the leader burns brightest as it steps down.
	float tip = reveal < 1.0 ? smoothstep(reveal - 0.06, reveal, UV.y) * 2.0 : 0.0;
	ALBEDO = (core_color * core * (4.0 + tip * 3.0) + glow_color * glow * 0.8) * energy * COLOR.a;
}
