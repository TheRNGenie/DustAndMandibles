// Toon ramp shader for textured models (the Meshy characters): same lighting as
// toon.gdshader, colour from the model's texture instead of vertex colours.
shader_type spatial;
render_mode cull_back;

#include "res://shaders/toon_light.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.12;
uniform float brightness : hint_range(0.5, 2.0) = 1.08;
// Matte: the AI models' textures carry baked-in shine (white streaks on dark
// paint); 1 caps those highlights and evens out the paint so it reads like the
// game's flat cel colours.
uniform float matte : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo.rgb * brightness;
	if (matte > 0.0) {
		// The paint's own colour from a much blurrier mip; the shine (anything
		// brighter than that) is pressed back down to it.
		vec3 base = textureLod(albedo_tex, UV, 6.0).rgb * albedo.rgb * brightness;
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		float lb = dot(base, vec3(0.299, 0.587, 0.114));
		float over = max(l - lb * 1.05, 0.0);
		c = mix(c, c * (l - over * 0.95) / max(l, 0.001), matte);
		c = mix(c, base, 0.3 * matte);
	}
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	c = clamp(mix(vec3(grey), c, saturation), 0.0, 1.0);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	EMISSION = flash_color.rgb * flash_amount;
}
