// Dust & Mandibles sky: a painted, toon-lit western sky drawn in one pass.
//
// From the back forward: a graded sky (sun-side scattering, a bright haze line
// on the horizon, golden-hour flare, the earth's shadow and the pink belt
// opposite a low sun, a faint airglow at night); stars, the Milky Way, shooting
// stars and a moon with phases; the sun disk; high cloud (cirrus streaks
// combed by the wind, or a mackerel sky); distant cloud banks and storm towers
// all round the horizon (rain shafts under them in storms, a dust wall in a
// dust storm); the main cumulus deck, lit in three toon tones from the sun's
// side with silver linings; then the sun's corona and sunburst, and the haze
// that melts the far ground into the sky.
//
// DayCycle drives everything: the colours by the clock, and the cloud mix
// (cover, high cloud, banks, wind) by the wave and the weather. Every cloud
// shape comes from one tiling noise texture (assets/sky/sky_noise.png, made
// by tools/sky/make_sky_noise.py); the reflection cubemap pass skips the fine
// detail.
shader_type sky;
render_mode use_debanding;

uniform vec4 top_color : source_color = vec4(0.310, 0.722, 0.847, 1.0); // #4FB8D8
uniform vec4 horizon_color : source_color = vec4(0.969, 0.851, 0.627, 1.0); // #F7D9A0
uniform vec4 ground_color : source_color = vec4(0.784, 0.502, 0.353, 1.0);
// The scene fog's colour (DayCycle): the sky meets it at and below the horizon,
// so the far ground (fully fogged before the camera's far plane) melts into the
// sky with no edge. fog_band: how far above the horizon the blend reaches.
uniform vec4 fog_color : source_color = vec4(0.969, 0.851, 0.627, 1.0);
uniform float fog_band = 0.07;
uniform bool use_fog_color = false;
// The painted mesa strip read as floating upside-down shapes from the airship;
// off (the real far mesas and the fog make the horizon now).
uniform bool use_mesa_strip = false;
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float sun_size : hint_range(0.0, 0.1) = 0.012;
uniform float bands = 0.0; // > 0 posterises the gradient
uniform vec4 cloud_color : source_color = vec4(1.0, 0.97, 0.92, 1.0);
// R: low cloud-field noise, G: billows, B: cells, A: fine wisps (all tiling).
uniform sampler2D sky_noise : filter_linear_mipmap, repeat_enable;
// 0 by day, 1 at full night (stars, moon instead of sun).
uniform float night : hint_range(0.0, 1.0) = 0.0;
// 0..1: how strongly the low sun floods the horizon with colour (golden hour).
uniform float golden : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.55, 0.25, 1.0);
// Storms and dust hide the sun, moon and stars.
uniform float overcast : hint_range(0.0, 1.0) = 0.0;

// The cloud mix (DayCycle: a style per wave, then the weather on top).
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.3; // cumulus cover
uniform float cloud_scale = 1.0; // > 1 bigger clouds
uniform float cirrus : hint_range(0.0, 1.0) = 0.3; // high streaks combed by the wind
uniform float alto : hint_range(0.0, 1.0) = 0.0; // a mackerel sky of small high puffs
uniform float bank : hint_range(0.0, 1.0) = 0.45; // cloud banks and towers on the horizon
uniform vec2 cloud_seed = vec2(0.0); // per run: where in the noise the sky starts
uniform vec2 cloud_drift = vec2(0.0); // how far the wind has carried the clouds
uniform vec2 wind = vec2(1.0, 0.25); // direction (and strength) the clouds travel
// Weather: storm towers and rain shafts, a dust wall, heat glare and shimmer,
// fog haze, a blood moon, and a lightning flash.
uniform float storm : hint_range(0.0, 1.0) = 0.0;
uniform float dust : hint_range(0.0, 1.0) = 0.0;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float haze : hint_range(0.0, 1.0) = 0.0;
uniform float blood : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// 0 = new moon, 0.25 first quarter, 0.5 full, 0.75 last quarter.
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;
// 1 = everything; 0 (Low effects) drops the high cloud, rays and rain shafts.
uniform float detail : hint_range(0.0, 1.0) = 1.0;

