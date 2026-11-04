class_name Materials
extends RefCounted
## Builds and caches the shared materials of the shader kit.

const TOON_SHADER: Shader = preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://shaders/outline.gdshader")
const TOON_GLIDE_SHADER: Shader = preload("res://shaders/toon_glide.gdshader")
const OUTLINE_GLIDE_SHADER: Shader = preload("res://shaders/outline_glide.gdshader")
const STRATA_SHADER: Shader = preload("res://shaders/cliff_strata.gdshader")
const STAR_SHADER: Shader = preload("res://shaders/vfx_star.gdshader")
const HOUSE_SHADER: Shader = preload("res://shaders/toon_house.gdshader")
## The homestead's painted wood, paint, shingle, stone and tin (AI-made with fal.ai,
## see assets/house/CREDITS.md; packing: shaders/toon_house.gdshader).
const HOUSE_DETAIL: Texture2D = preload("res://assets/house/house_detail.png")
const HOUSE_NRM_A: Texture2D = preload("res://assets/house/house_normal_a.png")
const HOUSE_NRM_B: Texture2D = preload("res://assets/house/house_normal_b.png")
const HOUSE_NRM_C: Texture2D = preload("res://assets/house/house_normal_c.png")
## Hand-painted terrain textures (AI-generated with fal.ai, see assets/terrain/CREDITS.md;
## how each is packed: shaders/cliff_strata.gdshader): rock and ground detail with
## their normal maps, and the infestation masks.
const ROCK_TEX: Texture2D = preload("res://assets/terrain/rock_detail.png")
const ROCK_NRM: Texture2D = preload("res://assets/terrain/rock_normal.png")
const GROUND_TEX: Texture2D = preload("res://assets/terrain/ground_detail.png")
const GROUND_NRM: Texture2D = preload("res://assets/terrain/ground_normal.png")
const RESIN_ATLAS: Texture2D = preload("res://assets/terrain/resin_atlas.png")
const RESIN_NRM: Texture2D = preload("res://assets/terrain/resin_normal.png")
const INFEST_MASK: Texture2D = preload("res://assets/terrain/infest_mask.png")
const MAX_HIVE_SPOTS := 12

static var _cache: Dictionary = {}
## Terrain texture detail (GraphicsQuality level: 0 Low, 1 Medium, 2 High) and the
## spots the infestation gathers round (tunnel mouths), applied to every strata material.
static var _terrain_detail := GraphicsQuality.HIGH
static var _hive_spots := PackedVector4Array()


## Toon material that reads colour from vertex colours, with an outline pass.
static func toon(outline_thickness: float = 0.03) -> ShaderMaterial:
	var key := "toon_%.3f" % outline_thickness
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("spec_strength", 0.14)
	if outline_thickness > 0.0:
		mat.next_pass = outline(outline_thickness)
	_cache[key] = mat
	return mat


## toon() for the bug MultiMesh batches (LegBatch): the same look, and every
## piece glides with its bug between updates (shaders/bug_glide.gdshaderinc).
static func toon_glide(outline_thickness: float = 0.03) -> ShaderMaterial:
	var key := "toon_glide_%.3f" % outline_thickness
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = TOON_GLIDE_SHADER
	mat.set_shader_parameter("spec_strength", 0.14)
	if outline_thickness > 0.0:
		var ol := ShaderMaterial.new()
		ol.shader = OUTLINE_GLIDE_SHADER
		ol.set_shader_parameter("thickness", outline_thickness)
		mat.next_pass = ol
	_cache[key] = mat
	return mat


## A unique toon material (not cached), for things that flash or change colour.
static func toon_unique(outline_thickness: float = 0.03) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("spec_strength", 0.14)
	if outline_thickness > 0.0:
		mat.next_pass = outline(outline_thickness)
	return mat


static func outline(thickness: float = 0.03) -> ShaderMaterial:
	var key := "outline_%.3f" % thickness
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter("thickness", thickness)
	_cache[key] = mat
	return mat


