// Weather on every surface (WeatherFx sets the globals, 0..1, easing in and
// out): rain darkens and deepens everything, most on what faces the sky; snow
// settles white on upward faces; dust powders the world sandy. Called on the
// albedo with the world-space normal.
global uniform float weather_wet;
global uniform float weather_snow;
global uniform float weather_dust;

vec3 weather_tint(vec3 c, vec3 world_n) {
	float up = clamp(world_n.y, 0.0, 1.0);
	if (weather_wet > 0.001) {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		vec3 wet = mix(vec3(l), c, 1.2) * vec3(0.5, 0.52, 0.56);
		c = mix(c, max(wet, vec3(0.0)), weather_wet * (0.5 + 0.5 * up));
	}
	if (weather_snow > 0.001) {
		c = mix(c, vec3(0.9, 0.93, 0.98), weather_snow * smoothstep(0.42, 0.8, up));
	}
	if (weather_dust > 0.001) {
		c = mix(c, vec3(0.8, 0.62, 0.42), weather_dust * (0.12 + 0.3 * up));
	}
	return c;
}
