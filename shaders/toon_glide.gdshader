// toon.gdshader for the bug MultiMesh batches (LegBatch): every piece is drawn
// back along its bug's motion so bugs that update a few times a second still
// move smoothly at render frame rate (see bug_glide.gdshaderinc).
shader_type spatial;
render_mode cull_back;

#include "res://shaders/toon_surface.gdshaderinc"
#include "res://shaders/bug_glide.gdshaderinc"

void vertex() {
	VERTEX = bug_glide(VERTEX, INSTANCE_CUSTOM, MODEL_MATRIX);
}
