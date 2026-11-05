// The outline hull: shared by outline.gdshader and outline_glide.gdshader
// (define BUG_GLIDE and include bug_glide.gdshaderinc first for the batches).

uniform vec4 outline_color : source_color = vec4(0.169, 0.106, 0.090, 1.0);
uniform float thickness : hint_range(0.0, 0.2) = 0.03;
// Bold, chunky silhouettes.
uniform float boldness : hint_range(0.5, 3.0) = 1.35;
uniform float distance_scale : hint_range(0.0, 0.2) = 0.03;
uniform float max_scale : hint_range(1.0, 8.0) = 3.0;
// AI-made models (AiModels): their decimated meshes split normals at every UV
// seam, so the hull tears into black shards. They carry a welded, smoothed
// normal in the vertex colour (rgb * 2 - 1) for the hull to push along.
uniform bool normal_from_color = false;

void vertex() {
#ifdef BUG_GLIDE
	VERTEX = bug_glide(VERTEX, INSTANCE_CUSTOM, MODEL_MATRIX);
#endif
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float scale = clamp(dist * distance_scale, 1.0, max_scale);
	vec3 push = normal_from_color ? COLOR.rgb * 2.0 - 1.0 : NORMAL;
	VERTEX += normalize(push + vec3(1e-5)) * thickness * scale * boldness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
