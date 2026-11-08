// A sheet of weather in the middle distance (WeatherFx: grey curtains of rain,
// walls of blowing dust): a tall upright card turned to the camera round the
// world's up axis, its tiling texture scrolling (`scroll`: down for rain,
// along the wind for dust), each card starting at its own place in the
// texture (the particle's anim offset), the card's edges soft.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 scroll = vec2(0.0);
uniform vec2 tiling = vec2(1.0);
uniform float light = 1.0;
uniform float near_fade = 40.0;

varying float v_fade;
varying float v_seed;

void vertex() {
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 back = normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0)));
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * sc.x, 0.0), vec4(0.0, sc.y, 0.0, 0.0), vec4(back * sc.z, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_fade = smoothstep(near_fade * 0.5, near_fade, length(CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz));
	v_seed = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec2 uv = UV * tiling + vec2(v_seed * 7.31, v_seed * 3.17) + scroll;
	vec4 t = texture(tex, uv);
	float edge = smoothstep(0.0, 0.28, UV.x) * (1.0 - smoothstep(0.72, 1.0, UV.x)) * smoothstep(0.0, 0.3, UV.y) * (1.0 - smoothstep(0.86, 1.0, UV.y));
	ALBEDO = tint.rgb * COLOR.rgb * t.rgb * light;
	ALPHA = clamp(tint.a * COLOR.a * t.a * edge * v_fade, 0.0, 1.0);
}
