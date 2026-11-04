// The homestead's toon material: the plain toon surface (vertex colours, cel
// light, outline pass from Materials) plus hand-painted detail (assets/house,
// AI-made with fal.ai) projected in the house's own space, so every board, log
// and shingle the builder makes gets grain without UVs. Which painting a pixel
// gets comes from its vertex colour: browns are wood planks, the East house's
// pale blue paint is chipped clapboard, the roof red is shingles on top and
// fieldstone on the chimney and skirt (wood trim on gables and roof edges),
// the tin and iron greys are
// corrugated tin. Anything else (team colours, glass, flowers) stays plain.
// house_detail: R wood, G paint, B shingle, A stone (luminance, 0.5 = average);
// house_nrm_a: RG wood, BA paint; house_nrm_b: RG shingle, BA stone;
// house_nrm_c: RG tin, B tin luminance.
// detail_level (Materials.set_terrain_detail): 0 plain, 1 painted, 2 + normals.
shader_type spatial;
render_mode cull_back;

#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform float saturation : hint_range(0.0, 2.0) = 1.18;
uniform sampler2D house_detail : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D house_nrm_a : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D house_nrm_b : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D house_nrm_c : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform int detail_level = 2;
uniform float tile = 2.2;          // metres per painted tile
uniform float strength : hint_range(0.0, 1.5) = 0.85;
uniform float bump : hint_range(0.0, 2.0) = 0.9;
uniform vec2 chimney_xz = vec2(2.1, 0.825); // HouseBuilder: W * 0.3, D * 0.15
// The airship deck uses this shader with its own paintings (Materials.toon_deck):
// there every red that isn't facing up is canvas (the canopy's underside).
uniform bool red_sides_wood = true;
// How much the reds (shingles/stone on the house, canvas on the deck) bump and
// vary: the deck's canopy wants smooth cloth, not crumpled foil.
uniform float red_bump = 1.0;
uniform float red_strength = 1.0;
uniform vec4 ink : source_color = vec4(0.169, 0.106, 0.090, 1.0);

varying vec3 obj_pos;
varying vec3 obj_nrm;

void vertex() {
	obj_pos = VERTEX;
	obj_nrm = NORMAL;
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

void fragment() {
	vec3 c = albedo.rgb * COLOR.rgb;
	float glow = 1.0 - COLOR.a;
	// The builder's colours are sRGB; COLOR arrives linear.
	vec3 hsv = rgb2hsv(pow(clamp(COLOR.rgb, 0.0, 1.0), vec3(1.0 / 2.2)));
	vec3 n = normalize(obj_nrm);
	vec3 an = abs(n);
	// 0 none, 1 wood, 2 paint, 3 shingle, 4 stone, 5 tin
	int kind = 0;
	float hue = hsv.x * 360.0;
	if (hsv.y < 0.2 && hsv.z > 0.3 && hsv.z < 0.72) {
		kind = 5;
	} else if (hue > 170.0 && hue < 215.0 && hsv.y < 0.3 && hsv.z > 0.5) {
		kind = 2;
	} else if (hue > 14.0 && hue < 40.0 && hsv.y > 0.35 && hsv.z > 0.25 && hsv.z < 0.62) {
		kind = 1;
	} else if ((hue < 14.0 || hue > 350.0) && hsv.y > 0.5 && hsv.z > 0.45 && hsv.z < 0.74) {
		// Up-facing roof red is shingles; on the sides only the stone skirt (low
		// down) and the chimney are stone, the gable and roof edges are wood trim.
		bool chimney = abs(obj_pos.x - chimney_xz.x) < 0.45 && abs(obj_pos.z - chimney_xz.y) < 0.45;
		kind = n.y > 0.35 ? 3 : ((obj_pos.y < 0.75 || chimney || !red_sides_wood) ? 4 : 1);
	}
	vec3 tilt = vec3(0.0);
	if (detail_level >= 1 && kind > 0 && glow < 0.01) {
		// Dominant-axis projection in the house's space; walls run v downward.
		vec3 q = obj_pos / tile;
		vec2 uv;
		int axis;
		if (an.y >= an.x && an.y >= an.z) {
			uv = q.xz; axis = 1;
		} else if (an.x >= an.z) {
			uv = vec2(q.z * sign(n.x), -q.y); axis = 0;
		} else {
			uv = vec2(-q.x * sign(n.z), -q.y); axis = 2;
		}
		vec4 d = texture(house_detail, uv);
		float l = kind == 1 ? d.r : (kind == 2 ? d.g : (kind == 3 ? d.b : (kind == 4 ? d.a : texture(house_nrm_c, uv).b)));
		float st = (kind == 3 || kind == 4) ? strength * red_strength : strength;
		c *= max(1.0 + (l * 2.0 - 1.0) * st, 0.3);
		c = mix(c, ink.rgb, smoothstep(0.14, 0.06, l) * 0.5 * st);
		if (detail_level >= 2) {
			vec2 m;
			if (kind <= 2) {
				vec4 t = texture(house_nrm_a, uv); m = kind == 1 ? t.rg : t.ba;
			} else if (kind <= 4) {
				vec4 t = texture(house_nrm_b, uv); m = kind == 3 ? t.rg : t.ba;
			} else {
				m = texture(house_nrm_c, uv).rg;
			}
			m = (m * 2.0 - 1.0) * bump * ((kind == 3 || kind == 4) ? red_bump : 1.0);
			float sx = n.x < 0.0 ? -1.0 : 1.0;
			float sz = n.z < 0.0 ? -1.0 : 1.0;
			tilt = axis == 1 ? vec3(m.x, 0.0, -m.y) : (axis == 0 ? vec3(0.0, m.y, sx * m.x) : vec3(-sz * m.x, m.y, 0.0));
		}
	}
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	c = clamp(mix(vec3(grey), c, saturation), 0.0, 1.0);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	EMISSION = c * glow * 2.5;
	// (Flat reds with no bump keep the mesh's own smooth normal: the canopy reads as soft cloth.)
	if (detail_level >= 2 && kind > 0 && !((kind == 3 || kind == 4) && red_bump <= 0.0)) {
		vec3 bent = normalize(n + tilt);
		NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(bent, 0.0)).xyz);
	}
}
