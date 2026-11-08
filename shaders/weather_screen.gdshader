// The weather over the whole view (WeatherFx.WeatherScreen, under the HUD):
// heat shimmer bending the lower half of the view, sand-brown grit streaming
// across in a dust storm with a dusty vignette, a cold grey edge in a storm,
// and the white-out of a close lightning flash. Only drawn while one is on.
shader_type canvas_item;

uniform float dust = 0.0;
uniform float heat = 0.0;
uniform float storm = 0.0;
uniform float flash = 0.0;
uniform float wind = 1.0;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	// Heat: the air over the ground wavers (strongest low in the view).
	vec2 off = vec2(0.0);
	if (heat > 0.0) {
		float low = smoothstep(0.42, 0.8, uv.y);
		vec2 q = uv * aspect * vec2(46.0, 90.0);
		off = vec2(vnoise(q + vec2(0.0, TIME * 2.4)) - 0.5, vnoise(q * 0.8 - vec2(TIME * 1.7, 0.0)) - 0.5) * 0.0055 * heat * low;
	}
	vec3 col = texture(screen, uv + off).rgb;
	float edge = smoothstep(0.35, 0.95, length((uv - 0.5) * vec2(1.6, 1.2)));
	// Dust: a sandy wash, darker at the edges, and grit streaking across.
	if (dust > 0.0) {
		vec3 sand = vec3(0.78, 0.58, 0.38);
		// Banks of dust blowing through the view, thicker and thinner.
		vec2 bq = uv * aspect * vec2(1.8, 3.2) + vec2(-wind * TIME * 0.7, TIME * 0.04);
		float bank = smoothstep(0.3, 0.85, vnoise(bq) * 0.6 + vnoise(bq * 2.3 + 7.0) * 0.4);
		col = mix(col, sand * 0.86, dust * (0.08 + 0.26 * edge + 0.24 * bank));
		vec2 g = uv * aspect * vec2(3.0, 60.0) + vec2(-wind * TIME * 9.0, 0.0);
		float streak = smoothstep(0.82, 0.97, vnoise(g)) * smoothstep(0.55, 0.9, vnoise(uv * aspect * vec2(1.5, 6.0) + vec2(-wind * TIME * 2.0, TIME * 0.3)));
		col = mix(col, sand * 1.1, streak * dust * 0.55);
	}
	// A storm's cold, darker edge.
	if (storm > 0.0) {
		col = mix(col, col * vec3(0.72, 0.78, 0.9), storm * edge * 0.55);
	}
	// A close strike whites the view out for a moment.
	col = mix(col, vec3(0.95, 0.97, 1.0), clamp(flash, 0.0, 1.0) * 0.8);
	COLOR = vec4(col, 1.0);
}
