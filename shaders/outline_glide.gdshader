// outline.gdshader for the bug MultiMesh batches: the hull glides with the body.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

#define BUG_GLIDE
#include "res://shaders/bug_glide.gdshaderinc"
#include "res://shaders/outline_surface.gdshaderinc"
