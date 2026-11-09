class_name UniRig
extends RefCounted
## A universal turret's model as live nodes: one MeshInstance3D (or bare pivot)
## per part of its builder's list (UniversalBuilder.spec), hung off the turret's
## own base / head (yaw) / gun (pitch) pivots or off each other, so the animation
## code (gen/universal_*.gd animate) can move any of them by name.
##
## Moving a part: pose(name, offset, rot) puts it at its rest transform moved by
## `offset` (in the parent's space) and turned by `rot` (about its own pivot).
## Call it every frame for the parts you animate; untouched parts keep their pose.

var parts: Dictionary = {}
var rest: Dictionary = {}
## Holders for the three pivots' visuals (scaled together for the tiers).
var holders: Array[Node3D] = []
var muzzles: Array[Node3D] = []
var heavy_muzzles: Array[Node3D] = []
var glow_mat: StandardMaterial3D
var crop_mat: ShaderMaterial
var spec: Dictionary
## Parts with a "trim" entry (the tier trims go on them; see UniKit.tier_trim).
var bodies: Array[MeshInstance3D] = []
var _trims: Array[Node] = []
## Free storage for the animation code between frames (spin angles, timers).
var state: Dictionary = {}

## Rigged (Nov 2026): the fal model (RiggedTurret: base / head / gun / spin
## meshes, built under the turret's pivots by Turret.setup) stands in for the
## code parts. No part list, so the groups' animate() is skipped; the barrels
## spin, the gun kicks back on a shot and a rim of the crop's colour glows on it.
var rigged := false
## Rigged, with no gun part (the Snare Launcher: its ropes would tear): the whole
## top turns but nothing tilts, so the gun pivot (and its muzzle) stays level.
var no_pitch := false
var _gun_mi: MeshInstance3D
var _spins: Array[Node3D] = []
var _rim: ShaderMaterial
var _recoil := 0.0
var _recoil_len := 0.05
var _spin_speed := 0.0

