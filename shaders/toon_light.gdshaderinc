// Shared cel-shading light function (Roboquest-inspired): hard bands with bright,
// cool purple-blue shadows, a crisp fresnel rim, and a small hard specular blob.
// Included by toon.gdshader and cliff_strata.gdshader.

uniform vec4 shadow_tint : source_color = vec4(0.42, 0.33, 0.62, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.7;
uniform float band_softness : hint_range(0.0, 0.2) = 0.025;
uniform float mid_band : hint_range(0.0, 1.0) = 0.55;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.55;
uniform float rim_width : hint_range(0.0, 1.0) = 0.68;
uniform float spec_strength : hint_range(0.0, 1.0) = 0.0; // set per material (Materials.toon)

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	// Band 1: shadow -> mid. Band 2: mid -> full light.
	float b1 = smoothstep(0.03, 0.03 + band_softness, ndl);
	float b2 = smoothstep(0.42, 0.42 + band_softness, ndl);
	float lit = b1 * mid_band + b2 * (1.0 - mid_band);
	vec3 shade = mix(shadow_tint.rgb * shadow_strength, vec3(1.0), lit);
	// Shadow tint only comes from the sun; point lights fall off normally.
	float falloff = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI * falloff;

	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// On upward-facing surfaces (the ground, floors, roofs) the rim depends only
	// on viewing angle, so a hard edge would draw a ring around the camera.
	// Fade it in very gradually there and keep it crisp on everything else.
	vec3 up_view = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float flat_k = smoothstep(0.55, 0.9, dot(NORMAL, up_view));
	float rim_soft = mix(0.03, 0.32, flat_k);
	rim = smoothstep(rim_width, min(rim_width + rim_soft, 1.0), rim) * b1 * mix(1.0, 0.45, flat_k);
	SPECULAR_LIGHT += rim * rim_strength * LIGHT_COLOR / PI * falloff;

	// Hard-edged highlight blob on the lit side.
	float hl = pow(clamp(dot(reflect(-LIGHT, NORMAL), VIEW), 0.0, 1.0), 20.0);
	hl = smoothstep(0.45, 0.5 + 0.4 * flat_k, hl) * b2;
	SPECULAR_LIGHT += hl * spec_strength * LIGHT_COLOR * falloff;
}
