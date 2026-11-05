// The toon surface (uniforms, fragment, light): shared by toon.gdshader and
// toon_glide.gdshader (the same look on bug MultiMesh batches, with glide).

#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = true;
uniform float emission_strength : hint_range(0.0, 8.0) = 2.5;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
// Punchier colour: pushes vertex colours away from grey.
uniform float saturation : hint_range(0.0, 2.0) = 1.18;
// Optional painted detail (assets/skins, AI-made with fal.ai), projected in the
// mesh's own space and picked by vertex colour. paint_mode 0 = off (every prop,
// building and weapon), 1 = bug skin (paint_tex: R chitin plates, G spider hair,
// B queen filigree, A brood-mother hide; paint_skin 1 queen / 2 mother), 2 =
// cloth (paint_tex: R denim, G leather, B felt, A cotton). Glowing parts (vertex
// alpha < 1: weak spots, eyes) are never painted.
uniform sampler2D paint_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform int paint_mode = 0;
uniform int paint_skin = 0;
uniform float paint_tile = 0.6;
uniform float paint_strength : hint_range(0.0, 1.5) = 0.7;
varying vec3 paint_pos;
varying vec3 paint_nrm;

vec3 paint_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 toon_paint(vec3 c, vec3 vcol, float glow) {
	if (paint_mode == 0 || glow > 0.01) {
		return c;
	}
	vec3 hsv = paint_hsv(pow(clamp(vcol, 0.0, 1.0), vec3(1.0 / 2.2)));
	float hue = hsv.x * 360.0;
	int ch = 0; // channel 0..3, -1 none
	if (paint_mode == 1) {
		if (hsv.z < 0.08 || (hsv.y < 0.12 && hsv.z > 0.85)) {
			ch = -1; // eyes, teeth, highlights
		} else if (paint_skin == 1) {
			ch = 2;
		} else if (paint_skin == 2) {
			ch = 3;
		} else if (hue > 255.0 && hue < 335.0 && hsv.y > 0.15) {
			ch = 1; // spider plums: hairy
		}
	} else {
		if (hue > 15.0 && hue < 42.0 && hsv.y > 0.18 && hsv.y < 0.62 && hsv.z > 0.7) {
			ch = -1; // skin
		} else if (hue > 190.0 && hue < 250.0 && hsv.y > 0.2) {
			ch = 0; // denim
		} else if (hue > 10.0 && hue < 45.0 && hsv.y > 0.35 && hsv.z < 0.7) {
			ch = 1; // leather
		} else if (hsv.y < 0.25 && hsv.z < 0.45) {
			ch = 2; // felt (dark hats, waistcoats)
		} else {
			ch = 3; // cotton
		}
	}
	if (ch < 0) {
		return c;
	}
	vec3 n = normalize(paint_nrm);
	vec3 a = abs(n);
	vec3 q = paint_pos / paint_tile;
	vec2 uv = (a.y >= a.x && a.y >= a.z) ? q.xz : ((a.x >= a.z) ? q.zy : q.xy);
	if (paint_mode == 1 && ch == 1) {
		uv *= 0.8; // the bristle tufts a little bigger than the chitin plates
	}
	vec4 t = texture(paint_tex, uv);
	float l = ch == 0 ? t.r : (ch == 1 ? t.g : (ch == 2 ? t.b : t.a));
	// Bristles, filigree and hide are fine and low-contrast: pushed harder, with
	// their dark strokes inked, so they read at playing distance.
	float st = paint_strength * ((paint_mode == 1 && ch >= 1) ? 1.7 : 1.0);
	float ink_at = (paint_mode == 1 && ch >= 1) ? 0.3 : 0.12;
	if (paint_mode == 1 && paint_skin == 1) {
		// The Hive Queen: her dark brown lifted to warm gilt, the filigree's
		// raised scrolls bright gold and its grooves inked, so it reads on the wall.
		float lum = dot(c, vec3(0.299, 0.587, 0.114));
		vec3 gilt = mix(vec3(0.55, 0.30, 0.06), vec3(1.0, 0.78, 0.22), smoothstep(0.35, 0.75, l));
		c = mix(c, gilt * (0.85 + lum * 0.5), 0.8);
		c = mix(c, vec3(0.169, 0.106, 0.090), smoothstep(0.32, 0.18, l) * 0.6);
		return c;
	}
	c *= max(1.0 + (l * 2.0 - 1.0) * st, 0.3);
	c = mix(c, vec3(0.169, 0.106, 0.090), smoothstep(ink_at, ink_at - 0.12, l) * min(0.4 * st, 0.75));
	return c;
}

void fragment() {
	vec3 c = albedo.rgb;
	float glow = 0.0;
	if (use_vertex_color) {
		c *= COLOR.rgb;
		glow = 1.0 - COLOR.a;
	}
	c = toon_paint(c, COLOR.rgb, glow);
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	c = clamp(mix(vec3(grey), c, saturation), 0.0, 1.0);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	EMISSION = c * glow * emission_strength + flash_color.rgb * flash_amount;
}