const RIM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 color : source_color = vec4(1.0);
uniform float amount = 0.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	ALBEDO = color.rgb;
	ALPHA = clamp(rim * amount, 0.0, 1.0);
}
"""
static var _rim_shader: Shader
## The crop-coloured rim on a fal model's gun while it's loaded.
const RIM_ON := true


## Wraps a turret whose model is a fal model (Turret.setup built its meshes):
## its base, head and gun meshes are the holders (scaled for the tiers), its
## muzzles are the model's, and the gun and spinning barrels get the crop rim.
static func wrap(t: Turret, recoil_len: float = 0.05) -> UniRig:
	var r := UniRig.new()
	r.rigged = true
	r.glow_mat = StandardMaterial3D.new()
	r.crop_mat = Materials.toon_unique(0.0)
	r._recoil_len = recoil_len
	for n: Node in [t, t._head]:
		for ch in n.get_children():
			if ch is MeshInstance3D:
				r.holders.append(ch as MeshInstance3D)
				break
	r._gun_mi = t._gun_mi
	if r._gun_mi != null:
		r.holders.append(r._gun_mi)
	r.no_pitch = r._gun_mi == null or r._gun_mi.mesh == null or r._gun_mi.mesh.get_surface_count() == 0
	for s: Variant in [t._spin, t._spin_b]:
		if s != null:
			r._spins.append(s as Node3D)
	r.muzzles.append(t._muzzle)
	if t._muzzle_b != null:
		r.muzzles.append(t._muzzle_b)
	if _rim_shader == null:
		_rim_shader = Shader.new()
		_rim_shader.code = RIM_SHADER
	r._rim = ShaderMaterial.new()
	r._rim.shader = _rim_shader
	if RIM_ON: # (dark while empty: the model's own look until it's loaded)
		var lit: Array = [r._gun_mi]
		lit.append_array(r._spins)
		for mi: Variant in lit:
			if mi is GeometryInstance3D:
				(mi as GeometryInstance3D).material_overlay = r._rim
	return r


## Rigged, every frame: the kick easing back and the barrels winding down
## (crewed guns: held up by the crank's spin, 0..1).
func rigged_tick(delta: float, crank: float = 0.0) -> void:
	_recoil = move_toward(_recoil, 0.0, delta * 6.0)
	if _gun_mi != null:
		_gun_mi.position.z = _recoil_len * _recoil * _recoil
	_spin_speed = maxf(move_toward(_spin_speed, 0.0, delta * 12.0), crank * 34.0)
	for i in _spins.size():
		_spins[i].rotate_object_local(Vector3.BACK, _spin_speed * delta * (1.0 if i == 0 else -1.0))


## Rigged: a shot (the kick and a spin of the barrels).
func rigged_shot() -> void:
	_recoil = 1.0
	_spin_speed = maxf(_spin_speed, 28.0)


## Rigged: the model's top at rest (turret space), for the EMPTY sign over it.
func rigged_top(t: Turret) -> float:
	var top := 0.0
	var at: Array = [0.0, t._head.position.y, t._head.position.y + t._gun.position.y]
	for i in mini(holders.size(), 3):
		var mi := holders[i] as MeshInstance3D
		if mi != null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			top = maxf(top, float(at[i]) + mi.mesh.get_aabb().end.y)
	return top


## Rigged: room for the base ring, from the model's footprint at rest (base
## and head: a model may be all head, like the Thunder Mule's cart).
func rigged_ring_r() -> float:
	var half := 0.0
	for i in mini(holders.size(), 2):
		var mi := holders[i] as MeshInstance3D
		if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var box := mi.mesh.get_aabb()
		for x: float in [box.position.x, box.end.x]:
			for z: float in [box.position.z, box.end.z]:
				half = maxf(half, Vector2(x, z).length() * 0.75)
	if half <= 0.0:
		return 0.85
	return clampf(half + 0.08, 0.5, 1.8)


## Builds `spec` under the given pivots: `base` doesn't move, `head` yaws, `gun` pitches.
static func make(s: Dictionary, base: Node3D, head: Node3D, gun: Node3D) -> UniRig:
	var r := UniRig.new()
	r.spec = s
	r.glow_mat = StandardMaterial3D.new()
	r.glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r.glow_mat.albedo_color = Color(0.16, 0.16, 0.17)
	r.crop_mat = Materials.toon_unique(0.0)
	var roots := {}
	for pair: Array in [["base", base], ["head", head], ["gun", gun]]:
		var h := Node3D.new()
		h.name = "Vis_" + str(pair[0])
		(pair[1] as Node3D).add_child(h)
		roots[pair[0]] = h
		r.holders.append(h)
	for p: Dictionary in s.get("parts", []):
		var n: Node3D
		if p.get("mesh") != null:
			var mi := MeshInstance3D.new()
			mi.mesh = p["mesh"]
			if bool(p.get("glow", false)):
				mi.material_override = r.glow_mat
			elif bool(p.get("crop", false)):
				mi.material_override = r.crop_mat
				mi.visible = false
			else:
				mi.material_override = Materials.toon(float(p.get("outline", 0.015)))
			if p.has("trim"):
				r.bodies.append(mi)
				mi.set_meta("trim", p["trim"])
			n = mi
		else:
			n = Node3D.new()
		n.name = str(p["name"])
		n.transform = Transform3D(p.get("basis", Basis()), p.get("pos", Vector3.ZERO))
		var parent_name := str(p.get("parent", "base"))
		var parent: Node3D = roots.get(parent_name, r.parts.get(parent_name, roots["base"]))
		parent.add_child(n)
		r.parts[n.name] = n
		r.rest[n.name] = n.transform
	# Muzzles live in gun space (or under a named part when given as [part, offset]).
	for key: String in ["muzzles", "heavy_muzzles"]:
		for m: Variant in s.get(key, []):
			var mz := Node3D.new()
			mz.name = "Muzzle"
			if m is Array:
				mz.position = (m as Array)[1]
				(r.parts.get(str((m as Array)[0]), roots["gun"]) as Node3D).add_child(mz)
			else:
				mz.position = m
				(roots["gun"] as Node3D).add_child(mz)
			(r.muzzles if key == "muzzles" else r.heavy_muzzles).append(mz)
	return r


func part(n: String) -> Node3D:
	return parts.get(n)


func has(n: String) -> bool:
	return parts.has(n)


## Rest transform moved by `offset` (parent space) and turned by `rot` (own pivot).
func pose(n: String, offset: Vector3 = Vector3.ZERO, rot: Basis = Basis()) -> void:
	var p: Node3D = parts.get(n)
	if p == null:
		return
	var r: Transform3D = rest[n]
	p.transform = Transform3D(r.basis * rot, r.origin + offset)


## Shorthand: turn part `n` by `angle` about its own `axis`.
func turn(n: String, axis: Vector3, angle: float, offset: Vector3 = Vector3.ZERO) -> void:
	pose(n, offset, Basis(axis, angle))


## Shorthand: slide part `n` along its own -Z by `back` metres (recoil: positive = backwards, +Z).
func kick(n: String, back: float) -> void:
	var p: Node3D = parts.get(n)
	if p == null:
		return
	var r: Transform3D = rest[n]
	p.transform = Transform3D(r.basis, r.origin + r.basis.z * back)


func show_part(n: String, on: bool) -> void:
	var p: Node3D = parts.get(n)
	if p != null:
		p.visible = on


## Scale (non-uniform allowed) a part about its pivot.
func stretch(n: String, s: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	var p: Node3D = parts.get(n)
	if p == null:
		return
	var r: Transform3D = rest[n]
	p.transform = Transform3D(r.basis.scaled(s), r.origin + offset)


## The crop's colour on the glow parts (dark when empty) and the crop fill.
## `glow` 0..1 fades it in and out (loading, wave end).
func set_crop(color: Color, glow: float, show_fill: bool) -> void:
	var dark := Color(0.16, 0.16, 0.17)
	glow_mat.albedo_color = dark.lerp(color * 1.35, clampf(glow, 0.0, 1.0))
	if _rim != null:
		_rim.set_shader_parameter("color", color)
		_rim.set_shader_parameter("amount", clampf(glow, 0.0, 1.5) * 0.9)
	crop_mat.set_shader_parameter("albedo", color)
	for n: String in parts:
		var mi := parts[n] as MeshInstance3D
		if mi != null and mi.material_override == crop_mat:
			mi.visible = show_fill


## Tier 2 and 3 trims on the body parts (brass bands; armour and glow lines).
func show_tier(tier: int) -> void:
	for t in _trims:
		if is_instance_valid(t):
			t.queue_free()
	_trims.clear()
	for mi: MeshInstance3D in bodies:
		var meshes := UniKit.tier_trim(mi.get_meta("trim", {}), tier)
		for i in 2:
			if meshes[i] == null:
				continue
			var tm := MeshInstance3D.new()
			tm.mesh = meshes[i]
			tm.material_override = glow_mat if i == 1 else Materials.toon(0.01)
			mi.add_child(tm)
			_trims.append(tm)


## Every part merged into one mesh at rest (the build ghost and icons).
static func whole_mesh(s: Dictionary, head_y: float, gun_y: float, gun_pitch: float = 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xf := {"base": Transform3D(), "head": Transform3D(Basis(), Vector3(0, head_y, 0)),
		"gun": Transform3D(Basis(), Vector3(0, head_y, 0)) * Transform3D(Basis(Vector3.RIGHT, gun_pitch), Vector3(0, gun_y, 0))}
	var any := false
	for p: Dictionary in s.get("parts", []):
		var parent: Transform3D = xf.get(str(p.get("parent", "base")), xf["base"])
		var mine := parent * Transform3D(p.get("basis", Basis()), p.get("pos", Vector3.ZERO))
		xf[str(p["name"])] = mine
		if p.get("mesh") == null or bool(p.get("crop", false)):
			continue
		var m := p["mesh"] as ArrayMesh
		for si in m.get_surface_count():
			st.append_from(m, si, mine)
			any = true
	if not any:
		return ArrayMesh.new()
	return st.commit()
