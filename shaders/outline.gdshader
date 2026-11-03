// Inverted-hull outline, used as next_pass on toon materials.
// Pushes vertices out along normals and draws only back faces in flat dark brown.
// Width grows a little with distance so silhouettes stay readable across the canyon.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

#include "res://shaders/outline_surface.gdshaderinc"
