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
## `outline` thick (0 for none), optionally lightened, tinted and toned down
## (saturation). Cached per model and look.
static func material(path: String, outline: float = 0.012, brightness: float = 1.08,
		tint: Color = Color.WHITE, saturation: float = 1.12, matte: float = 0.0) -> ShaderMaterial:
	var key := "%s_%.3f_%.2f_%s_%.2f_%.2f" % [path, outline, brightness, tint.to_html(), saturation, matte]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = TOON_TEX
	m.set_shader_parameter("brightness", brightness)
	m.set_shader_parameter("albedo", tint)
	m.set_shader_parameter("saturation", saturation)
	if matte > 0.0:
		m.set_shader_parameter("matte", matte)
		m.set_shader_parameter("rim_strength", 0.3) # no glossy rim on the shiny-looking models
	var src := mesh(path)
	if src != null and src.get_surface_count() > 0:
		var sm := src.surface_get_material(0) as BaseMaterial3D
		if sm != null and sm.albedo_texture != null:
			m.set_shader_parameter("albedo_tex", sm.albedo_texture)
	if outline > 0.0:
		m.next_pass = Materials.outline(outline)
	_mats[key] = m
	return m


## Puts the model in place of a builder mesh, visually only: sized to the mesh's
## bounds (`mode` "length": one scale from the length along z; "height": from
## the height; "fit": stretched to all three), standing on its bottom and centred,
## as a sibling with the same transform (so it moves, tilts and hides with the
## same parent); the builder mesh is hidden. Collision and logic stay as they are.
## Null (and nothing changed) when the model is missing.
## `box` (non-zero size) fits the model to that box instead of the mesh's bounds,
## and `keep` leaves the builder mesh showing (the model is added beside it).
static func stand_in(mi: MeshInstance3D, path: String, outline: float = 0.02, mode: String = "length",
		box: AABB = AABB(), keep: bool = false) -> MeshInstance3D:
	if mi == null or mi.mesh == null or mi.get_parent() == null or not exists(path):
		return null
	var src := mesh(path)
	if src == null:
		return null
	var t := box if box.size != Vector3.ZERO else mi.mesh.get_aabb()
	var a := src.get_aabb()
	var sc := Vector3.ONE * (t.size.z / maxf(a.size.z, 0.001))
	if mode == "height":
		sc = Vector3.ONE * (t.size.y / maxf(a.size.y, 0.001))
	elif mode == "fit":
		sc = t.size / a.size.max(Vector3.ONE * 0.001)
	var tb := t.get_center()
	tb.y = t.position.y
	var ab := a.get_center()
	ab.y = a.position.y
	var ai := instance(path, outline)
	if path.contains("/train/"):
		ai.material_override = material(path, outline, 1.12, Color.WHITE, 1.05, 1.0) # matte paint
	ai.name = String(mi.name) + "AI"
	ai.layers = mi.layers
	ai.cast_shadow = mi.cast_shadow
	ai.transform = mi.transform * Transform3D(Basis.from_scale(sc), tb - ab * sc)
	mi.get_parent().add_child(ai)
	mi.visible = keep
	return ai


## A ready MeshInstance3D of the model.
static func instance(path: String, outline: float = 0.012, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(path)
	mi.material_override = material(path, outline)
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
