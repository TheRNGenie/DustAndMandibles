// Triplanar canyon rock: sandstone strata of uneven thickness (six tones, one
// pale caprock stripe), desert-varnish streaks running down the walls, darker
// crevices from a big-scale noise, a damp dark base near the canyon floor, and
// sand on anything flat enough, with pebble flecks and scrubby patches.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 band_a : source_color = vec4(0.784, 0.392, 0.235, 1.0); // #C8643C
uniform vec4 band_b : source_color = vec4(0.659, 0.290, 0.196, 1.0); // #A84A32
uniform vec4 band_c : source_color = vec4(0.878, 0.541, 0.306, 1.0); // #E08A4E
uniform vec4 band_d : source_color = vec4(0.92, 0.74, 0.55, 1.0);    // pale cream stripe
uniform vec4 band_e : source_color = vec4(0.55, 0.24, 0.22, 1.0);    // deep oxblood
uniform vec4 band_f : source_color = vec4(0.82, 0.47, 0.30, 1.0);
uniform vec4 varnish : source_color = vec4(0.30, 0.17, 0.16, 1.0);   // dark drip streaks
uniform vec4 top_color : source_color = vec4(0.910, 0.698, 0.416, 1.0); // #E8B26A
uniform vec4 scrub_color : source_color = vec4(0.62, 0.55, 0.30, 1.0);
uniform float band_height = 2.6;
uniform float wobble = 1.6;
uniform float noise_scale = 0.04;
uniform float detail_strength : hint_range(0.0, 0.5) = 0.1;
uniform float top_threshold : hint_range(0.0, 1.0) = 0.72;
uniform float floor_y = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float tri(vec3 p, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float nx = texture(noise_tex, p.zy * scale).r;
	float ny = texture(noise_tex, p.xz * scale).r;
	float nz = texture(noise_tex, p.xy * scale).r;
	return nx * w.x + ny * w.y + nz * w.z;
}

vec3 band_color(float i) {
	float b = mod(i, 7.0);
	if (b < 1.0) return band_a.rgb;
	if (b < 2.0) return band_b.rgb;
	if (b < 3.0) return band_c.rgb;
	if (b < 4.0) return band_f.rgb;
	if (b < 5.0) return band_e.rgb;
	if (b < 6.0) return band_c.rgb;
	return band_d.rgb;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 wn = normalize(world_normal);
	float n = tri(world_pos, wn, noise_scale);
	float big = tri(world_pos, wn, noise_scale * 0.25);
	// Uneven strata: band edges wobble, and a second noise stretches some layers.
	float h = world_pos.y + (n - 0.5) * wobble * 2.0 + (big - 0.5) * 6.0;
	float idx = floor(h / band_height);
	vec3 rock = band_color(idx);
	// Thin dark seam at the bottom of every layer.
	float frac_h = fract(h / band_height);
	rock *= mix(0.78, 1.0, smoothstep(0.0, 0.08, frac_h));
	// Desert varnish: dark streaks dripping down steep walls.
	float steep = 1.0 - abs(wn.y);
	vec2 streak_uv = vec2(world_pos.x + world_pos.z, world_pos.y * 0.08);
	float streak = texture(noise_tex, streak_uv * vec2(0.09, 0.5)).r;
	streak = smoothstep(0.58, 0.72, streak) * steep;
	rock = mix(rock, varnish.rgb, streak * 0.45);
	// Crevices and shading variety at a large scale.
	rock *= mix(0.82, 1.08, big);
	// Damp, darker rock near the canyon floor.
	rock *= mix(0.72, 1.0, smoothstep(floor_y, floor_y + 9.0, world_pos.y));
	// Fine brush-stroke detail.
	float detail = tri(world_pos * 6.0, wn, noise_scale);
	rock *= 1.0 + (detail - 0.5) * detail_strength * 2.0;
	float up = step(0.0, wn.y) * smoothstep(top_threshold - 0.04, top_threshold + 0.04, abs(wn.y));
	// Sand: patches of scrubby ground and pebble flecks.
	vec3 sand = top_color.rgb * (1.0 + (detail - 0.5) * detail_strength);
	float scrub = smoothstep(0.6, 0.7, tri(world_pos, wn, noise_scale * 0.6));
	sand = mix(sand, scrub_color.rgb, scrub * 0.35);
	float pebble = smoothstep(0.8, 0.81, tri(world_pos * 22.0, wn, noise_scale));
	sand = mix(sand, band_b.rgb, pebble * 0.3);
	ALBEDO = mix(rock, sand, up);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
