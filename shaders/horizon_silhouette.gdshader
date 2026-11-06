// Far landforms on the horizon (BadlandsTerrain.horizon_silhouettes), well past
// the camera's far plane: each vertex is pulled toward the camera along its line
// of sight (same spot on screen) and drawn at the very back of the depth range,
// so everything else covers it and the far plane never clips it. Faint: the
// colour leans toward the horizon haze; the fog is left off. Lit as flat ground
// (a silhouette, no shading across it) by the sun alone, so it dims at dusk.
shader_type spatial;
render_mode cull_disabled, fog_disabled, specular_disabled, ambient_light_disabled;

uniform vec4 color : source_color = vec4(0.788, 0.541, 0.369, 1.0); // #C98A5E
uniform vec4 haze : source_color = vec4(0.969, 0.851, 0.627, 1.0);  // Palette.SKY_HORIZON
uniform float faint : hint_range(0.0, 1.0) = 0.5;
uniform float pull = 0.15;
// Hazier toward the foot (from base_y up over fade metres), so where nearer
// ground covers the foot the cut doesn't show.
uniform float base_y = 70.0;
uniform float fade = 120.0;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vp.xyz *= pull;
	POSITION = PROJECTION_MATRIX * vp;
	POSITION.z = POSITION.w * 0.000001;
}

void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float foot = 1.0 - smoothstep(base_y, base_y + fade, world_y);
	ALBEDO = mix(color.rgb, haze.rgb, mix(faint, 0.9, foot));
	ROUGHNESS = 1.0;
}
