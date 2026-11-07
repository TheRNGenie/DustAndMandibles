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
// masks (R: unused since the resin atlas, G: claw scrapes, B: burrow holes,
// A: silk stains). The hive resin is stamped from resin_atlas (four painted
// variants: drips, debris with trapped bugs and bones, cracked crust, pustules;
// RGB colour, A height; resin_nrm their normals) into a jittered grid of cells,
// each with its own variant, rotation, scale and offset, switched on by the
// infestation, so no two patches match. Thick sheets of crust and debris close
// round the tunnel mouths, the thickest parts glow with a slow pulse, and the
// wet surface catches a hard toon glint. The infestation grows with depth below the plateau top
// (plateau_y) and around the bug tunnels (hive_spots), drawn as flat colour
// shapes with a dark ink rim so it stays in the toon look.
// detail_level (Materials.set_terrain_detail, from the Effects setting):
// 0 Low = infestation only, one projection, one resin layer; 1 Medium = + the
// painted colour detail, a second resin layer and the ground's second scale;
// 2 High = + the normal maps (and the resin's glint), blended projections at corners.
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
uniform sampler2D resin_atlas : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D resin_nrm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float resin_cell = 4.2;       // metres per resin cell
uniform float resin_tile = 3.2;       // metres per painted resin tile
uniform vec4 resin_glow : source_color = vec4(1.0, 0.62, 0.18, 1.0);
uniform float resin_glow_strength : hint_range(0.0, 2.0) = 0.22;
// The exponential fog thins the detail on far walls: its contrast is raised to match.
uniform float haze_density = 0.0032;
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
uniform vec4 resin_dark : source_color = vec4(0.36, 0.16, 0.06, 1.0);
uniform vec4 resin_light : source_color = vec4(0.80, 0.47, 0.13, 1.0);
uniform vec4 hole_color : source_color = vec4(0.24, 0.12, 0.12, 1.0);
uniform vec4 silk_color : source_color = vec4(0.95, 0.90, 0.84, 1.0);
uniform vec4 ink : source_color = vec4(0.169, 0.106, 0.090, 1.0); // Palette.OUTLINE
// ...and heavier round the tunnel mouths: xyz centre, w radius (up to 24).
uniform vec4 hive_spots[24];
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

