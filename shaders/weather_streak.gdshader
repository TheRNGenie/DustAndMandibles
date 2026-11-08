// A weather streak (WeatherFx: rain, blowing sand, grit): a particle quad
// stretched along its velocity (particle_flag_align_y puts the velocity on the
// particle's Y axis) and turned round that axis to face the camera, so rain
// slants with the wind and sand streams sideways. Streaks fade out as they pass
// close to the eye (no pillars across the view), and take the day's light
// (`light`, dimmer at night, bright in a lightning flash).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float near_fade = 1.5;
uniform float light = 1.0;

varying float v_fade;

void vertex() {
	vec3 pos = MODEL_MATRIX[3].xyz;
	vec3 axis = MODEL_MATRIX[1].xyz;
	float len = max(length(axis), 1e-5);
	vec3 y = axis / len;
	vec3 to_cam = CAMERA_POSITION_WORLD - pos;
	float d = length(to_cam);
	vec3 x = cross(y, to_cam / max(d, 1e-4));
	float xl = length(x);
	x = xl > 1e-3 ? x / xl : normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 z = cross(x, y);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(x * length(MODEL_MATRIX[0].xyz), 0.0), vec4(y * len, 0.0), vec4(z, 0.0), vec4(pos, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_fade = smoothstep(near_fade * 0.35, near_fade, d);
}

void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = tint.rgb * COLOR.rgb * t.rgb * light;
	ALPHA = clamp(tint.a * COLOR.a * t.a * v_fade, 0.0, 1.0);
}
