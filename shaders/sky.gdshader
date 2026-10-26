// Stylised gradient sky with a hard-edged sun and soft banding.
shader_type sky;

uniform vec4 top_color : source_color = vec4(0.310, 0.722, 0.847, 1.0); // #4FB8D8
uniform vec4 horizon_color : source_color = vec4(0.969, 0.851, 0.627, 1.0); // #F7D9A0
uniform vec4 ground_color : source_color = vec4(0.784, 0.502, 0.353, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float sun_size : hint_range(0.0, 0.1) = 0.012;
uniform float bands = 0.0; // > 0 posterises the gradient
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.35;
uniform vec4 cloud_color : source_color = vec4(1.0, 0.97, 0.92, 1.0);
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;

void sky() {
	vec3 dir = EYEDIR;
	float up = clamp(dir.y, 0.0, 1.0);
	float t = smoothstep(0.0, 0.55, up);
	if (bands > 0.0) {
		t = floor(t * bands) / bands;
	}
	vec3 col = mix(horizon_color.rgb, top_color.rgb, t);
	if (dir.y < 0.0) {
		col = mix(horizon_color.rgb, ground_color.rgb, smoothstep(0.0, 0.15, -dir.y));
	}
	// Flat, hard-edged cartoon clouds.
	if (dir.y > 0.02) {
		vec2 uv = dir.xz / (dir.y + 0.25) * 0.15 + vec2(TIME * 0.002, 0.0);
		float c = texture(cloud_noise, uv).r;
		float mask = smoothstep(1.0 - cloud_amount, 1.0 - cloud_amount + 0.02, c);
		mask *= smoothstep(0.02, 0.2, dir.y);
		col = mix(col, cloud_color.rgb, mask * 0.9);
	}
	if (LIGHT0_ENABLED) {
		float s = dot(dir, LIGHT0_DIRECTION);
		float disk = smoothstep(1.0 - sun_size, 1.0 - sun_size * 0.8, s);
		col = mix(col, sun_color.rgb * 2.0, disk);
	}
	COLOR = col;
}
