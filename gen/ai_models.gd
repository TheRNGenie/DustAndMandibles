class_name AiModels
extends RefCounted
## The AI-made models (assets/props, assets/fences, assets/airship: concept art by
## fal.ai z-image, turned 3D by fal.ai trellis, cut down by tools/props/prep_ai.py)
## with the game's look: the cel shading of the textured characters
## (toon_tex.gdshader) and the ink outline.

const TOON_TEX := preload("res://shaders/toon_tex.gdshader")

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}


static func exists(path: String) -> bool:
	return ResourceLoader.exists(path)


## The model's mesh (the first mesh in the GLB).
static func mesh(path: String) -> Mesh:
	if _meshes.has(path):
		return _meshes[path]
	var m: Mesh = null
	var packed := load(path) as PackedScene
	if packed != null:
		var root := packed.instantiate()
		var mis := root.find_children("*", "MeshInstance3D", true, false)
		if not mis.is_empty():
			m = (mis[0] as MeshInstance3D).mesh
		root.free()
	_meshes[path] = m
	return m


## A cel-shaded material with the model's own colour map and an outline
## `outline` thick (0 for none). Cached per model and thickness.
static func material(path: String, outline: float = 0.012, brightness: float = 1.08) -> ShaderMaterial:
	var key := "%s_%.3f_%.2f" % [path, outline, brightness]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = TOON_TEX
	m.set_shader_parameter("brightness", brightness)
	var src := mesh(path)
	if src != null and src.get_surface_count() > 0:
		var sm := src.surface_get_material(0) as BaseMaterial3D
		if sm != null and sm.albedo_texture != null:
			m.set_shader_parameter("albedo_tex", sm.albedo_texture)
	if outline > 0.0:
		m.next_pass = Materials.outline(outline)
	_mats[key] = m
	return m


## A ready MeshInstance3D of the model.
static func instance(path: String, outline: float = 0.012, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(path)
	mi.material_override = material(path, outline)
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
