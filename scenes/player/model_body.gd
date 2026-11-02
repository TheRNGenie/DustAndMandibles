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
	&"cattleman": ["res://assets/rigged/hat_cattleman.glb", 0.13],
	&"ten_gallon": ["res://assets/rigged/hat_ten_gallon.glb", 0.13],
	&"gambler": ["res://assets/rigged/hat_gambler.glb", 0.14],
	&"bowler": ["res://assets/rigged/hat_bowler.glb", 0.14],
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
var _feet: Array = []
var _first_person := false
## First person: bones folded to nothing. Everything from the chest up (the head
## would block the view; the first-person hands replace the arms), so looking
## down you see your belt, legs and boots, the way first-person bodies usually work.
## How much of the model's own (A-pose) arm spread a lowered arm keeps.
const HANG_KEEP := 0.22
const FP_HIDDEN := ["Neck", "LeftShoulder", "RightShoulder"]
var _ankle_rest := 0.0
var _rig: DummyRig
var _scene: Node3D
static var _cache: Dictionary = {}


static func has_model(outfit: StringName) -> bool:
	return MODELS.has(outfit) and ResourceLoader.exists(MODELS[outfit])


## Builds the model inside `rig` (call after the rig's pivots exist).
func setup(rig: DummyRig, outfit: StringName, first_person: bool) -> void:
	_rig = rig
	_first_person = first_person
	var path: String = MODELS[outfit]
	# Shown as made in Meshy (its own materials); --toon puts the game's cel shading on instead.
	var native := not GameState.has_flag("--toon")
	var packed: PackedScene = _cache.get(path)
	if packed == null:
		packed = load(path)
		_cache[path] = packed
	_scene = packed.instantiate() as Node3D
	# The models face +Z out of Blender; the rig faces -Z.
	_scene.rotation.y = PI
	add_child(_scene)
	skel = _scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for mi: MeshInstance3D in _scene.find_children("*", "MeshInstance3D", true, false):
		if native:
			# Exactly as made in Meshy: its own PBR material and maps. In first
			# person you see your own body when you look down (head and arms
			# folded away: the first-person arms hold the gun).
			continue
		var src := mi.get_active_material(0) as BaseMaterial3D
		var m := ShaderMaterial.new()
		m.shader = TOON_TEX
		if src != null and src.albedo_texture != null:
			m.set_shader_parameter("albedo_tex", src.albedo_texture)
		# A thin outline: thick hulls poke through the detailed models' seams.
		m.next_pass = Materials.outline(0.005)
		mi.material_override = m
		materials.append(m)


## Maps the rig's pivots to bones once everything is in the tree.
var _fp_chain_cache: Array = []


