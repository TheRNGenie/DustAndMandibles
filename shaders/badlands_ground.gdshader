// The badlands round the canyon (BadlandsTerrain): anything steep shows the
// canyon's strata bands by world height (a deep wash shows the same layers as
// the cliffs), with varnish streaks and darker south-facing walls; the flats are
// sand with scrubby patches and pebble flecks, pale sand in the washes, caliche
// hardpan with cracks in the basins and a darker varnished tint on mesa tops,
// and sand drifts onto low ledges. Bands too thin to draw fade to their average.
// `masks` on: vertex colour = (wash, mesa top, caliche) for the ground. Off: it
// tints the rock (formations), and 1 - alpha bleaches it (pale cap stones).
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 band_a : source_color = vec4(0.784, 0.392, 0.235, 1.0);
uniform vec4 band_b : source_color = vec4(0.659, 0.290, 0.196, 1.0);
uniform vec4 band_c : source_color = vec4(0.878, 0.541, 0.306, 1.0);
uniform vec4 band_d : source_color = vec4(0.92, 0.74, 0.55, 1.0);
uniform vec4 band_e : source_color = vec4(0.55, 0.24, 0.22, 1.0);
uniform vec4 band_f : source_color = vec4(0.82, 0.47, 0.30, 1.0);
uniform vec4 band_avg : source_color = vec4(0.80, 0.46, 0.31, 1.0);
uniform vec4 varnish : source_color = vec4(0.30, 0.17, 0.16, 1.0);
uniform vec4 sand_color : source_color = vec4(0.86, 0.63, 0.38, 1.0);
uniform vec4 wash_color : source_color = vec4(0.87, 0.74, 0.54, 1.0);
uniform vec4 caliche_color : source_color = vec4(0.84, 0.76, 0.62, 1.0);
uniform vec4 top_varnish : source_color = vec4(0.62, 0.36, 0.25, 1.0);
uniform vec4 scrub_color : source_color = vec4(0.55, 0.52, 0.30, 1.0);
uniform float band_height = 2.6;
uniform float base_y = 100.0;
uniform float tint_gain = 1.27;
uniform bool masks = true;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 vmask;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vmask = COLOR;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Distance from the nearest edge of a jittered cell grid (0 on a crack).
float cracks(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash12(i + g), hash12(i + g + 17.3));
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return sqrt(d2) - sqrt(d1);
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
	float dist = distance(world_pos, CAMERA_POSITION_WORLD);
	float big = texture(noise_tex, world_pos.xz * 0.0035).r;
	float mid = texture(noise_tex, (world_pos.xz + vec2(world_pos.y)) * 0.03).r;
	// Strata: wobbling band edges, a dark seam under each layer.
	float h = world_pos.y + (mid - 0.5) * 3.2 + (big - 0.5) * 7.0;
	vec3 rock = band_color(floor(h / band_height));
	rock *= mix(0.78, 1.0, smoothstep(0.0, 0.08, fract(h / band_height)));
	rock = mix(rock, band_avg.rgb, smoothstep(0.3, 0.9, fwidth(h) / band_height));
	// Varnish: dark drips down the walls, and south-facing faces darker still.
	float steep = 1.0 - abs(wn.y);
	float streak = texture(noise_tex, vec2(world_pos.x + world_pos.z, world_pos.y * 0.08) * vec2(0.05, 0.5)).r;
	streak = smoothstep(0.58, 0.72, streak) * steep;
	rock = mix(rock, varnish.rgb, streak * 0.4 + steep * smoothstep(0.1, 0.8, wn.z) * 0.28);
	rock *= mix(0.84, 1.08, big);

	vec3 m = masks ? vmask.rgb : vec3(0.0);
	float near = 1.0 - smoothstep(50.0, 150.0, dist);
	vec3 flat_c = sand_color.rgb * mix(0.9, 1.06, mid);
	float scrub = smoothstep(0.6, 0.7, texture(noise_tex, world_pos.xz * 0.021).r);
	flat_c = mix(flat_c, scrub_color.rgb, scrub * 0.3 * (1.0 - m.r));
	flat_c = mix(flat_c, caliche_color.rgb, m.b);
	if (near > 0.0 && m.b > 0.05) {
		float c = cracks(world_pos.xz * 0.45);
		flat_c = mix(flat_c, flat_c * 0.66, (1.0 - smoothstep(0.02, 0.07, c)) * m.b * near);
	}
	flat_c = mix(flat_c, wash_color.rgb * mix(0.94, 1.04, mid), m.r);
	flat_c = mix(flat_c, top_varnish.rgb * mix(0.85, 1.1, mid), m.g * 0.45);
	// Desert pavement: dark pebble flecks on the open flats close by.
	vec2 pg = world_pos.xz * 3.0;
	vec2 pid = floor(pg);
	vec2 pf = fract(pg) - 0.5 - (vec2(hash12(pid + 3.1), hash12(pid + 5.7)) - 0.5) * 0.6;
	float peb = step(0.8, hash12(pid)) * (1.0 - smoothstep(0.1, 0.17, length(pf * vec2(1.0, 1.4))));
	peb *= near * (1.0 - m.r) * (1.0 - m.b);
	flat_c = mix(flat_c, varnish.rgb * 1.3, peb * 0.5);

	float up = smoothstep(0.62, 0.8, wn.y);
	// Sand drifted onto the low ledges.
	float drift = smoothstep(0.35, 0.6, wn.y) * (1.0 - smoothstep(base_y - 18.0, base_y + 4.0, world_pos.y));
	up = max(up, drift * 0.75);
	vec3 col = mix(rock, flat_c, up);
	if (!masks) {
		col *= vmask.rgb * tint_gain;
		col = mix(col, caliche_color.rgb * mix(0.9, 1.0, mid), 1.0 - vmask.a);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
