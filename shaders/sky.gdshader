// Stylised gradient sky: a hard-edged sun with a warm halo that spreads along
// the horizon at golden hour, flat cartoon clouds, and at night a starry sky
// with a faint dust band and a cratered moon (the sun light doubles as the moon).
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
// 0 by day, 1 at full night (stars, moon instead of sun).
uniform float night : hint_range(0.0, 1.0) = 0.0;
// 0..1: how strongly the low sun floods the horizon with colour (golden hour).
uniform float golden : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.55, 0.25, 1.0);
// Storms hide the stars.
uniform float overcast : hint_range(0.0, 1.0) = 0.0;

float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
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

// The Milky Way: a patchy band of starlight with a dark dust lane down it.
float milky(vec3 dir, out float lane) {
	vec3 bn = normalize(vec3(0.62, 0.38, -0.69));
	float off = dot(dir, bn);
	vec3 a = normalize(cross(bn, vec3(0.0, 1.0, 0.0)));
	vec3 b = cross(bn, a);
	vec2 uv = vec2(dot(dir, a), dot(dir, b));
	float n1 = texture(cloud_noise, uv * 0.9 + vec2(0.31, 0.17)).r;
	float n2 = texture(cloud_noise, uv * 2.7 + vec2(0.6, 0.4)).r;
	float clumps = clamp(n1 * 0.7 + n2 * 0.5 - 0.35, 0.0, 1.0);
	float width = 0.16 + (n1 - 0.5) * 0.1;
	float band = 1.0 - smoothstep(0.0, width, abs(off));
	lane = (1.0 - smoothstep(0.0, 0.035 + n2 * 0.03, abs(off + (n1 - 0.5) * 0.06))) * band;
	return band * (0.35 + clumps);
}

void sky() {
	vec3 dir = EYEDIR;
	float up = clamp(dir.y, 0.0, 1.0);
	float t = smoothstep(0.0, 0.55, up);
	if (bands > 0.0) {
		t = floor(t * bands) / bands;
	}
	vec3 col = mix(horizon_color.rgb, top_color.rgb, t);
	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0, 1.0, 0.0);
	float to_sun = dot(dir, sun_dir);
	// Golden hour: the horizon toward the sun flares orange-pink in soft bands.
	if (golden > 0.0 && dir.y > -0.05) {
		float facing = clamp(dot(normalize(dir.xz + 1e-4), normalize(sun_dir.xz + 1e-4)) * 0.5 + 0.5, 0.0, 1.0);
		float low = 1.0 - smoothstep(0.0, 0.35, up);
		float flare = pow(facing, 3.0) * low;
		flare = floor(flare * 4.0 + 0.5) / 4.0; // toon bands
		col = mix(col, glow_color.rgb, flare * golden * 0.8);
		// A pink-violet band higher up, away from the sun.
		float belt = smoothstep(0.08, 0.2, up) * (1.0 - smoothstep(0.2, 0.42, up)) * (1.0 - facing);
		col = mix(col, vec3(0.82, 0.5, 0.66), belt * golden * 0.35);
	}
	if (dir.y < 0.0) {
		col = mix(horizon_color.rgb, ground_color.rgb, smoothstep(0.0, 0.15, -dir.y));
	}
	// Night: stars and the Milky Way.
	if (night > 0.0 && dir.y > 0.0) {
		float fade = night * (1.0 - overcast) * smoothstep(0.0, 0.25, dir.y);
		float lane;
		float mw = milky(dir, lane);
		col += vec3(0.32, 0.34, 0.55) * mw * fade * 0.42;
		col = mix(col, col * 0.7, lane * fade * 0.6);
		col += stars(dir) * fade * (1.0 + mw * 0.8) * (1.0 - lane * 0.7);
	}
	// Flat, hard-edged cartoon clouds.
	if (dir.y > 0.02) {
		vec2 uv = dir.xz / (dir.y + 0.25) * 0.15 + vec2(TIME * 0.002, 0.0);
		float c = texture(cloud_noise, uv).r;
		float mask = smoothstep(1.0 - cloud_amount, 1.0 - cloud_amount + 0.02, c);
		mask *= smoothstep(0.02, 0.2, dir.y);
		// Clouds near the low sun get a hot rim.
		float rim = smoothstep(1.0 - cloud_amount + 0.02, 1.0 - cloud_amount + 0.06, c);
		vec3 cc = mix(cloud_color.rgb + glow_color.rgb * golden * 0.35 * smoothstep(0.5, 1.0, to_sun), cloud_color.rgb, rim);
		col = mix(col, cc, mask * 0.9 * (1.0 - night * 0.4));
	}
	if (LIGHT0_ENABLED) {
		if (night < 0.5) {
			// Sun: hard disk, a toon halo ring, and a wide soft glow (bigger when low).
			float halo = smoothstep(1.0 - sun_size * 4.0, 1.0 - sun_size * 3.4, to_sun) * 0.12;
			float wide = pow(max(to_sun, 0.0), 64.0) * (0.15 + golden * 0.5) + pow(max(to_sun, 0.0), 8.0) * golden * 0.25;
			col += sun_color.rgb * (halo + wide) * (1.0 - night * 2.0);
			float disk = smoothstep(1.0 - sun_size, 1.0 - sun_size * 0.8, to_sun);
			col = mix(col, sun_color.rgb * 2.0, disk);
		} else {
			// Moon: a bigger pale disk with darker maria, and a cool glow.
			float msize = sun_size * 2.2;
			float disk = smoothstep(1.0 - msize, 1.0 - msize * 0.9, to_sun);
			vec3 side = normalize(cross(sun_dir, vec3(0.0, 1.0, 0.0)) + 1e-4);
			vec3 upv = cross(side, sun_dir);
			vec2 m = vec2(dot(dir, side), dot(dir, upv)) / sqrt(msize * 2.0);
			float maria = smoothstep(0.32, 0.25, length(m - vec2(0.25, 0.2))) + smoothstep(0.22, 0.15, length(m - vec2(-0.3, -0.1)))
				+ smoothstep(0.15, 0.1, length(m - vec2(0.1, -0.4)));
			vec3 moon = mix(vec3(1.0, 0.97, 0.88), vec3(0.62, 0.64, 0.74), clamp(maria, 0.0, 1.0)) * 1.05;
			// Toon terminator: a darker crescent band on the side away from the horizon glow.
			moon *= mix(1.0, 0.82, smoothstep(0.35, 0.5, dot(m, vec2(-0.7, -0.7))));
			col += vec3(0.4, 0.45, 0.65) * pow(max(to_sun, 0.0), 60.0) * 0.5 * night;
			// A toon halo ring round the moon.
			float ring = smoothstep(1.0 - msize * 2.4, 1.0 - msize * 2.15, to_sun) * 0.06 * night * (1.0 - overcast);
			col += vec3(0.55, 0.6, 0.85) * ring;
			col = mix(col, moon, disk * (1.0 - overcast * 0.7));
		}
	}
	COLOR = col;
}