## For each FP_HIDDEN bone: it and all its descendants, parents first.
func _fp_chains() -> Array:
	if _fp_chain_cache.is_empty():
		for bn: String in FP_HIDDEN:
			var root := skel.find_bone(bn)
			if root < 0:
				continue
			var chain: Array[int] = [root]
			var i := 0
			while i < chain.size():
				for c: int in skel.get_bone_children(chain[i]):
					chain.append(c)
				i += 1
			_fp_chain_cache.append(chain)
	return _fp_chain_cache


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
		var aligned := rest_rig
		if p[2]:
			# Lined up with the pivot's rest (straight down), so a raised arm points
			# exactly where the rig aims it. Hanging arms keep the model's own
			# relaxed angle (they'd clip into the clothes if pulled straight).
			var along := (rest_rig * Vector3.UP).normalized()
			aligned = _rotation_between(along, Vector3.DOWN) * rest_rig
		_map.append([p[0], b, aligned, rest_rig, p[2]])
	_map.sort_custom(func(a: Array, c: Array) -> bool: return int(a[1]) < int(c[1]))
	_hips_bone = skel.find_bone("Hips")
	if _hips_bone >= 0:
		_hips_rest = skel.get_bone_global_rest(_hips_bone).origin
	_feet = [skel.find_bone("LeftFoot"), skel.find_bone("RightFoot")]
	_ankle_rest = 1e9
	for f in _feet:
		if f >= 0:
			_ankle_rest = minf(_ankle_rest, (to_rig * skel.get_bone_global_rest(f).origin).y)


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
	var to_rig := rig_inv * skel.global_transform
	var sk_from_rig := to_rig.affine_inverse().basis
	var raise := {}
	var hang := {}
	for m: Array in _map:
		var pivot: Node3D = m[0]
		var b: int = m[1]
		var p_rig: Basis = (rig_inv.basis * pivot.global_basis).orthonormalized()
		var rest: Basis = m[2]
		if m[4]:
			# Arms: point each bone where the rig's limb points (so elbows bend the
			# way the rig bends them, whatever the model's bone roll), keeping the
			# model's own hang (a little of it) when the arm is down.
			var side := "L" if skel.get_bone_name(b).begins_with("Left") else "R"
			if not raise.has(side):
				var down := (p_rig * Vector3.DOWN).normalized()
				raise[side] = smoothstep(0.25, 0.9, down.angle_to(Vector3.DOWN))
				var model_hang := ((m[3] as Basis) * Vector3.UP).normalized()
				# Only a little of the model's A-pose spread, so arms hang by the sides.
				hang[side] = Basis().slerp(_rotation_between(Vector3.DOWN, model_hang), HANG_KEEP * (1.0 - float(raise[side])))
			var want := p_rig * ((hang[side] as Basis) * Vector3.DOWN)
			var rest_m: Basis = m[3]
			var rest_dir := (rest_m * Vector3.UP).normalized()
			var aim_basis := _rotation_between(rest_dir, want.normalized()) * rest_m
			skel.set_bone_global_pose(b, Transform3D((sk_from_rig * aim_basis).orthonormalized(), skel.get_bone_global_pose(b).origin))
			continue
		var target: Basis = sk_from_rig * (p_rig * rest)
		var cur := skel.get_bone_global_pose(b)
		var origin := cur.origin
		if b == _hips_bone:
			var off := _rig._hips.position - Vector3(0, RIG_HIP_Y, 0)
			origin = _hips_rest + sk_from_rig * off
		skel.set_bone_global_pose(b, Transform3D(target.orthonormalized(), origin))
	if _first_person:
		# Fold each hidden bone and everything below it to a point. Absolute
		# transforms, so nothing shrinks further frame after frame.
		for chain: Array in _fp_chains():
			var at := skel.get_bone_global_pose(int(chain[0])).origin
			for hb: int in chain:
				skel.set_bone_global_pose(hb, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), at))
	# Keep the boots out of the ground: if the lower foot ends up below where it
	# stands at rest (hips dipping on a stride or a landing), lift the whole body.
	if _hips_bone >= 0 and _feet.size() == 2 and _feet[0] >= 0 and _feet[1] >= 0:
		var low := 1e9
		for f: int in _feet:
			low = minf(low, (to_rig * skel.get_bone_global_pose(f).origin).y)
		var sink := _ankle_rest - low
		if sink > 0.001:
			var hp := skel.get_bone_global_pose(_hips_bone)
			hp.origin += sk_from_rig * Vector3(0, minf(sink, 0.3), 0)
			skel.set_bone_global_pose(_hips_bone, hp)


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
		if first_person:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if not GameState.has_flag("--toon"):
			continue
		var src := mi.get_active_material(0) as BaseMaterial3D
		var m := ShaderMaterial.new()
		m.shader = TOON_TEX
		if src != null and src.albedo_texture != null:
			m.set_shader_parameter("albedo_tex", src.albedo_texture)
		m.next_pass = Materials.outline(0.005)
		mi.material_override = m
		if first_person:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	return n


func set_flash(color: Color, amount: float) -> void:
	for m in materials:
		m.set_shader_parameter("flash_color", color)
		m.set_shader_parameter("flash_amount", amount)
