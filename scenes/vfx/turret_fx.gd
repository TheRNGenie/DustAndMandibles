extends Node
## Looks after turrets and structures without touching their logic (it only
## reads them): Gatling barrels glow hotter the longer they spin, damaged
## things go sooty and smoke (black smoke and embers when nearly gone), and
## anything wrecked bursts into splinters. Polls a few times a second; smoke
## emitters come from a small capped pool.

const SCAN := 0.25
const SMOKE_POOL := 12
const SOOT_AT := 0.6
const BURNING_AT := 0.3

var vfx: Node3D

var _scan := 0.0
## instance id -> {node, top, heat, glow_mat, smoke (index or -1), soot (0/1/2)}
var _tracked: Dictionary = {}
var _smokes: Array[GPUParticles3D] = []
var _embers: Array[GPUParticles3D] = []
var _smoke_owner: Array[int] = []
var _soot_mats: Array[StandardMaterial3D] = []


func _ready() -> void:
	_soot_mats = [_soot_material(0.78), _soot_material(0.5)]


func _process(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0:
		_scan = SCAN
		_rescan()
	# Barrel heat: every frame, but only for turrets with spinning barrels.
	for id: int in _tracked:
		var t: Dictionary = _tracked[id]
		if not t.has("spin"):
			continue
		var nv: Variant = t["node"]
		if not is_instance_valid(nv):
			continue
		var n := nv as Node
		var spin_speed := float(n.get("_spin_speed"))
		var heat := float(t["heat"])
		heat = move_toward(heat, 1.0 if spin_speed > 14.0 else 0.0, delta * (0.22 if spin_speed > 14.0 else 0.12))
		t["heat"] = heat
		_show_heat(t, heat)


func _rescan() -> void:
	var seen := {}
	for n: Node in get_tree().get_nodes_in_group("structures"):
		var id := n.get_instance_id()
		seen[id] = true
		if not _tracked.has(id):
			_track(n)
		_update_damage(_tracked[id])
	for id: int in _tracked.keys():
		if not seen.has(id):
			_release(id)


func _track(n: Node) -> void:
	var t := {"node": n, "heat": 0.0, "smoke": -1, "soot": 0, "top": 1.6}
	var spin: Variant = n.get("_spin")
	if spin is MeshInstance3D:
		t["spin"] = spin
	# How tall it is, so smoke comes off the top.
	var top := 0.0
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		if g.mesh == null:
			continue
		var box := (n as Node3D).global_transform.affine_inverse() * g.global_transform * g.mesh.get_aabb()
		top = maxf(top, box.end.y)
	if top > 0.0:
		t["top"] = minf(top, 12.0)
	_tracked[n.get_instance_id()] = t
	n.tree_exiting.connect(_on_leaving.bind(n), CONNECT_ONE_SHOT)


## Wrecked (HP gone) as it leaves the tree: splinters where it stood.
func _on_leaving(n: Node) -> void:
	var h := n.get("health") as Health
	if h != null and h.hp <= 0.5 and vfx != null and n is Node3D and n.is_inside_tree() and not get_tree().paused:
		var t: Dictionary = _tracked.get(n.get_instance_id(), {})
		vfx.call("splinters", (n as Node3D).global_position + Vector3.UP * float(t.get("top", 1.6)) * 0.5, 1.0)


func _release(id: int) -> void:
	var t: Dictionary = _tracked[id]
	_set_smoke(t, -1)
	_tracked.erase(id)


func _update_damage(t: Dictionary) -> void:
	if not is_instance_valid(t["node"]):
		return
	var n := t["node"] as Node3D
	var h := n.get("health") as Health
	if h == null:
		return
	var f := h.fraction()
	var soot := 0
	if f < BURNING_AT:
		soot = 2
	elif f < SOOT_AT:
		soot = 1
	if soot != int(t["soot"]):
		t["soot"] = soot
		for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
			var g := mi as MeshInstance3D
			if g == t.get("spin") and float(t["heat"]) > 0.05:
				continue
			g.material_overlay = null if soot == 0 else _soot_mats[soot - 1]
		_set_smoke(t, soot)


## Gives (or takes back) a smoke column; `level` 1 = grey smoke, 2 = black smoke and embers.
func _set_smoke(t: Dictionary, level: int) -> void:
	var idx := int(t["smoke"])
	if level <= 0:
		if idx >= 0:
			_smokes[idx].emitting = false
			_embers[idx].emitting = false
			_smoke_owner[idx] = 0
			t["smoke"] = -1
		return
	if idx < 0:
		idx = _free_smoke()
		if idx < 0:
			return
		t["smoke"] = idx
		_smoke_owner[idx] = (t["node"] as Node).get_instance_id()
	var n := t["node"] as Node3D
	var at := n.global_position + Vector3.UP * float(t["top"])
	_smokes[idx].global_position = at
	_embers[idx].global_position = at - Vector3.UP * 0.3
	_smokes[idx].amount_ratio = 0.6 if level == 1 else 1.0
	(_smokes[idx].draw_pass_1 as QuadMesh).material = _smoke_mat(level)
	_smokes[idx].emitting = true
	_embers[idx].emitting = level == 2


func _free_smoke() -> int:
	for i in _smokes.size():
		if _smoke_owner[i] == 0:
			return i
	if _smokes.size() >= SMOKE_POOL or vfx == null:
		return -1
	var s := GPUParticles3D.new()
	s.amount = 16
	s.lifetime = 3.0
	s.local_coords = false
	s.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 14, 12))
	var pm: ParticleProcessMaterial = vfx.call("puff_process", Vector2(0.8, 1.6), 12.0, 1.4, 3.0)
	pm.direction = Vector3(0, 1, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	# Drifts a little downwind.
	pm.gravity = Vector3(0.6, 1.2, 0.3)
	s.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	quad.material = _smoke_mat(1)
	s.draw_pass_1 = quad
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	_smokes.append(s)
	var e := GPUParticles3D.new()
	e.amount = 8
	e.lifetime = 1.2
	e.local_coords = false
	e.emitting = false
	e.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 8, 8))
	var epm := ParticleProcessMaterial.new()
	epm.direction = Vector3(0, 1, 0)
	epm.spread = 35.0
	epm.initial_velocity_min = 1.0
	epm.initial_velocity_max = 2.5
	epm.gravity = Vector3(0, 0.5, 0)
	epm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	epm.emission_sphere_radius = 0.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	epm.scale_curve = ct
	e.process_material = epm
	var star := QuadMesh.new()
	star.size = Vector2(0.18, 0.18)
	star.material = Materials.star(Color("#FF8A2A"), 3.0)
	e.draw_pass_1 = star
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(e)
	_embers.append(e)
	_smoke_owner.append(0)
	return _smokes.size() - 1


