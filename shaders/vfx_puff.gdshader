// Billboarded cartoon puff for dust, smoke and dust devils: a lumpy round blob
// with a hard toon edge and a lit top / shaded bottom. Particle COLOR tints and fades.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.91, 0.78, 0.6, 1.0);
uniform vec4 shade : source_color = vec4(0.62, 0.47, 0.52, 1.0);
uniform float lumps = 5.0;
uniform float softness : hint_range(0.0, 0.5) = 0.08;
// Optional painted puff (assets/fx/dust.png): its shape and shading, in our tints.
uniform sampler2D puff_tex : filter_linear_mipmap;
uniform bool use_tex = false;

varying float v_seed;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	// Each particle gets its own lump pattern.
	v_seed = fract(float(INSTANCE_ID) * 0.61803);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float seed = v_seed;
	float edge = 0.82 + 0.1 * sin(a * lumps + seed * 6.28) + 0.05 * sin(a * (lumps + 3.0) - seed * 9.0);
	float mask = 1.0 - smoothstep(edge - softness, edge, r);
	// Lit from above: lighter top, shadowed underside, in two hard bands.
	float lit = step(0.05, -p.y + 0.25 * (1.0 - r));
	vec3 col = mix(shade.rgb, tint.rgb, lit) * COLOR.rgb;
	if (use_tex) {
		// Each particle turned its own way, so no two puffs match.
		float ang = seed * 6.2832;
		vec2 q = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * (UV - 0.5) + 0.5;
		vec4 t = texture(puff_tex, q);
		float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
		col = mix(shade.rgb, tint.rgb, smoothstep(0.55, 0.8, l)) * COLOR.rgb;
		mask = t.a;
	}
	ALBEDO = col;
	ALPHA = mask * COLOR.a;
}