// tri() for use inside a branch: the same lookups with the derivatives passed in
// (dx, dy = how far p moves per pixel), so the mip picked never changes.
float tri_g(vec3 p, vec3 n, float scale, vec3 dx, vec3 dy) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float nx = textureGrad(noise_tex, p.zy * scale, dx.zy * scale, dy.zy * scale).r;
	float ny = textureGrad(noise_tex, p.xz * scale, dx.xz * scale, dy.xz * scale).r;
	float nz = textureGrad(noise_tex, p.xy * scale, dx.xy * scale, dy.xy * scale).r;
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

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// One layer of resin cells over the dominant projection (uv in metres; `wall`:
// a vertical surface whose v runs downward). Keeps the topmost resin found so
// far: colour, coverage, ink rim, thickness, tilt (uv space) and cell seed.
void resin_layer(vec2 uv, vec2 duvdx, vec2 duvdy, float layer, bool wall, float inf, float hive,
		bool with_nrm, inout vec3 r_col, inout float r_fill, inout float r_rim, inout float r_thick,
		inout vec2 r_tilt, inout float r_seed) {
	vec2 g = uv / resin_cell + layer * vec2(0.5, 0.37);
	vec2 cell = floor(g);
	vec2 c2 = cell + layer * 31.7;
	float h1 = hash12(c2);
	float h2 = hash12(c2 * 1.7 + 3.1);
	float h3 = hash12(c2 * 2.3 + 7.7);
	float h4 = hash12(c2 * 3.1 + 1.3);
	float h5 = hash12(c2 * 0.7 + 9.2);
	float h6 = hash12(c2 * 5.3 + 4.4);
	// More cells switch on as the infestation rises; round the tunnels nearly all.
	if (h1 > inf * 0.75 + hive * 0.5 - 0.25) {
		return;
	}
	vec2 f = fract(g) - 0.5 - (vec2(h5, h6) - 0.5) * 0.25;
	float ang = wall ? (h2 - 0.5) * 0.6 : h2 * 6.2832;
	float sc = mix(0.7, 1.35, h3) * mix(1.0, 1.35, hive);
	mat2 rot = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	vec2 lc = rot * f / sc;
	// The patch's outline: round on the ground, sagging long on the walls.
	vec2 e = lc;
	if (wall) {
		e.y *= e.y > 0.0 ? mix(0.45, 0.8, h6) : 1.4;
	}
	float env = 1.0 - smoothstep(0.12, 0.5, length(e));
	env = max(env, smoothstep(0.55, 1.0, hive) * 0.9); // sheets close over the tunnel mouths
	// Variant: drips, debris, crust, pustules (drips favoured on the walls,
	// debris and crust at the tunnels).
	float pick = h4;
	if (wall && pick < 0.5) {
		pick *= 0.5;
	}
	if (hive > 0.45) {
		pick = 0.25 + pick * 0.5;
	}
	float v = floor(pick * 4.0);
	vec2 q0 = vec2(mod(v, 2.0), floor(v / 2.0)) * 0.5;
	float k = resin_cell / resin_tile;
	vec2 t = lc * sc * k + vec2(h5, h6) * 3.0;
	vec2 auv = q0 + fract(t) * 0.49 + 0.005;
	mat2 j = rot * (k / resin_cell * 0.49);
	vec2 gdx = j * duvdx;
	vec2 gdy = j * duvdy;
	vec4 a = textureGrad(resin_atlas, auv, gdx, gdy);
	float thr = 1.0 - env * mix(0.5, 0.95, clamp(inf + hive * 0.4, 0.0, 1.0));
	float fill = smoothstep(thr, thr + 0.035, a.a);
	float rim = max(smoothstep(thr - 0.08, thr - 0.03, a.a) - fill, 0.0);
	if (fill > r_fill * 0.98) {
		r_col = a.rgb;
		r_thick = smoothstep(thr + 0.15, 1.0, a.a) * fill;
		r_seed = h2;
		if (with_nrm) {
			vec2 m = textureGrad(resin_nrm, auv, gdx, gdy).rg * 2.0 - 1.0;
			// tile space (image up = -v) back to the projection's uv space
			r_tilt = transpose(rot) * vec2(m.x, -m.y) * fill;
		}
	}
	r_rim = max(r_rim * (1.0 - fill), rim);
	r_fill = max(r_fill, fill);
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
	// Sand: patches of scrubby ground and pebble flecks (walls never show it, so
	// they skip the six lookups).
	vec3 sand = top_color.rgb * (1.0 + (detail - 0.5) * detail_strength);
	if (up > 0.0) {
		float scrub = smoothstep(0.6, 0.7, tri_g(world_pos, wn, noise_scale * 0.6, dpdx, dpdy));
		sand = mix(sand, scrub_color.rgb, scrub * 0.35);
		float pebble = smoothstep(0.8, 0.81, tri_g(world_pos * 22.0, wn, noise_scale, dpdx * 22.0, dpdy * 22.0));
		sand = mix(sand, band_b.rgb, pebble * 0.3);
	}

	// How deep into the canyon (0 on the plateau, 1 on the floor).
	float depth = clamp((plateau_y - world_pos.y) / max(plateau_y - floor_y, 1.0), 0.0, 1.0);
	// Hand-painted detail (Medium and up): ledged strata or blocky slabs on the
	// rock (a pick per band), the plateau's cracked hardpan turning to gravel,
	// flat stones and bones toward the floor. High also bends the normals.
	vec3 tilt = vec3(0.0);
	float haze_k = clamp(exp(haze_density * distance(world_pos, CAMERA_POSITION_WORLD)), 1.0, 1.9);
	if (detail_level >= 1) {
		float slabs = step(0.62, fract(idx * 0.618 + 0.3));
		if (up < 1.0) {
			vec4 dr = project(rock_tex, world_pos, wn, rock_tex_size, dpdx, dpdy);
			float rl = mix(dr.r, dr.g, slabs);
			rock *= max(1.0 + (0.45 + 1.1 * rl - 1.0) * rock_detail * haze_k, 0.25);
			// The painting's darkest strokes (crack lines, ledge undersides) as ink.
			rock = mix(rock, ink.rgb, min(smoothstep(0.16, 0.08, rl) * 0.55 * rock_detail * haze_k, 0.9));
			if (detail_level >= 2) {
				tilt += project_normal(rock_nrm, world_pos, wn, rock_tex_size, dpdx, dpdy, slabs) * rock_bump * (1.0 - up);
			}
		}
		if (up > 0.0) {
			vec4 dg = project(ground_tex, world_pos, wn, ground_tex_size, dpdx, dpdy);
			// A second, larger and turned copy, blended in by a big noise, so the
			// hardpan's cracks and the floor's stones never line up on a grid.
			const mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
			float s2 = 1.0 / (ground_tex_size * 2.3);
			vec2 g2 = turn * world_pos.xz * s2 + vec2(0.37, 0.71);
			vec4 dg2 = textureGrad(ground_tex, g2, turn * dpdx.xz * s2, turn * dpdy.xz * s2);
			float w2 = smoothstep(0.42, 0.58, big) * step(0.5, wn.y);
			dg = mix(dg, dg2, w2);
			float fl = smoothstep(0.35, 0.8, depth);
			vec3 plat = sand * mix(1.0, 0.45 + 1.1 * dg.a, ground_detail);
			vec3 flo = sand * max(vec3(1.0) + (dg.rgb * 2.0 - 1.0) * 1.5 * ground_detail, vec3(0.35));
			sand = mix(plat, flo, fl);
			if (detail_level >= 2) {
				tilt += project_normal(ground_nrm, world_pos, wn, ground_tex_size, dpdx, dpdy, 1.0 - step(0.5, fl)) * ground_bump * up * (1.0 - w2);
			}
		}
	}
	vec3 col = mix(rock, sand, up);

	// Infestation: thicker with depth, gathered in big patches (more on the walls
	// than the ground), and thickest round the tunnel mouths.
	float patch = smoothstep(0.38, 0.62, big);
	float inf = smoothstep(0.2, 1.0, depth) * mix(0.3, 1.0, patch) * mix(1.0, 0.75, up);
	float hive = 0.0;
	for (int i = 0; i < hive_count; i++) {
		vec4 s = hive_spots[i];
		float d = distance(world_pos, s.xyz);
		hive = max(hive, 1.0 - smoothstep(s.w * 0.35, s.w, d));
	}
	inf += hive * 0.6;
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
	}
	// Hive resin, stamped cell by cell on the dominant projection.
	vec3 aw = abs(wn);
	float sx = wn.x < 0.0 ? -1.0 : 1.0;
	float sz = wn.z < 0.0 ? -1.0 : 1.0;
	int axis = (aw.y >= aw.x && aw.y >= aw.z) ? 1 : (aw.x >= aw.z ? 0 : 2);
	vec2 ruv = axis == 1 ? world_pos.xz : (axis == 0 ? vec2(world_pos.z * sx, -world_pos.y) : vec2(-world_pos.x * sz, -world_pos.y));
	vec2 rdx = axis == 1 ? dpdx.xz : (axis == 0 ? vec2(dpdx.z * sx, -dpdx.y) : vec2(-dpdx.x * sz, -dpdx.y));
	vec2 rdy = axis == 1 ? dpdy.xz : (axis == 0 ? vec2(dpdy.z * sx, -dpdy.y) : vec2(-dpdy.x * sz, -dpdy.y));
	vec3 glow = vec3(0.0);
	if (inf > 0.12) {
		bool wall = axis != 1;
		bool nrm = detail_level >= 2;
		vec3 r_col = vec3(0.0);
		float r_fill = 0.0;
		float r_rim = 0.0;
		float r_thick = 0.0;
		float r_seed = 0.0;
		vec2 r_tilt = vec2(0.0);
		resin_layer(ruv, rdx, rdy, 0.0, wall, inf, hive, nrm, r_col, r_fill, r_rim, r_thick, r_tilt, r_seed);
		if (detail_level >= 1) {
			resin_layer(ruv, rdx, rdy, 1.0, wall, inf, hive, nrm, r_col, r_fill, r_rim, r_thick, r_tilt, r_seed);
		}
		if (r_fill + r_rim > 0.0) {
			// Painted resin, pulled a touch toward the palette's amber and darker
			// where thin; an ink rim round every patch.
			float rl = dot(r_col, vec3(0.299, 0.587, 0.114));
			vec3 rc = mix(resin_dark.rgb * 0.7, resin_light.rgb, smoothstep(0.12, 0.85, rl));
			rc = mix(rc, r_col * 0.8, 0.3) * mix(0.75, 1.0, r_thick);
			rc = mix(rc, vec3(1.0, 0.93, 0.78), smoothstep(0.86, 0.95, rl)); // painted highlights
			col = mix(col, rc, r_fill);
			col = mix(col, ink.rgb, r_rim * 0.75);
			// Slow pulse in the thickest parts, strongest at the tunnels and deep down.
			float pulse = 0.55 + 0.45 * sin(TIME * 1.6 + r_seed * 6.2832);
			glow = resin_glow.rgb * smoothstep(0.45, 0.9, r_thick) * pulse * resin_glow_strength * clamp(hive + depth * 0.5, 0.0, 1.0);
			// The resin's own bumps (uv space back to world).
			vec3 rt = axis == 1 ? vec3(r_tilt.x, 0.0, r_tilt.y) : (axis == 0 ? vec3(0.0, -r_tilt.y, sx * r_tilt.x) : vec3(-sz * r_tilt.x, -r_tilt.y, 0.0));
			tilt = mix(tilt, rt * 1.4, r_fill);
			// Wet sheen: a hard glint where the bumps face the camera (needs the
			// bumps, so High only; the painting's own highlights show at every level).
			if (nrm) {
				vec3 bn = normalize(wn + tilt);
				vec3 vdir = normalize(CAMERA_POSITION_WORLD - world_pos);
				float facing = dot(bn, vdir);
				float glint = smoothstep(0.95, 0.965, facing) * step(0.25, length(r_tilt));
				col = mix(col, vec3(1.0, 0.95, 0.82), clamp(glint, 0.0, 1.0) * r_fill * smoothstep(0.1, 0.4, r_thick) * 0.85);
			}
		}
	}
	if (detail_level >= 2) {
		vec3 bent = normalize(wn + tilt);
		NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz) * (FRONT_FACING ? 1.0 : -1.0);
	}
	EMISSION = glow;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