// Painted art (assets/sky, AI-made with fal.ai): a starfield, and a strip of
// distant mesas round the horizon.
uniform bool use_art = false;
uniform sampler2D art_stars : filter_linear_mipmap, repeat_enable;
uniform sampler2D art_mesas : source_color, filter_linear_mipmap, repeat_enable;

float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

// Three soft-edged toon tones (0, 0.5, 1) from a 0..1 light amount.
float toon3(float l, float a, float b) {
	return smoothstep(a - 0.03, a + 0.03, l) * 0.5 + smoothstep(b - 0.03, b + 0.03, l) * 0.5;
}

// Hard little stars on a cube-ish grid of directions, twinkling, in three
// layers: a dust of faint ones, a scatter of ordinary ones, and a few big
// bright ones with a four-point toon glint. Slightly warm or cool by star.
vec3 stars(vec3 dir) {
	vec3 s = vec3(0.0);
	vec3 t1 = normalize(cross(dir, vec3(0.0, 1.0, 0.001)));
	vec3 t2 = cross(dir, t1);
	for (int layer = 0; layer < 3; layer++) {
		float scale = layer == 0 ? 90.0 : (layer == 1 ? 190.0 : 38.0);
		float keep = layer == 0 ? 0.962 : (layer == 1 ? 0.925 : 0.982);
		vec3 p = dir * scale;
		vec3 cell = floor(p);
		float h = hash(cell + float(layer) * 17.0);
		if (h > keep) {
			vec3 c = cell + 0.2 + 0.6 * vec3(hash(cell + 1.3), hash(cell + 2.7), hash(cell + 4.1));
			vec3 v = p - c;
			float d = length(v);
			float tw = 0.65 + 0.35 * sin(TIME * (1.5 + h * 4.0) + h * 40.0);
			vec3 tint = mix(vec3(0.8, 0.88, 1.0), vec3(1.0, 0.86, 0.66), hash(cell + 7.7));
			if (layer == 2) {
				float core = smoothstep(0.2, 0.1, d);
				float dx = abs(dot(v, t1));
				float dy = abs(dot(v, t2));
				float glint = (smoothstep(0.045, 0.0, dy) * smoothstep(0.75, 0.0, dx) + smoothstep(0.045, 0.0, dx) * smoothstep(0.75, 0.0, dy)) * (0.55 + 0.45 * tw);
				s += mix(vec3(1.0), tint, 0.5) * (core * 1.6 + glint * 0.9);
			} else {
				float size = layer == 0 ? 0.28 : 0.18;
				s += tint * smoothstep(size, size * 0.4, d) * tw * (layer == 0 ? 1.0 : 0.6);
			}
		}
	}
	return s;
}

// The Milky Way: a patchy band of star clouds with a dark dust lane down it,
// swelling to a warm bright bulge toward one end. bulge: how much of that.
float milky(vec3 dir, out float lane, out float bulge) {
	vec3 bn = normalize(vec3(0.62, 0.38, -0.69));
	float off = dot(dir, bn);
	vec3 a = normalize(cross(bn, vec3(0.0, 1.0, 0.0)));
	vec3 b = cross(bn, a);
	vec2 uv = vec2(dot(dir, a), dot(dir, b));
	float n1 = texture(sky_noise, uv * 0.9 + vec2(0.31, 0.17)).r;
	float n2 = texture(sky_noise, uv * 2.7 + vec2(0.6, 0.4)).r;
	float cells = texture(sky_noise, uv * 3.5 + vec2(0.2, 0.8)).b; // knots of star cloud
	bulge = exp(-pow(length(uv - vec2(0.55, -0.35)) * 2.6, 2.0));
	float grain = texture(sky_noise, uv * 9.0 + vec2(0.5, 0.1)).a; // fine star dust
	float clumps = clamp(n1 * 0.8 + n2 * 0.6 - 0.45, 0.0, 1.0) * (0.6 + cells * 0.8) * (0.7 + grain * 0.6);
	float width = 0.16 + (n1 - 0.5) * 0.1 + bulge * 0.12;
	float band = 1.0 - smoothstep(0.0, width, abs(off));
	lane = (1.0 - smoothstep(0.0, 0.035 + n2 * 0.03 + bulge * 0.03, abs(off + (n1 - 0.5) * 0.06))) * band;
	return band * (0.25 + clumps * 1.3 + bulge * 0.6);
}

