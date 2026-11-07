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
## The airship deck's set in the same layout: deck planks, wood, canvas, brass.
const DECK_SET := ["res://assets/airship/deck/deck_detail.png", "res://assets/airship/deck/deck_normal_a.png",
		"res://assets/airship/deck/deck_normal_b.png", "res://assets/airship/deck/deck_normal_c.png"]
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
const MAX_HIVE_SPOTS := 24

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


## `mat` without its outline pass (cached, so the Effects setting still reaches
## it): for a node that draws the outline from a second, shadowless node.
static func without_outline(mat: ShaderMaterial) -> ShaderMaterial:
	var key := "noout_%d" % mat.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var bare := mat.duplicate() as ShaderMaterial
	bare.next_pass = null
	_cache[key] = bare
	return bare


## toon() for the bug MultiMesh batches (LegBatch): the same look, and every
## piece glides with its bug between updates (shaders/bug_glide.gdshaderinc).
static func toon_glide(outline_thickness: float = 0.03) -> ShaderMaterial:
	var key := "toon_glide_%.3f" % outline_thickness
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = TOON_GLIDE_SHADER
	mat.set_shader_parameter("spec_strength", 0.14)
	_paint(mat, 1, 0, 0.6)
	if outline_thickness > 0.0:
		var ol := ShaderMaterial.new()
		ol.shader = OUTLINE_GLIDE_SHADER
		ol.set_shader_parameter("thickness", outline_thickness)
		mat.next_pass = ol
	_cache[key] = mat
	return mat


## toon_glide() with a boss's own skin (1 the Hive Queen's gilded filigree,
## 2 the Hive Mother's veined hide), painted at a boss's scale.
static func toon_glide_skin(outline_thickness: float, skin: int) -> ShaderMaterial:
	var key := "toon_glide_skin%d_%.3f" % [skin, outline_thickness]
	if _cache.has(key):
		return _cache[key]
	var mat := toon_glide(outline_thickness).duplicate() as ShaderMaterial
	if outline_thickness > 0.0:
		mat.next_pass = toon_glide(outline_thickness).next_pass
	_paint(mat, 1, skin, 1.4)
	mat.set_shader_parameter("paint_strength", 0.75)
	_cache[key] = mat
	return mat


const BUG_SKIN: Texture2D = preload("res://assets/skins/bug_detail.png")
const CLOTH: Texture2D = preload("res://assets/skins/cloth_detail.png")


## Painted detail on a toon material (toon_surface.gdshaderinc): mode 1 bug
## skin, 2 cloth. Off on Low effects.
static func _paint(mat: ShaderMaterial, mode: int, skin: int = 0, tile: float = 0.6) -> void:
	mat.set_meta(&"paint_mode", mode)
	mat.set_shader_parameter("paint_tex", BUG_SKIN if mode == 1 else CLOTH)
	mat.set_shader_parameter("paint_mode", mode if _terrain_detail > 0 else 0)
	mat.set_shader_parameter("paint_skin", skin)
	mat.set_shader_parameter("paint_tile", tile)
	mat.set_shader_parameter("paint_strength", 0.65 if mode == 1 else 0.5)


## Cloth textures (denim, leather, felt, cotton by colour) on a cowboy's material.
static func cloth(mat: ShaderMaterial) -> ShaderMaterial:
	_paint(mat, 2, 0, 0.3)
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
	mat.set_shader_parameter("kind_map", PackedInt32Array([0, 1, 2, 3, 4, 5, 0, 0]))
	if outline_thickness > 0.0:
		mat.next_pass = outline(outline_thickness)
	_cache[key] = mat
	return mat


## toon_house() with the airship deck's paintings: planks on the browns, canvas
## on the reds (the canopy, both sides), riveted brass on the greys.
static func toon_deck(outline_thickness: float = 0.03) -> ShaderMaterial:
	var key := "deck_%.3f" % outline_thickness
	if _cache.has(key):
		return _cache[key]
	var mat := toon_house(outline_thickness).duplicate() as ShaderMaterial
	if outline_thickness > 0.0:
		mat.next_pass = outline(outline_thickness)
	for i in 4:
		mat.set_shader_parameter(["house_detail", "house_nrm_a", "house_nrm_b", "house_nrm_c"][i], load(DECK_SET[i]))
	mat.set_shader_parameter("red_sides_wood", false)
	mat.set_shader_parameter("tile", 2.6)
	mat.set_shader_parameter("bump", 0.55)
	# The canopy is smooth canvas: no bump or painted pattern on the reds.
	mat.set_shader_parameter("red_bump", 0.0)
	mat.set_shader_parameter("red_strength", 0.0)
	_cache[key] = mat
	return mat


