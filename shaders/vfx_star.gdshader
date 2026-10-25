// Billboarded comic "star burst" quad for hit sparks and muzzle flashes.
// Particle colour (COLOR) controls tint and fade.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.824, 0.247, 1.0);
uniform float spikes = 4.0;
uniform float sharpness = 6.0;
uniform float core = 0.3;
uniform float brightness = 2.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float star = pow(abs(cos(a * spikes * 0.5)), sharpness);
	float edge = mix(core, 1.0, star);
	float mask = 1.0 - smoothstep(edge - 0.06, edge, r);
	float hot = 1.0 - smoothstep(0.0, core, r);
	ALBEDO = mix(tint.rgb * COLOR.rgb, vec3(1.0), hot * 0.8) * brightness;
	ALPHA = mask * COLOR.a;
}