// A shooting star now and then on a clear night (one chance every six seconds).
float meteor(vec3 dir) {
	float per = 6.0;
	float slot = floor(TIME / per);
	float tt = TIME - slot * per;
	if (hash(vec3(slot, 3.7, 1.9)) < 0.55 || tt > 0.8) {
		return 0.0;
	}
	float a1 = hash(vec3(slot, 5.1, 2.3)) * 6.2832;
	float e1 = 0.4 + hash(vec3(slot, 7.3, 4.4)) * 0.5;
	vec3 p0 = vec3(cos(a1) * cos(e1), sin(e1), sin(a1) * cos(e1));
	vec3 tx = normalize(cross(p0, vec3(0.0, 1.0, 0.0)));
	float side = hash(vec3(slot, 9.1, 6.6)) > 0.5 ? 1.0 : -1.0;
	vec3 trav = normalize(tx * side + vec3(0.0, -0.55, 0.0));
	float k = tt / 0.8;
	vec3 head = p0 + trav * 0.3 * k;
	vec3 tail = p0 + trav * 0.3 * max(k - 0.3, 0.0);
	vec3 seg = head - tail;
	float u = clamp(dot(dir - tail, seg) / max(dot(seg, seg), 1e-6), 0.0, 1.0);
	float d = length(dir - (tail + seg * u));
	return smoothstep(0.0018, 0.0003, d) * u * u * sin(k * 3.1416);
}