## The painted toon look on any builder mesh: `set_dir` holds a texture set packed
## like assets/house (detail, normal_a/b/c; e.g. assets/rustic: wood, paint, cave
## rock, stone, rusty iron) and `kind_map` says which painting each vertex-colour
## class gets (see toon_house.gdshader). Cached per set, map and outline.
const RUSTIC := "res://assets/rustic/rustic"
static func toon_painted(set_prefix: String, kind_map: Array, outline_thickness: float = 0.03, tile: float = 2.2) -> ShaderMaterial:
	var key := "painted_%s_%s_%.3f_%.2f" % [set_prefix, str(kind_map), outline_thickness, tile]
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = HOUSE_SHADER
	mat.set_shader_parameter("spec_strength", 0.14)
	mat.set_shader_parameter("house_detail", load(set_prefix + "_detail.png"))
	mat.set_shader_parameter("house_nrm_a", load(set_prefix + "_normal_a.png"))
	mat.set_shader_parameter("house_nrm_b", load(set_prefix + "_normal_b.png"))
	mat.set_shader_parameter("house_nrm_c", load(set_prefix + "_normal_c.png"))
	mat.set_shader_parameter("detail_level", _terrain_detail)
	mat.set_shader_parameter("kind_map", PackedInt32Array(kind_map))
	mat.set_shader_parameter("tile", tile)
	if outline_thickness > 0.0:
		mat.next_pass = outline(outline_thickness)
	_cache[key] = mat
	return mat


## Swaps the shared plain toon materials under `root` for toon_painted ones
## (leaves unique ones that flash, glow or change colour alone). Visual only.
static func paint_subtree(root: Node, set_prefix: String, kind_map: Array, tile: float = 2.2) -> void:
	if root == null or not ResourceLoader.exists(set_prefix + "_detail.png"):
		return
	var swapped := {}
	var nodes: Array = root.find_children("*", "GeometryInstance3D", true, false)
	if root is GeometryInstance3D:
		nodes.append(root)
	for n: Node in nodes:
		var gi := n as GeometryInstance3D
		var m := gi.material_override as ShaderMaterial
		if m == null or m.shader != TOON_SHADER:
			continue
		if not swapped.has(m):
			var t := 0.0
			if m.next_pass is ShaderMaterial:
				t = float((m.next_pass as ShaderMaterial).get_shader_parameter("thickness"))
			swapped[m] = toon_painted(set_prefix, kind_map, t, tile) if toon(t) == m else null
		if swapped[m] != null:
			gi.material_override = swapped[m]


## Kind maps for toon_painted (see toon_house.gdshader's kind_map).
const MAP_TRAIN := [0, 1, 2, 1, 1, 5, 5, 5]    # reds as planks, every grey and dark as rusty iron
const MAP_MINE := [0, 1, 2, 3, 3, 5, 3, 3]     # dark rock and reds as cave rock, greys as iron
const MAP_YARD := [0, 1, 2, 1, 4, 5, 0, 5]     # greys and darks iron, earthy soil left plain
const MAP_TIMBER := [0, 1, 2, 1, 1, 5, 1, 5]   # all wood, iron fittings
const MAP_RUINS := [0, 1, 2, 1, 4, 5, 1, 5]

static var _live: Array = [] # [root, set_prefix, kind_map]
static var _pending: Array = []


## paint_subtree now (next frame) and again for anything later built under `root`
## (cars, upgrade parts, story stages swap their meshes in as they go).
static func paint_live(root: Node, set_prefix: String, kind_map: Array) -> void:
	if root == null or not ResourceLoader.exists(set_prefix + "_detail.png"):
		return
	var tree := root.get_tree() if root.is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_live = _live.filter(func(e: Array) -> bool: return is_instance_valid(e[0]))
	_live.append([root, set_prefix, kind_map])
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	_queue(root)


static func _on_node_added(n: Node) -> void:
	if not (n is GeometryInstance3D):
		return
	# Only what's built under a live root (not every tracer and damage number);
	# once the roots are all gone, stop listening.
	var any := false
	for e: Array in _live:
		if not is_instance_valid(e[0]):
			continue
		var root := e[0] as Node
		any = true
		if root == n or root.is_ancestor_of(n):
			_queue(n)
			return
	if not any:
		_live.clear()
		var tree := n.get_tree()
		if tree != null and tree.node_added.is_connected(_on_node_added):
			tree.node_added.disconnect(_on_node_added)


static func _queue(n: Node) -> void:
	if _pending.is_empty():
		var tree := Engine.get_main_loop() as SceneTree
		tree.process_frame.connect(_flush, CONNECT_ONE_SHOT)
	_pending.append(n)


static func _flush() -> void:
	var batch := _pending.duplicate()
	_pending.clear()
	for v: Variant in batch:
		if not is_instance_valid(v):
			continue
		var n := v as Node
		for e: Array in _live:
			if not is_instance_valid(e[0]):
				continue
			var root := e[0] as Node
			if root == n or root.is_ancestor_of(n):
				paint_subtree(n, e[1], e[2])
				break


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
		if m is ShaderMaterial and (m as ShaderMaterial).has_meta(&"paint_mode"):
			(m as ShaderMaterial).set_shader_parameter("paint_mode", int((m as ShaderMaterial).get_meta(&"paint_mode")) if _terrain_detail > 0 else 0)
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
