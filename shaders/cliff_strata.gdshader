// Triplanar canyon rock: sandstone strata of uneven thickness (six tones, one
// pale caprock stripe), desert-varnish streaks running down the walls, darker
// crevices from a big-scale noise, a damp dark base near the canyon floor, and
// sand on anything flat enough, with pebble flecks and scrubby patches.
//
// On top of that, packed hand-painted textures (assets/terrain, AI-made with
// fal.ai): rock_tex shades the walls (R: ledged strata, G: blocky slabs, picked
// per band) and rock_nrm bends their normals (RG ledges, BA slabs) so the toon
// light draws hard bands on every ledge; ground_tex colours the canyon floor
// (RGB: gravel, flat stones, bone bits) and the plateau (A: cracked hardpan),
// with ground_nrm (RG floor, BA plateau); infest_tex holds the bug infestation
// masks (R: hive resin, G: claw scrapes, B: burrow holes, A: silk stains). The infestation grows with depth below the plateau top
// (plateau_y) and around the bug tunnels (hive_spots), drawn as flat colour
// shapes with a dark ink rim so it stays in the toon look.
// detail_level (Materials.set_terrain_detail, from the Effects setting):
// 0 Low = infestation only, one projection; 1 Medium = + the painted colour
// detail; 2 High = + the normal maps, and blended projections at the corners.
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

// Hand-painted detail and the infestation.
uniform sampler2D rock_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_nrm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ground_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ground_nrm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D infest_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform int detail_level = 2;
uniform float rock_tex_size = 14.0;   // metres per tile of the rock detail
uniform float ground_tex_size = 10.0; // metres per tile of the ground detail
uniform float infest_tex_size = 14.0; // metres per tile of the infestation masks
uniform float rock_detail : hint_range(0.0, 1.0) = 0.9;
uniform float ground_detail : hint_range(0.0, 1.0) = 0.8;
uniform float rock_bump : hint_range(0.0, 2.0) = 1.5;
uniform float ground_bump : hint_range(0.0, 2.0) = 0.8;
uniform float plateau_y = 60.0;       // the infestation starts below here...
uniform float infest_strength : hint_range(0.0, 2.0) = 1.0;
uniform vec4 resin_dark : source_color = vec4(0.42, 0.20, 0.07, 1.0);
uniform vec4 resin_light : source_color = vec4(0.80, 0.47, 0.13, 1.0);
uniform vec4 hole_color : source_color = vec4(0.24, 0.12, 0.12, 1.0);
uniform vec4 silk_color : source_color = vec4(0.95, 0.90, 0.84, 1.0);
uniform vec4 ink : source_color = vec4(0.169, 0.106, 0.090, 1.0); // Palette.OUTLINE
// ...and heavier round the tunnel mouths: xyz centre, w radius (up to 12).
uniform vec4 hive_spots[12];
uniform int hive_count = 0;

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

// A packed texture projected in world space: the two wall projections run with
// v downward (drips fall, ledges lie flat), the ground one from above. Only
// projections that carry weight are sampled (one on most pixels; High blends up
// to three at the corners); textureGrad keeps mip selection right in the branch.
// dpdx / dpdy: the screen derivatives of the world position, taken outside any branch.
vec4 project(sampler2D t, vec3 p, vec3 n, float size, vec3 dpdx, vec3 dpdy) {
	vec3 q = p / size;
	vec3 gx = dpdx / size;
	vec3 gy = dpdy / size;
	float sx = n.x < 0.0 ? -1.0 : 1.0;
	float sz = n.z < 0.0 ? -1.0 : 1.0;
	vec2 ux = vec2(q.z * sx, -q.y);
	vec2 uy = q.xz;
	vec2 uz = vec2(-q.x * sz, -q.y);
	vec2 dx_x = vec2(gx.z * sx, -gx.y), dy_x = vec2(gy.z * sx, -gy.y);
	vec2 dx_y = gx.xz, dy_y = gy.xz;
	vec2 dx_z = vec2(-gx.x * sz, -gx.y), dy_z = vec2(-gy.x * sz, -gy.y);
	vec3 a = abs(n);
	if (detail_level < 2) {
		if (a.y >= a.x && a.y >= a.z) return textureGrad(t, uy, dx_y, dy_y);
		if (a.x >= a.z) return textureGrad(t, ux, dx_x, dy_x);
		return textureGrad(t, uz, dx_z, dy_z);
	}
	vec3 w = pow(a, vec3(8.0));
	w /= (w.x + w.y + w.z);
	vec4 c = vec4(0.0);
	float tot = 0.0;
	if (w.x > 0.03) { c += textureGrad(t, ux, dx_x, dy_x) * w.x; tot += w.x; }
	if (w.y > 0.03) { c += textureGrad(t, uy, dx_y, dy_y) * w.y; tot += w.y; }
	if (w.z > 0.03) { c += textureGrad(t, uz, dx_z, dy_z) * w.z; tot += w.z; }
	return c / max(tot, 0.001);
}