void sky() {
	vec3 dir = EYEDIR;
	bool fine = !AT_CUBEMAP_PASS; // reflections skip the fine detail
	bool rich = fine && detail > 0.5;
	float up = max(dir.y, 0.0);
	float day = 1.0 - night;
	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0, 1.0, 0.0);
	float to_sun = dot(dir, sun_dir);
	vec2 ring = normalize(dir.xz + vec2(1e-5, 0.0)); // compass bearing
	vec2 sun_ring = normalize(sun_dir.xz + vec2(1e-5, 0.0));
	float facing = dot(ring, sun_ring) * 0.5 + 0.5; // 1 toward the sun's bearing
	vec3 haze_col = use_fog_color ? fog_color.rgb : horizon_color.rgb;
	// Heat shimmer: the horizon wobbles.
	float hy = dir.y;
	if (heat > 0.0 && fine) {
		float az = atan(dir.x, dir.z);
		hy += sin(az * 90.0 + TIME * 3.1) * sin(az * 37.0 - TIME * 1.7) * 0.0025 * heat * exp(-up * 25.0);
	}

	// ---- The graded sky.
	float t = (1.0 - exp(-up * 3.2)) / (1.0 - exp(-3.2));
	if (bands > 0.0) {
		t = floor(t * bands) / bands;
	}
	vec3 col = mix(horizon_color.rgb, top_color.rgb, t);
	col += horizon_color.rgb * 0.1 * exp(-abs(hy) * 30.0) * day; // the bright haze line
	col *= 1.0 - 0.07 * (1.0 - facing) * day * (1.0 - t * 0.5); // the far side of the sky a shade cooler
	col += sun_color.rgb * pow(max(to_sun, 0.0), 5.0) * (0.1 + golden * 0.18 + heat * 0.12) * day * (1.0 - overcast * 0.6);
	// Golden hour: the horizon toward the sun flares orange-pink in soft toon
	// steps; opposite the sun the earth's blue shadow rises under a pink belt.
	if (golden > 0.0 && dir.y > -0.05) {
		float low = 1.0 - smoothstep(0.0, 0.35, up);
		float f = pow(facing, 3.0) * low * 5.0;
		float flare = (floor(f) + smoothstep(0.8, 1.0, fract(f))) / 5.0;
		col = mix(col, glow_color.rgb, flare * golden * 0.8);
		float anti = (1.0 - facing) * (1.0 - facing);
		float earth = 1.0 - smoothstep(0.0, 0.055, up);
		float belt = smoothstep(0.035, 0.075, up) * (1.0 - smoothstep(0.12, 0.26, up));
		col = mix(col, col * vec3(0.7, 0.74, 0.94), earth * anti * golden * 0.55);
		col = mix(col, vec3(0.9, 0.6, 0.68), belt * anti * golden * 0.4);
	}
	// A heat wave bleaches the sky: a pale, hot glare that whitens toward the horizon.
	col = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))) * vec3(1.08, 1.0, 0.86) + 0.08, heat * 0.7);
	col = mix(col, horizon_color.rgb * 1.06 + 0.04, heat * exp(-up * 7.0) * 0.45);
	col += vec3(0.03, 0.07, 0.06) * exp(-up * 10.0) * night * (1.0 - overcast); // airglow
	if (dir.y < 0.0) {
		col = mix(horizon_color.rgb, ground_color.rgb, smoothstep(0.0, 0.15, -dir.y));
	}

	// ---- Night: stars, the Milky Way, a shooting star now and then.
	if (night > 0.0 && dir.y > 0.0 && fine) {
		float fade = night * (1.0 - overcast) * smoothstep(0.0, 0.25, dir.y) * (1.0 - blood * 0.45) * (1.0 - dust);
		float lane;
		float bulge;
		float mw = milky(dir, lane, bulge);
		col += mix(vec3(0.32, 0.34, 0.55), vec3(0.62, 0.5, 0.42), bulge) * mw * fade * 0.42;
		col = mix(col, col * 0.7, lane * fade * 0.6);
		col += stars(dir) * fade * (1.0 + mw * 0.8) * (1.0 - lane * 0.7);
		if (use_art) {
			vec2 suv = dir.xz / (dir.y + 0.35) * 0.6;
			col += vec3(0.95, 0.95, 1.0) * textureLod(art_stars, suv, 0.0).r * fade * 0.9;
		}
		if (night > 0.55) {
			col += vec3(1.0, 0.95, 0.85) * meteor(dir) * 1.6 * fade;
		}
	}

	// ---- The sun disk, or the moon with its phase (clouds pass in front).
	float phase_light = 1.0 - abs(moon_phase - 0.5) * 2.0; // 1 at full
	if (LIGHT0_ENABLED) {
		if (night < 0.5) {
			float low = 1.0 - smoothstep(0.05, 0.35, sun_dir.y);
			float sr = sun_size * 0.22 * (1.0 + low * 0.3 + heat * 0.2);
			float disk = smoothstep(1.0 - sr, 1.0 - sr * 0.9, to_sun);
			float core = smoothstep(1.0 - sr * 0.9, 1.0, to_sun);
			col = mix(col, sun_color.rgb * mix(1.7, 2.3, core), disk * (1.0 - overcast * 0.8));
		} else {
			float msize = sun_size * 0.32 * (1.0 + blood * 1.6);
			float disk = smoothstep(1.0 - msize, 1.0 - msize * 0.93, to_sun);
			if (disk > 0.0) {
				vec3 side = normalize(cross(sun_dir, vec3(0.0, 1.0, 0.0)) + 1e-4);
				vec3 upv = cross(side, sun_dir);
				vec2 m = vec2(dot(dir, side), dot(dir, upv)) / sqrt(msize * 2.0); // -1..1 across the disk
				float nz = sqrt(max(1.0 - dot(m, m), 0.0));
				float ph = moon_phase * 6.2832;
				float lit = smoothstep(-0.04, 0.1, dot(vec3(m, nz), normalize(vec3(sin(ph), 0.15 * sin(ph), -cos(ph)))));
				float maria = smoothstep(0.52, 0.66, texture(sky_noise, m * 0.22 + vec2(0.31, 0.63)).r);
				float crater = texture(sky_noise, m * 0.45 + vec2(0.7, 0.2)).b;
				vec3 albedo = mix(vec3(1.0, 0.97, 0.9), vec3(0.6, 0.62, 0.72), maria) * mix(0.88, 1.06, crater) * mix(0.78, 1.0, nz);
				vec3 moon = mix(col * 1.15 + albedo * 0.05, albedo * 1.08, lit); // the dark side shows faint earthshine
				moon = mix(moon, moon * vec3(1.15, 0.36, 0.26), blood);
				col = mix(col, moon, disk * (1.0 - overcast * 0.7));
			}
		}
	}

	vec3 c_lit = cloud_color.rgb;
	c_lit = mix(c_lit, glow_color.rgb * 1.15 + vec3(0.1), golden * 0.45 * (0.4 + 0.6 * facing));
	vec3 c_shadow = mix(cloud_color.rgb * vec3(0.58, 0.58, 0.72), top_color.rgb * 0.9, 0.25);
	c_shadow = mix(c_shadow, vec3(0.6, 0.43, 0.6) * length(cloud_color.rgb) * 0.6, golden * 0.45);
	c_lit = mix(c_lit, c_lit * 0.74, overcast);
	c_shadow = mix(c_shadow, c_shadow * vec3(0.52, 0.54, 0.6), overcast * (0.6 + storm * 0.4));
	// Moonlit clouds stay low-key: grey crowns, bases close to the night sky.
	c_lit *= mix(1.0, 0.8, night);
	c_shadow = mix(c_shadow, top_color.rgb * 1.35, night * 0.6);
	c_lit = mix(c_lit, c_lit * vec3(1.2, 0.55, 0.5), blood * night * 0.6);
	// Lightning: a strike lights the clouds; in a thunderstorm the far towers
	// flicker with sheet lightning between strikes.
	float slot = floor(TIME * 0.7);
	float fa = hash(vec3(slot, 4.0, 2.0)) * 6.2832;
	float spot = pow(max(dot(ring, vec2(sin(fa), cos(fa))), 0.0), 24.0);
	float sheet = storm > 0.6 ? step(0.9, hash(vec3(floor(TIME * 9.0), 1.0, 2.0))) * step(0.55, hash(vec3(slot, 7.0, 3.0))) * spot * (storm - 0.6) * 2.5 : 0.0;
	vec3 bolt = vec3(0.72, 0.78, 1.0) * (flash * (0.35 + 0.65 * spot) + sheet);
	float cloud_a = 0.0; // how much cloud covers this point (dims the sun's glow)
	vec2 wd = normalize(wind + vec2(1e-4, 0.0)); // the wind's heading

	// ---- High cloud: cirrus streaks combed out along the wind, or a mackerel
	// sky of small puffs in ripples across it. The amount sets how much of the
	// sky they spread over.
	if (dir.y > 0.0 && rich && (cirrus > 0.0 || alto > 0.0)) {
		vec2 hu = dir.xz / (dir.y + 0.09) * (0.24 * cloud_scale) + cloud_seed * 1.37 + cloud_drift * 1.8;
		vec2 wr = vec2(dot(hu, wd), dot(hu, vec2(-wd.y, wd.x)));
		float hpatch = texture(sky_noise, hu * 0.3 + vec2(0.13, 0.57)).r;
		vec3 hcol = mix(cloud_color.rgb * 1.05, glow_color.rgb * 1.3 + vec3(0.12, 0.05, 0.1), golden * 0.75);
		hcol = mix(hcol, haze_col, (1.0 - smoothstep(0.0, 0.25, dir.y)) * 0.5) * mix(1.0, 0.55, night);
		float hfade = smoothstep(0.02, 0.12, dir.y) * (1.0 - overcast * 0.8) * (1.0 - night * 0.6);
		if (cirrus > 0.0) {
			float st = texture(sky_noise, vec2(wr.x * 0.16, (wr.y + (hpatch - 0.5) * 0.18) * 2.2)).a;
			float ci = smoothstep(0.52, 0.86, st) * smoothstep(0.92 - cirrus * 0.6, 1.02 - cirrus * 0.5, hpatch);
			col = mix(col, hcol, ci * 0.6 * hfade);
			cloud_a = max(cloud_a, ci * 0.3);
		}
		if (alto > 0.0) {
			vec2 au = vec2(wr.x * 1.7, wr.y * 0.85);
			float ac = texture(sky_noise, au).b;
			float ac2 = texture(sky_noise, au - vec2(0.0, 0.025)).b;
			float am = smoothstep(0.56, 0.66, ac) * smoothstep(0.95 - alto * 0.55, 1.05 - alto * 0.45, hpatch);
			vec3 acol = mix(mix(hcol, c_shadow, 0.45), hcol, smoothstep(-0.04, 0.04, ac - ac2));
			col = mix(col, acol, am * 0.9 * hfade);
			cloud_a = max(cloud_a, am * 0.5);
		}
	}

	// ---- Banks and towers round the horizon (taller in storms; a dust wall in
	// a dust storm), with rain shafts hanging under storm cells.
	float bank_k = clamp(bank + storm * 0.6 + dust * 0.8, 0.0, 1.0);
	if (dir.y > -0.02 && dir.y < 0.6 && bank_k > 0.0) {
		vec2 seed_b = cloud_seed * 0.53 + vec2(cloud_drift.x * 0.25, 0.0);
		float prof = texture(sky_noise, ring * 0.5 + cloud_seed * 0.31 + vec2(0.7, 0.2)).r;
		// Low banks most waves; a big sky (or a storm) builds towers where the
		// profile peaks.
		float towers = smoothstep(0.5, 0.95, bank_k);
		float hmax = (0.05 + 0.1 * bank_k + storm * 0.12 + dust * 0.14) * (0.5 + pow(prof, 2.5) * (1.0 + 4.0 * towers));
		float rel = clamp(dir.y / max(hmax, 0.01), 0.0, 2.0);
		float b = texture(sky_noise, ring * (1.0 + dir.y * 3.5) + seed_b).g;
		float bdet = fine ? texture(sky_noise, ring * (4.0 + dir.y * 18.0) + seed_b * 2.0).a : 0.6;
		float dens = b - smoothstep(0.0, 1.0, rel) * 0.95 - smoothstep(0.9, 1.2, rel) + 0.28 + (prof - 0.5) * 0.2 - (1.0 - bdet) * 0.12;
		float ba = smoothstep(0.02, 0.1 + dust * 0.2, dens) * smoothstep(-0.02, 0.01, dir.y) * smoothstep(0.0, 0.35, bank_k);
		if (ba > 0.001) {
			float y2 = dir.y + 0.018;
			float b2 = texture(sky_noise, ring * (1.0 + y2 * 3.5) + seed_b).g;
			float rel2 = clamp(y2 / max(hmax, 0.01), 0.0, 2.0);
			float dens2 = b2 - smoothstep(0.0, 1.0, rel2) * 0.95 - smoothstep(0.9, 1.2, rel2) + 0.28 + (prof - 0.5) * 0.2 - (1.0 - bdet) * 0.12;
			float top = clamp((dens - dens2) * 2.5 + 0.45, 0.0, 1.0); // the billow's sunlit crown
			float tone = toon3(top * 0.5 + facing * 0.3 + rel * 0.25, 0.45, 0.68);
			vec3 bcol = mix(c_shadow, c_lit, tone);
			vec3 dust_col = mix(haze_col, vec3(0.74, 0.52, 0.33), 0.45);
			bcol = mix(bcol, mix(dust_col * 0.78, dust_col * 1.08, tone), dust);
			bcol += bolt * (0.5 + 0.5 * (1.0 - rel));
			bcol = mix(bcol, haze_col, 0.18 + 0.32 * (1.0 - smoothstep(0.0, 0.8, rel)));
			col = mix(col, bcol, ba);
			cloud_a = max(cloud_a, ba);
		}
		if (storm > 0.3 && rich && dir.y < 0.14) {
			float cell = texture(sky_noise, ring * 0.9 + cloud_seed + vec2(0.3, 0.9)).r;
			float s = texture(sky_noise, ring * 2.2 + vec2(dir.y * 0.5 * sign(wind.x), 0.0)).r;
			float shaft = smoothstep(0.5, 0.75, s) * smoothstep(0.5, 0.72, cell) * (1.0 - smoothstep(0.0, 0.12, dir.y)) * smoothstep(-0.01, 0.01, dir.y);
			col = mix(col, mix(c_shadow, haze_col, 0.4), shaft * (storm - 0.3) * 0.9);
		}
	}

	// ---- The cumulus deck: rounded billows gathered into clouds with blue
	// between, lit in three toon tones (bright crowns toward the top of the sky
	// and the sun's side, shaded bases), a silver lining near the sun, and
	// hazier toward the horizon. Storms close the gaps.
	float cov = clamp(cloud_amount + overcast * 0.25, 0.0, 1.0);
	if (dir.y > 0.0 && cov > 0.001) {
		vec2 cu = dir.xz / (dir.y + 0.17) * (0.3 * cloud_scale) + cloud_seed + cloud_drift;
		float thr = 1.02 - cov * 0.82 - overcast * 0.3; // a storm closes the deck
		float dens = (texture(sky_noise, cu * 0.42 + vec2(0.37, 0.71), 3.0).r + (texture(sky_noise, cu).g - 0.5) * 0.24 - thr) * 5.0;
		float det = fine ? texture(sky_noise, cu * 3.1 + cloud_drift * 0.6).a : 0.6;
		dens -= (1.0 - det) * 0.35 * (1.0 - smoothstep(0.0, 1.0, dens));
		float a = smoothstep(0.0, 0.3, dens) * smoothstep(0.0, 0.07, dir.y);
		if (a > 0.001) {
			// Probe the cloud a step up the sky and toward the sun: where it thins
			// out there, this point is on a lit crown.
			vec2 cp = cu - ring * (0.05 * (1.0 - smoothstep(0.55, 0.95, dir.y))) + sun_dir.xz * 0.045;
			float dens2 = (texture(sky_noise, cp * 0.42 + vec2(0.37, 0.71), 3.0).r + (texture(sky_noise, cp).g - 0.5) * 0.24 - thr) * 5.0;
			float edge = clamp((dens - dens2) * 0.6 + 0.5, 0.0, 1.0);
			float thick = smoothstep(0.3, 2.2, dens);
			// Seen from the side, crowns catch the light; seen from below, the base
			// is one soft shade with bright thin edges.
			float below = smoothstep(0.5, 0.9, dir.y);
			float tone = toon3(mix(edge * 0.72 + (1.0 - thick) * 0.28, (1.0 - thick) * 0.75 + edge * 0.25, below), 0.42, 0.6);
			vec3 ccol = mix(c_shadow, c_lit, tone) * (0.96 + 0.06 * det);
			float lining = (1.0 - smoothstep(0.0, 0.6, dens)) * pow(max(to_sun, 0.0), 12.0);
			ccol += mix(sun_color.rgb, vec3(1.0, 0.3, 0.2), blood * night) * lining * mix(1.3, 0.45, night) * (1.0 - overcast * 0.7);
			ccol += bolt * (0.3 + 0.4 * thick);
			ccol = mix(ccol, haze_col, (1.0 - smoothstep(0.0, 0.32, dir.y)) * 0.55);
			col = mix(col, ccol, a * mix(1.0, 0.92, night));
			cloud_a = max(cloud_a, a);
		}
	}

	// ---- Light over the clouds: the sun's corona, toon halo and sunburst, or
	// the moon's cool glow (a blood moon's red one) and a halo ring in thin cloud.
	if (LIGHT0_ENABLED) {
		float s = max(to_sun, 0.0);
		float sv = (1.0 - overcast * 0.75) * (1.0 - cloud_a * 0.55);
		if (night < 0.5) {
			vec3 glow = sun_color.rgb * (pow(s, 900.0) * 0.6 + pow(s, 90.0) * (0.22 + golden * 0.35 + heat * 0.25) + pow(s, 14.0) * golden * 0.22);
			glow += sun_color.rgb * smoothstep(1.0 - sun_size * 1.2, 1.0 - sun_size * 1.0, to_sun) * 0.1;
			if (rich && s > 0.5) {
				vec3 sx = normalize(cross(sun_dir, vec3(0.0, 1.0, 0.0)) + 1e-4);
				vec3 sy = cross(sx, sun_dir);
				vec2 sp = vec2(dot(dir, sx), dot(dir, sy));
				float dist = length(sp);
				float rn = texture(sky_noise, sp / max(dist, 1e-4) * 1.3 + vec2(TIME * 0.004, 0.31)).r;
				float rays = smoothstep(0.5, 0.62, rn) * exp(-dist * 5.0) * smoothstep(0.02, 0.07, dist);
				glow += sun_color.rgb * rays * (0.05 + golden * 0.14);
			}
			col += glow * sv * day;
		} else {
			vec3 mc = mix(vec3(0.42, 0.48, 0.7), vec3(0.95, 0.22, 0.12), blood);
			col += mc * (pow(s, 60.0) * 0.45 + pow(s, 8.0) * 0.14 * blood) * night * (0.35 + 0.65 * phase_light) * sv;
			float halo = smoothstep(0.006, 0.0, abs(to_sun - 0.927)) * cirrus * 0.08 * (1.0 - overcast);
			col += vec3(0.6, 0.66, 0.9) * halo * night;
		}
	}

	// ---- Dust and haze: a dust storm browns the whole sky; fog and dust raise
	// the haze that melts the far ground into it.
	col = mix(col, mix(haze_col, vec3(0.74, 0.52, 0.33), 0.35), dust * (0.2 + 0.5 * exp(-up * 3.5)));
	if (use_fog_color) {
		col = mix(fog_color.rgb, col, smoothstep(-0.01, fog_band + haze * 0.3 + dust * 0.15, hy));
	}
	// The distant mesas: a painted strip just above the horizon, all the way round.
	if (use_art && use_mesa_strip && dir.y > -0.005 && dir.y < 0.16) {
		float az = atan(dir.x, dir.z) / 6.2832;
		vec4 mtex = textureLod(art_mesas, vec2(az * 3.0, 1.0 - (dir.y + 0.02) / 0.18), 0.0);
		float land = 1.0 - smoothstep(0.82, 0.9, dot(mtex.rgb, vec3(0.33)));
		vec3 hazed = mix(mtex.rgb * 0.82, haze_col, 0.32) * mix(1.0, 0.35, night);
		col = mix(col, hazed, land * 0.85 * smoothstep(-0.005, 0.035, dir.y));
	}
	COLOR = col;
}
