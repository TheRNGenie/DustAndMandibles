// Inverted-hull outline, used as next_pass on toon materials.
// Pushes vertices out along normals and draws only back faces in flat dark brown.
// Width grows a little with distance so silhouettes stay readable across the canyon.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.169, 0.106, 0.090, 1.0);
uniform float thickness : hint_range(0.0, 0.2) = 0.03;
uniform float distance_scale : hint_range(0.0, 0.2) = 0.03;
uniform float max_scale : hint_range(1.0, 8.0) = 3.0;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float scale = clamp(dist * distance_scale, 1.0, max_scale);
	VERTEX += normalize(NORMAL) * thickness * scale;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
