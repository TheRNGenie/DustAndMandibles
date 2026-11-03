// Fliers' see-through wings (one MultiMesh for every flier), gliding with the body.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

#include "res://shaders/bug_glide.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.85, 0.95, 1.0, 0.45);

void vertex() {
	VERTEX = bug_glide(VERTEX, INSTANCE_CUSTOM, MODEL_MATRIX);
}

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
}
