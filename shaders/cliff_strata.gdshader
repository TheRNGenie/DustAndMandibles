// Triplanar rock shader: colours rock in horizontal sandstone bands by world height,
// with noise wobble, and turns flat upward surfaces into sand.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 band_a : source_color = vec4(0.784, 0.392, 0.235, 1.0); // #C8643C
uniform vec4 band_b : source_color = vec4(0.659, 0.290, 0.196, 1.0); // #A84A32
uniform vec4 band_c : source_color = vec4(0.878, 0.541, 0.306, 1.0); // #E08A4E
uniform vec4 top_color : source_color = vec4(0.910, 0.698, 0.416, 1.0); // #E8B26A
uniform float band_height = 3.2;
uniform float wobble = 1.4;
uniform float noise_scale = 0.04;
uniform float detail_strength : hint_range(0.0, 0.5) = 0.08;
uniform float top_threshold : hint_range(0.0, 1.0) = 0.72;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float triplanar_noise(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float nx = texture(noise_tex, p.zy * noise_scale).r;
	float ny = texture(noise_tex, p.xz * noise_scale).r;
	float nz = texture(noise_tex, p.xy * noise_scale).r;
	return nx * w.x + ny * w.y + nz * w.z;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 wn = normalize(world_normal);
	float n = triplanar_noise(world_pos, wn);
	float h = world_pos.y + (n - 0.5) * wobble * 2.0;
	float band = mod(floor(h / band_height), 4.0);
	vec3 rock = band_a.rgb;
	if (band == 1.0) {
		rock = band_b.rgb;
	} else if (band == 2.0) {
		rock = band_c.rgb;
	} else if (band == 3.0) {
		rock = mix(band_a.rgb, band_b.rgb, 0.5);
	}
	// Fine brush-stroke detail.
	float detail = triplanar_noise(world_pos * 6.0, wn);
	rock *= 1.0 + (detail - 0.5) * detail_strength * 2.0;
	float up = step(0.0, wn.y) * smoothstep(top_threshold - 0.04, top_threshold + 0.04, abs(wn.y));
	vec3 sand = top_color.rgb * (1.0 + (detail - 0.5) * detail_strength);
	ALBEDO = mix(rock, sand, up);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
