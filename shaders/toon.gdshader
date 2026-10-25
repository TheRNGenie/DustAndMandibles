// Toon ramp shader used by every generated prop, building, bug and weapon.
// Vertex colour drives albedo; vertex alpha < 1 marks glowing weak spots.
shader_type spatial;
render_mode cull_back;

#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = true;
uniform float emission_strength : hint_range(0.0, 8.0) = 2.5;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = albedo.rgb;
	float glow = 0.0;
	if (use_vertex_color) {
		c *= COLOR.rgb;
		glow = 1.0 - COLOR.a;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	EMISSION = c * glow * emission_strength + flash_color.rgb * flash_amount;
}
