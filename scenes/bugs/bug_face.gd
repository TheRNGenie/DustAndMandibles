class_name BugFace
extends Node3D
## A bug's attitude: two chunky black eyebrows over its eyes that frown harder
## when a player is close (and twitch when it gets shot), plus, for the rare
## smoker, a cigarette in the mouth with a glowing tip and puffs of smoke.

const BROW := Color("#1A1412")
const NEAR := 25.0

var _brows: Array[Node3D] = []
var _cig: Node3D
var _ember: OmniLight3D
var _bug: Node3D
var _frown := 0.4
var _wince := 0.0
var _r := 0.05
var _t := 0.0
var _puff_t := 0.0


func setup(bug: Node3D, spec: Dictionary, smoker: bool) -> void:
	_bug = bug
	var eyes: Dictionary = spec.get("eyes", {})
	if eyes.is_empty():
		return
	var center: Vector3 = eyes["center"]
	var spread: float = eyes["spread"]
	_r = float(eyes["r"])
	var mat := Materials.toon(0.012)
	for side: float in [-1.0, 1.0]:
		# Pivot at the inner end so frowning tips the inner end down.
		var pivot := Node3D.new()
		pivot.position = center + Vector3(side * maxf(spread - _r * 0.9, _r * 0.3), _r * 1.45, -_r * 0.55)
		add_child(pivot)
		var mi := MeshInstance3D.new()
		var st := MeshKit.begin()
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(side * _r * 1.35, 0, 0)), Vector3(_r * 3.0, _r * 0.8, _r * 0.9), BROW)
		mi.mesh = MeshKit.finish(st)
		mi.material_override = mat
		pivot.add_child(mi)
		pivot.set_meta("side", side)
		_brows.append(pivot)
	if smoker:
		_add_cigarette(center + Vector3(spread * 0.6, -_r * 1.9, -_r * 0.6))


func _add_cigarette(mouth: Vector3) -> void:
	var len := maxf(_r * 3.2, 0.12)
	var rad := len * 0.09
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -len * 0.5)), rad, rad, len, 8, Palette.BONE)
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -len * 0.1)), rad * 1.05, rad * 1.05, len * 0.22, 8, Color("#C98A3A"))
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -len * 1.0)), rad, rad, len * 0.07, 8, Color("#FF6A1A"), true, 0.9)
	_cig = MeshInstance3D.new()
	(_cig as MeshInstance3D).mesh = MeshKit.finish(st)
	(_cig as MeshInstance3D).material_override = Materials.toon(0.006)
	_cig.position = mouth
	_cig.rotation = Vector3(-0.35, -0.5, 0.0)
	add_child(_cig)
	_ember = OmniLight3D.new()
	_ember.light_color = Color("#FF7A2A")
	_ember.omni_range = len * 1.5
	_ember.light_energy = 0.4
	_ember.position = mouth + _cig.basis * Vector3(0, 0, -len)
	add_child(_ember)


## Got shot: brows jump into a deep scowl for a moment.
func wince() -> void:
	_wince = 1.0


func _process(delta: float) -> void:
	if _brows.is_empty():
		return
	_t += delta
	_wince = maxf(_wince - delta * 2.5, 0.0)
	# Frown harder the closer the nearest player is.
	var near := INF
	for n: Node in get_tree().get_nodes_in_group("players"):
		near = minf(near, (n as Node3D).global_position.distance_to(global_position))
	var want := 0.35 + 0.35 * clampf(1.0 - near / NEAR, 0.0, 1.0) + sin(_t * 7.0) * 0.03
	_frown = lerpf(_frown, want, clampf(delta * 4.0, 0.0, 1.0))
	for b in _brows:
		var side: float = b.get_meta("side")
		b.rotation.z = side * (_frown + _wince * 0.4)
	if _cig != null:
		_ember.light_energy = 0.35 + sin(_t * 5.0) * 0.15
		_puff_t -= delta
		if _puff_t <= 0.0:
			_puff_t = 1.2
			_puff()


func _puff() -> void:
	var p := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = _r * 0.6
	sphere.height = _r * 1.2
	sphere.radial_segments = 8
	sphere.rings = 4
	p.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.92, 0.94, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	get_tree().current_scene.add_child(p)
	p.global_position = _ember.global_position
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "global_position", p.global_position + Vector3(randf_range(-0.3, 0.3), 1.2, randf_range(-0.3, 0.3)), 2.0)
	tw.tween_property(p, "scale", Vector3.ONE * 3.5, 2.0)
	tw.tween_property(mat, "albedo_color:a", 0.0, 2.0)
	tw.chain().tween_callback(p.queue_free)
