class_name GunModels
extends RefCounted
## The Meshy guns and held items (assets/rigged/guns/, fitted into gun space by
## tools/rig/prep_gun.py: barrel along -Z, real size, the old guns' barrel line).
## Each comes as a body plus, where something moves, separate parts cut out in
## the same space: the rifle's lever, the shotgun's barrels, the Gatling's barrel
## cluster, the lighter's lid. A part goes under its pivot node shifted by
## -pivot, so it turns about the right point. Missing files fall back to the
## code-built meshes.

const DIR := "res://assets/rigged/guns/"
## Where each moving part turns (gun space).
const PIVOTS := {
	"lever_rifle_lever": Vector3(0.0, -0.045, -0.012),
	"coach_shotgun_barrels": Vector3(0.0, -0.023, -0.087),
	"crank_gatling_barrels": Vector3(0.004, 0.0147, -0.3),
	"crank_gatling_crank": Vector3(-0.07, 0.015, -0.221),
	"zippo_lid": Vector3(0.019, 0.0395, 0.0),
	"dino_rifle_glass": Vector3(-0.005, 0.072, -0.395), # the lens; its fit turns about here (DinoGlass)
}
static var _cache: Dictionary = {}


static func has(id: StringName, part: String = "body") -> bool:
	if FrontierGuns.has(id): # code-built frontier guns (gen/frontier_guns.gd)
		return part == "body" or FrontierGuns.parts(id).has(part)
	if ArmoryGuns.has(id): # the Weapon Slots guns, built in code (gen/armory_*.gd)
		return part == "body" or ArmoryGuns.parts(id).has(part)
	return ResourceLoader.exists("%s%s_%s.glb" % [DIR, id, part])


## A fresh node for `id`'s `part` with the toon look (null if there's no model).
static func make(id: StringName, part: String = "body", outline: float = 0.004, shadows: bool = false) -> Node3D:
	var path := "%s%s_%s.glb" % [DIR, id, part]
	# As made in Meshy (its own materials); --toon puts the cel shading on instead.
	var native := not GameState.has_flag("--toon")
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = _cache.get(path)
	if packed == null:
		packed = load(path)
		_cache[path] = packed
	var n := packed.instantiate() as Node3D
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if native:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		var src := mi.get_active_material(0) as BaseMaterial3D
		var m := ShaderMaterial.new()
		m.shader = ModelBody.TOON_TEX
		if src != null and src.albedo_texture != null:
			m.set_shader_parameter("albedo_tex", src.albedo_texture)
		# Meshy textures are already rich; don't push them further.
		m.set_shader_parameter("saturation", 0.95)
		m.set_shader_parameter("brightness", 1.05)
		if outline > 0.0:
			m.next_pass = Materials.outline(outline)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


static func pivot(id: StringName, part: String) -> Vector3:
	return PIVOTS.get("%s_%s" % [id, part], Vector3.ZERO)


## The whole gun in one piece (body and every part at rest), for hands and the ground.
static func whole(id: StringName, outline: float = 0.006, shadows: bool = true, variant: int = 0) -> Node3D:
	if FrontierGuns.has(id):
		return FrontierGuns.whole(id, shadows)
	if ArmoryGuns.has(id):
		return ArmoryGuns.whole(id, shadows)
	var body := make(id, "body", outline, shadows)
	if body == null:
		return null
	for part in ["lever", "barrels", "lid"]:
		var p := make(id, part, outline, shadows)
		if p != null:
			body.add_child(p)
	var g := glass(id, variant, outline, shadows)
	if g != null:
		body.add_child(g)
	return body


## The Dino Rifle's glass, placed for its fit (DinoGlass variant), on a pivot at the lens.
static func glass(id: StringName, variant: int, outline: float = 0.006, shadows: bool = false) -> Node3D:
	var part := make(id, "glass", outline, shadows)
	if part == null:
		return null
	var piv := Node3D.new()
	piv.name = "Glass"
	place_glass(piv, id, variant)
	part.position = -pivot(id, "glass")
	piv.add_child(part)
	return piv


static func place_glass(piv: Node3D, id: StringName, variant: int) -> void:
	var fit: Dictionary = DinoGlass.VARIANTS[clampi(variant, 0, DinoGlass.VARIANTS.size() - 1)]
	piv.position = pivot(id, "glass") + (fit["pos"] as Vector3)
	var r: Vector3 = fit["rot"]
	piv.rotation = Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z))