// The same projection for a packed pair of normal maps (RG and BA, picked by
// `pick`): returns the world-space tilt to add to the surface normal.
vec3 project_normal(sampler2D t, vec3 p, vec3 n, float size, vec3 dpdx, vec3 dpdy, float pick) {
	vec3 q = p / size;
	vec3 gx = dpdx / size;
	vec3 gy = dpdy / size;
	float sx = n.x < 0.0 ? -1.0 : 1.0;
	float sz = n.z < 0.0 ? -1.0 : 1.0;
	vec3 w = pow(abs(n), vec3(8.0));
	w /= (w.x + w.y + w.z);
	vec3 off = vec3(0.0);
	if (w.x > 0.03) {
		vec4 c = textureGrad(t, vec2(q.z * sx, -q.y), vec2(gx.z * sx, -gx.y), vec2(gy.z * sx, -gy.y));
		vec2 m = mix(c.rg, c.ba, pick) * 2.0 - 1.0;
		off += vec3(0.0, m.y, sx * m.x) * w.x;
	}
	if (w.y > 0.03) {
		vec4 c = textureGrad(t, q.xz, gx.xz, gy.xz);
		vec2 m = mix(c.rg, c.ba, pick) * 2.0 - 1.0;
		off += vec3(m.x, 0.0, -m.y) * w.y;
	}
	if (w.z > 0.03) {
		vec4 c = textureGrad(t, vec2(-q.x * sz, -q.y), vec2(-gx.x * sz, -gx.y), vec2(-gy.x * sz, -gy.y));
		vec2 m = mix(c.rg, c.ba, pick) * 2.0 - 1.0;
		off += vec3(-sz * m.x, m.y, 0.0) * w.z;
	}
	return off;
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

// A flat-coloured shape where `field` passes `t`, with a thin ink rim at its edge.
// Returns (fill, rim).
vec2 shape(float field, float t) {
	float fill = smoothstep(t, t + 0.03, field);
	float rim = smoothstep(t - 0.06, t - 0.03, field) - fill;
	return vec2(fill, max(rim, 0.0));
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 wn = normalize(world_normal);
	vec3 dpdx = dFdx(world_pos);
	vec3 dpdy = dFdy(world_pos);
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

	// How deep into the canyon (0 on the plateau, 1 on the floor).
	float depth = clamp((plateau_y - world_pos.y) / max(plateau_y - floor_y, 1.0), 0.0, 1.0);
	// Hand-painted detail (Medium and up): ledged strata or blocky slabs on the
	// rock (a pick per band), the plateau's cracked hardpan turning to gravel,
	// flat stones and bones toward the floor. High also bends the normals.
	vec3 tilt = vec3(0.0);
	if (detail_level >= 1) {
		float slabs = step(0.62, fract(idx * 0.618 + 0.3));
		if (up < 1.0) {
			vec4 dr = project(rock_tex, world_pos, wn, rock_tex_size, dpdx, dpdy);
			float rl = mix(dr.r, dr.g, slabs);
			rock *= mix(1.0, 0.45 + 1.1 * rl, rock_detail);
			// The painting's darkest strokes (crack lines, ledge undersides) as ink.
			rock = mix(rock, ink.rgb, smoothstep(0.16, 0.08, rl) * 0.55 * rock_detail);
			if (detail_level >= 2) {
				tilt += project_normal(rock_nrm, world_pos, wn, rock_tex_size, dpdx, dpdy, slabs) * rock_bump * (1.0 - up);
			}
		}
		if (up > 0.0) {
			vec4 dg = project(ground_tex, world_pos, wn, ground_tex_size, dpdx, dpdy);
			float fl = smoothstep(0.35, 0.8, depth);
			vec3 plat = sand * mix(1.0, 0.45 + 1.1 * dg.a, ground_detail);
			vec3 flo = sand * max(vec3(1.0) + (dg.rgb * 2.0 - 1.0) * 1.5 * ground_detail, vec3(0.35));
			sand = mix(plat, flo, fl);
			if (detail_level >= 2) {
				tilt += project_normal(ground_nrm, world_pos, wn, ground_tex_size, dpdx, dpdy, 1.0 - step(0.5, fl)) * ground_bump * up;
			}
		}
	}
	if (detail_level >= 2) {
		vec3 bent = normalize(wn + tilt);
		NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz) * (FRONT_FACING ? 1.0 : -1.0);
	}
	vec3 col = mix(rock, sand, up);

	// Infestation: thicker with depth, gathered in big patches (more on the walls
	// than the ground), and thickest round the tunnel mouths.
	float patch = smoothstep(0.38, 0.62, big);
	float inf = smoothstep(0.2, 1.0, depth) * mix(0.3, 1.0, patch) * mix(1.0, 0.75, up);
	for (int i = 0; i < hive_count; i++) {
		vec4 s = hive_spots[i];
		float d = distance(world_pos, s.xyz);
		inf += (1.0 - smoothstep(s.w * 0.35, s.w, d)) * 0.6;
	}
	inf = clamp(inf * infest_strength, 0.0, 1.25);
	if (inf > 0.02) {
		vec4 m = project(infest_tex, world_pos, wn, infest_tex_size, dpdx, dpdy);
		// Silk stains: faint pale smears (more on the walls).
		float silk = smoothstep(0.45, 0.6, m.a) * smoothstep(0.25, 0.7, inf) * steep;
		col = mix(col, silk_color.rgb, silk * 0.14);
		// Claw scrapes on the walls: pale gouges with an ink edge.
		vec2 cs = shape(m.g * steep, mix(1.1, 0.6, smoothstep(0.1, 0.8, inf)));
		col = mix(col, col * 1.3 + vec3(0.07, 0.05, 0.03), cs.x);
		col = mix(col, ink.rgb, cs.y * 0.5);
		// Burrow holes (only the bigger ones): a darker crumbled ring, then the hole.
		float ht = mix(1.1, 0.8, smoothstep(0.35, 1.0, inf));
		float ring = smoothstep(ht - 0.3, ht - 0.25, m.b);
		col *= mix(1.0, 0.8, ring);
		vec2 hs = shape(m.b, ht + 0.04);
		col = mix(col, hole_color.rgb, hs.x);
		// Hive resin: amber glaze, two flat tones, dark ink rim.
		// The glaze is dark at its edge and catches the light inside (a toon highlight).
		float rf = m.r * mix(0.7, 1.05, n);
		float rt = mix(1.2, 0.6, smoothstep(0.3, 1.1, inf));
		vec2 rs = shape(rf, rt);
		float glint = smoothstep(rt + 0.22, rt + 0.25, rf * mix(0.9, 1.1, detail));
		vec3 resin = mix(resin_dark.rgb, resin_light.rgb, glint);
		col = mix(col, resin, rs.x);
		col = mix(col, ink.rgb, rs.y * 0.7);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