## Rock material for cliffs, canyon floor and mesas.
static func strata(top: Color = Palette.SAND) -> ShaderMaterial:
	var key := "strata_%s" % top.to_html()
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = STRATA_SHADER
	mat.set_shader_parameter("noise_tex", noise_texture(7, 0.02))
	mat.set_shader_parameter("top_color", top)
	mat.set_shader_parameter("rock_tex", ROCK_TEX)
	mat.set_shader_parameter("rock_nrm", ROCK_NRM)
	mat.set_shader_parameter("ground_tex", GROUND_TEX)
	mat.set_shader_parameter("ground_nrm", GROUND_NRM)
	mat.set_shader_parameter("resin_atlas", RESIN_ATLAS)
	mat.set_shader_parameter("resin_nrm", RESIN_NRM)
	mat.set_shader_parameter("infest_tex", INFEST_MASK)
	mat.set_shader_parameter("plateau_y", WorldLayout.CLIFF_HEIGHT)
	_apply_terrain(mat)
	_cache[key] = mat
	return mat


## The homestead's toon material (house, porch wings, workshop): vertex colours
## with painted wood grain, shingles, stone and tin by colour, and an outline.
static func toon_house(outline_thickness: float = 0.03) -> ShaderMaterial:
	var key := "house_%.3f" % outline_thickness
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = HOUSE_SHADER
	mat.set_shader_parameter("spec_strength", 0.14)
	mat.set_shader_parameter("house_detail", HOUSE_DETAIL)
	mat.set_shader_parameter("house_nrm_a", HOUSE_NRM_A)
	mat.set_shader_parameter("house_nrm_b", HOUSE_NRM_B)
	mat.set_shader_parameter("house_nrm_c", HOUSE_NRM_C)
	mat.set_shader_parameter("detail_level", _terrain_detail)
	if outline_thickness > 0.0:
		mat.next_pass = outline(outline_thickness)
	_cache[key] = mat
	return mat


## Every strata material in the cache (duplicates made from one included).
static func _strata_materials() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for m: Variant in _cache.values():
		if m is ShaderMaterial and (m as ShaderMaterial).shader == STRATA_SHADER:
			out.append(m)
	return out


static func _apply_terrain(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("detail_level", _terrain_detail)
	var spots: Array[Vector4] = []
	for i in MAX_HIVE_SPOTS:
		spots.append(_hive_spots[i] if i < _hive_spots.size() else Vector4.ZERO)
	mat.set_shader_parameter("hive_spots", spots)
	mat.set_shader_parameter("hive_count", mini(_hive_spots.size(), MAX_HIVE_SPOTS))


## Terrain texture detail from the Effects setting: Low draws the infestation only.
static func set_terrain_detail(level: int) -> void:
	_terrain_detail = GraphicsQuality.level(level)
	for mat in _strata_materials():
		_apply_terrain(mat)
	for m: Variant in _cache.values():
		if m is ShaderMaterial and (m as ShaderMaterial).shader == HOUSE_SHADER:
			(m as ShaderMaterial).set_shader_parameter("detail_level", _terrain_detail)


## Where the infestation is thickest (x, y, z, radius), e.g. the bug tunnel mouths.
## Call after the terrain is built (map materials are duplicated from the cache).
static func set_hive_spots(spots: PackedVector4Array) -> void:
	_hive_spots = spots
	for mat in _strata_materials():
		_apply_terrain(mat)


static func star(tint: Color, brightness: float = 2.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = STAR_SHADER
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("brightness", brightness)
	return mat


## Seamless noise texture generated by the engine (no image files).
static func noise_texture(seed_value: int, frequency: float, size: int = 256) -> NoiseTexture2D:
	var key := "noise_%d_%.4f_%d" % [seed_value, frequency, size]
	if _cache.has(key):
		return _cache[key]
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = size
	tex.height = size
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.noise = noise
	_cache[key] = tex
	return tex
