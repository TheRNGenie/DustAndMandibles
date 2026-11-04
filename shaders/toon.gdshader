// Toon ramp shader used by every generated prop, building, bug and weapon.
// Vertex colour drives albedo; vertex alpha < 1 marks glowing weak spots.
shader_type spatial;
render_mode cull_back;

#include "res://shaders/toon_surface.gdshaderinc"

void vertex() {
	paint_pos = VERTEX;
	paint_nrm = NORMAL;
}