var _smoke_mats: Dictionary = {}


func _smoke_mat(level: int) -> ShaderMaterial:
	if not _smoke_mats.has(level):
		if level == 1:
			_smoke_mats[level] = vfx.call("puff_material", Color("#B9B2AA"), Color("#7D7380"))
		else:
			_smoke_mats[level] = vfx.call("puff_material", Color("#4A4440"), Color("#2A2428"))
	return _smoke_mats[level]


## Sooty, patchy darkening drawn over the model (multiplies what's underneath).
func _soot_material(strength: float) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.08
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.22, 0.19, 0.18))
	ramp.set_color(1, Color(1, 1, 1))
	ramp.add_point(0.45, Color(0.45, 0.4, 0.38))
	tex.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.albedo_texture = tex
	m.albedo_color = Color(strength, strength * 0.96, strength * 0.93)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.6
	m.render_priority = 1
	return m


## Barrels glow from dull red to orange the longer a Gatling keeps spinning.
func _show_heat(t: Dictionary, heat: float) -> void:
	var spin := t["spin"] as MeshInstance3D
	if not is_instance_valid(spin):
		return
	if heat < 0.05:
		if t.has("glow_mat") and spin.material_overlay == t["glow_mat"]:
			spin.material_overlay = null if int(t["soot"]) == 0 else _soot_mats[int(t["soot"]) - 1]
		return
	if not t.has("glow_mat"):
		var g := StandardMaterial3D.new()
		g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		g.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.render_priority = 1
		t["glow_mat"] = g
	var mat := t["glow_mat"] as StandardMaterial3D
	var k := smoothstep(0.05, 1.0, heat)
	var col := Color("#9A1E08").lerp(Color("#FF9A2E"), k)
	mat.albedo_color = Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, k * 0.85)
	if spin.material_overlay != mat:
		spin.material_overlay = mat
