class_name ModelBody
extends Node3D
## A rigged character model (assets/rigged/*.glb, made with Meshy and rigged by
## tools/rig/autorig.py) worn by a DummyRig. The rig keeps animating its own
## invisible pivots exactly as before (walk, aim, interactions, wobble); every
## frame each mapped bone copies its pivot's rotation, so all of that carries
## over unchanged. Arms are lined up with the pivots' straight-down rest so the
## gun arm points where you aim; legs keep the model's own stance.

const MODELS := {
	&"vest": "res://assets/rigged/dummy_vest.glb",
	&"duster": "res://assets/rigged/dummy_duster.glb",
	&"poncho": "res://assets/rigged/dummy_poncho.glb",
	&"lawman": "res://assets/rigged/dummy_lawman.glb",
}
## Meshy hats (tools/rig/prep_prop.py: centred, lowest point at 0): [file, height on the head pivot].
const HATS := {
	&"cattleman": ["res://assets/rigged/hat_cattleman.glb", 0.15],
	&"ten_gallon": ["res://assets/rigged/hat_ten_gallon.glb", 0.15],
	&"gambler": ["res://assets/rigged/hat_gambler.glb", 0.16],
	&"bowler": ["res://assets/rigged/hat_bowler.glb", 0.16],
	&"sombrero": ["res://assets/rigged/hat_sombrero.glb", 0.07],
}
const TOON_TEX := preload("res://shaders/toon_tex.gdshader")
## The procedural rig's hip height at rest; the model's hips follow changes to it.
const RIG_HIP_Y := 0.95

var skel: Skeleton3D
var materials: Array[ShaderMaterial] = []
## [pivot, bone index, rest target basis (rig space), align?]
var _map: Array = []
var _hips_bone := -1
var _hips_rest := Vector3.ZERO
var _rig: DummyRig
var _scene: Node3D
static var _cache: Dictionary = {}


static func has_model(outfit: StringName) -> bool:
	return MODELS.has(outfit) and ResourceLoader.exists(MODELS[outfit])


## Builds the model inside `rig` (call after the rig's pivots exist).
func setup(rig: DummyRig, outfit: StringName, first_person: bool) -> void:
	_rig = rig
	var packed: PackedScene = _cache.get(outfit)
	if packed == null:
		packed = load(MODELS[outfit])
		_cache[outfit] = packed
	_scene = packed.instantiate() as Node3D
	# The models face +Z out of Blender; the rig faces -Z.
	_scene.rotation.y = PI
	add_child(_scene)
	skel = _scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for mi: MeshInstance3D in _scene.find_children("*", "MeshInstance3D", true, false):
		var src := mi.get_active_material(0) as BaseMaterial3D
		var m := ShaderMaterial.new()
		m.shader = TOON_TEX
		if src != null and src.albedo_texture != null:
			m.set_shader_parameter("albedo_tex", src.albedo_texture)
		m.next_pass = Materials.outline(0.012)
		mi.material_override = m
		materials.append(m)
		if first_person:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## Maps the rig's pivots to bones once everything is in the tree.
func bind() -> void:
	_map.clear()
	var to_rig := _rig.global_transform.affine_inverse() * skel.global_transform
	var pairs := [
		[_rig._hips, "Hips", false], [_rig._torso, "Spine", false], [_rig._head, "Head", false],
		[_rig._thighs[0], "LeftUpperLeg", false], [_rig._shins[0], "LeftLowerLeg", false], [_rig._ankles[0], "LeftFoot", false],
		[_rig._thighs[1], "RightUpperLeg", false], [_rig._shins[1], "RightLowerLeg", false], [_rig._ankles[1], "RightFoot", false],
		[_rig._shoulders[0], "LeftUpperArm", true], [_rig._elbows[0], "LeftLowerArm", true],
		[_rig._shoulders[1], "RightUpperArm", true], [_rig._elbows[1], "RightLowerArm", true],
	]
	for p: Array in pairs:
		var b := skel.find_bone(p[1])
		if b < 0:
			continue
		var rest_rig: Basis = (to_rig.basis * skel.get_bone_global_rest(b).basis).orthonormalized()
		if p[2]:
			# Line the bone up with the pivot's rest (straight down).
			var along := (rest_rig * Vector3.UP).normalized()
			rest_rig = _rotation_between(along, Vector3.DOWN) * rest_rig
		_map.append([p[0], b, rest_rig])
	_map.sort_custom(func(a: Array, c: Array) -> bool: return int(a[1]) < int(c[1]))
	_hips_bone = skel.find_bone("Hips")
	if _hips_bone >= 0:
		_hips_rest = skel.get_bone_global_rest(_hips_bone).origin


static func _rotation_between(a: Vector3, b: Vector3) -> Basis:
	var axis := a.cross(b)
	if axis.length() < 0.0001:
		return Basis()
	return Basis(axis.normalized(), a.angle_to(b))


## Copies the pivots' current rotations onto the bones.
func apply() -> void:
	if _map.is_empty():
		bind()
	var rig_inv := _rig.global_transform.affine_inverse()
	var sk_from_rig := (rig_inv * skel.global_transform).affine_inverse().basis
	for m: Array in _map:
		var pivot: Node3D = m[0]
		var b: int = m[1]
		var p_rig: Basis = (rig_inv.basis * pivot.global_basis).orthonormalized()
		var target: Basis = sk_from_rig * (p_rig * (m[2] as Basis))
		var cur := skel.get_bone_global_pose(b)
		var origin := cur.origin
		if b == _hips_bone:
			var off := _rig._hips.position - Vector3(0, RIG_HIP_Y, 0)
			origin = _hips_rest + sk_from_rig * off
		skel.set_bone_global_pose(b, Transform3D(target.orthonormalized(), origin))


## A Meshy hat as a node with the toon look, or null when there's no model for it.
static func hat(id: StringName, first_person: bool) -> Node3D:
	if not HATS.has(id) or not ResourceLoader.exists(HATS[id][0]):
		return null
	var packed: PackedScene = _cache.get("hat_" + String(id))
	if packed == null:
		packed = load(HATS[id][0])
		_cache["hat_" + String(id)] = packed
	var n := packed.instantiate() as Node3D
	n.position.y = float(HATS[id][1])
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var src := mi.get_active_material(0) as BaseMaterial3D
		var m := ShaderMaterial.new()
		m.shader = TOON_TEX
		if src != null and src.albedo_texture != null:
			m.set_shader_parameter("albedo_tex", src.albedo_texture)
		m.next_pass = Materials.outline(0.01)
		mi.material_override = m
		if first_person:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	return n


func set_flash(color: Color, amount: float) -> void:
	for m in materials:
		m.set_shader_parameter("flash_color", color)
		m.set_shader_parameter("flash_amount", amount)
