// Fliers' see-through wings (one MultiMesh for every flier), gliding with the body.
// Drawn veins (long veins along the wing, cross veins between, a dark edge) and
// a dragonfly shimmer: a hue that slides with the viewing angle and time.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

#include "res://shaders/bug_glide.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.85, 0.95, 1.0, 0.45);
uniform vec4 vein_color : source_color = vec4(0.17, 0.11, 0.09, 1.0);
uniform float shimmer : hint_range(0.0, 1.0) = 0.55;

varying vec3 wing_pos;

void vertex() {
	wing_pos = VERTEX; // x runs out along the wing (0 .. 1.4), z across it
	VERTEX = bug_glide(VERTEX, INSTANCE_CUSTOM, MODEL_MATRIX);
}

void fragment() {
	float x = wing_pos.x / 1.4;
	float z = wing_pos.z / 0.16;
	// Long veins fanning out from the root, cross veins between them.
	float lv = abs(fract(z * 2.5 + x * 0.6) - 0.5);
	float cv = abs(fract(x * 9.0 + z * 0.8) - 0.5);
	float vein = max(smoothstep(0.06, 0.0, lv), smoothstep(0.05, 0.0, cv) * 0.6);
	// The dark rim (the wing's edge: the ellipse's outer band).
	float r = length(vec2((x - 0.5) * 2.0, z));
	float rim = smoothstep(0.82, 0.95, r);
	// Shimmer: thin-film colours shifting with angle and time.
	float ang = dot(normalize(NORMAL), normalize(VIEW));
	vec3 film = 0.5 + 0.5 * cos(6.2832 * (vec3(0.0, 0.33, 0.67) + ang * 1.3 + x * 0.6 + TIME * 0.15));
	vec3 col = mix(albedo.rgb, film, shimmer * (0.35 + 0.65 * (1.0 - abs(ang))));
	col = mix(col, vein_color.rgb, max(vein * 0.7, rim));
	ALBEDO = col;
	ALPHA = clamp(albedo.a + max(vein * 0.4, rim * 0.5), 0.0, 1.0);
}
